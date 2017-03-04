# name: discourse-slack-official
# about: This is intended to be a feature-rich plugin for slack-discourse integration
# version: 1.0.0
# authors: Nick Sahler (nicksahler), Dave McClure (mcwumbly) for slack backdoor code.
# url: https://github.com/discourse/discourse-slack-official

require_dependency 'discourse'
require_dependency 'search'
require_dependency 'search/grouped_search_results'
require 'net/http'
require 'json'
require 'time'
require 'cgi'
require File.expand_path('../lib/validators/discourse_slack_enabled_setting_validator.rb', __FILE__)

enabled_site_setting :slack_enabled

PLUGIN_NAME = "discourse-slack-official".freeze

register_asset "stylesheets/slack_admin.scss"

after_initialize do
  DOMAIN = Discourse.base_url

  unless ::PluginStore.get(PLUGIN_NAME, "not_first_time")
    ::PluginStore.set(PLUGIN_NAME, "not_first_time", true)
    ::PluginStore.set(PLUGIN_NAME, "category_*", [{ category_id: '0', channel: "#general", filter: "follow" }])
  end

  module ::DiscourseSlack
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseSlack
    end
  end

  require_dependency File.expand_path('../jobs/notify_slack.rb', __FILE__)
  require_dependency 'application_controller'
  require_dependency 'discourse_event'
  require_dependency 'admin_constraint'

  require_relative 'slack_parser'

  class ::DiscourseSlack::SlackController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_filter :slack_enabled?
    before_filter :slack_discourse_username_present?

    before_filter :slack_token_valid?, :except => [:list, :edit, :delete, :test_notification, :reset_settings]
    skip_before_filter :check_xhr, :preload_json, :verify_authenticity_token, except: [:list, :edit, :delete, :test_notification, :reset_settings]

    before_filter :slack_webhook_or_token_present?

    def slack_enabled?
      raise Discourse::NotFound unless SiteSetting.slack_enabled?
    end

    def list
      rows = PluginStoreRow.where(plugin_name: PLUGIN_NAME).where("key ~* :pat", :pat => '^category_.*')
      out = []

      rows.each do |row|
        ::PluginStore.cast_value(row.type_name, row.value).each do | rule |
          x = {
            category_id: row.key.gsub('category_', '').gsub('*', '0'),
            channel: rule[:channel],
            filter: rule[:filter]
          }

          out.push x
        end
      end

      render json: (params[:raw]) ? rows : out
    end

    def test_notification
      DiscourseSlack::Slack.notify(
        Topic.order('RANDOM()').where(closed: false, archived: false)
          .first.ordered_posts.first.id
      )

      render json: success_json
    end

    def reset_settings
      PluginStoreRow.where(plugin_name: PLUGIN_NAME).destroy_all
      render json: success_json
    end

    def is_number? string
      true if Float(string) rescue false
    end

    # "0" on the client is usde to represent "all categories" - "*" on the server, to support old versions of the plugin.
    def edit
      return render json: { message: "Error"}, status: 500 if params[:channel] == '' || !is_number?(params[:category_id])
      DiscourseSlack::Slack.set_filter_by_id(( params[:category_id] === "0") ? '*' : params[:category_id], params[:channel], params[:filter])
      render json: success_json
    end

    def delete
      return render json: { message: "Error"}, status: 500 if params[:channel] == '' || !is_number?(params[:category_id])

      DiscourseSlack::Slack.delete_filter('*', params[:channel]) if ( params[:category_id] === "0" )
      DiscourseSlack::Slack.delete_filter(params[:category_id], params[:channel])

      render json: success_json
    end

    def command
      guardian = Guardian.new(User.find_by_username(SiteSetting.slack_discourse_username))

      tokens = params[:text].split(" ")

      # channel name fix
      if (params[:channel_name] === "directmessage")
        channel = "@#{params[:user_name]}"
      elsif (params[:channel_name] === "privategroup")
        channel = params[:channel_id]
      else
        channel = "##{params[:channel_name]}"
      end

      cmd = "help"

      if tokens.size > 0
        cmd = tokens[0]
      end
      ## TODO Put back URL finding
      case cmd
      when "search"
        if (tokens.size >= 2)
          query = tokens[1..tokens.size-1].join(" ")
          render json: DiscourseSlack::Slack.slack_search_results_message(query)
        else
          render json: { text: DiscourseSlack::Slack.help }
        end
      when "watch", "follow", "mute"
        if (tokens.size == 2)
          cat_name = tokens[1]
          category = Category.find_by({slug: cat_name})
          if (cat_name.casecmp("all") === 0)
            DiscourseSlack::Slack.set_filter_by_id('*', channel, cmd, params[:channel_id])
            render json: { text: "*#{DiscourseSlack::Slack.filter_to_past(cmd).capitalize} all categories* on this channel." }
          elsif (category && guardian.can_see_category?(category))
            DiscourseSlack::Slack.set_filter_by_id(category.id, channel, cmd, params[:channel_id])
            render json: { text: "*#{DiscourseSlack::Slack.filter_to_past(cmd).capitalize}* category *#{category.name}*" }
          else
            # TODO DRY (easy)
            cat_list = (CategoryList.new(Guardian.new User.find_by_username(SiteSetting.slack_discourse_username)).categories.map { |c| c.slug }).join(', ')
            render json: { text: "I can't find the *#{tokens[1]}* category. Did you mean: #{cat_list}" }
          end
        else
          render json: { text: DiscourseSlack::Slack.help }
        end
      when "help"
        render json: { text: DiscourseSlack::Slack.help }
      when "status"
        render json: { text: DiscourseSlack::Slack.status, link_names: 1 }
      else
        render json: { text: DiscourseSlack::Slack.help }
      end
    end

    def knock
      route = topic_route params[:text]
      post_number = route[:post_number] ? route[:post_number].to_i : 1

      topic = find_topic(route[:topic_id], post_number)
      post = find_post(topic, post_number)

      render json: DiscourseSlack::Slack.slack_message(post)
    end

    def slack_token_valid?
      raise Discourse::InvalidAccess.new if SiteSetting.slack_incoming_webhook_token.blank?
      raise Discourse::InvalidAccess.new unless SiteSetting.slack_incoming_webhook_token == params[:token]
    end

    def slack_discourse_username_present?
      raise Discourse::InvalidAccess.new unless SiteSetting.slack_discourse_username
    end

    def slack_webhook_or_token_present?
      raise Discourse::InvalidAccess.new if SiteSetting.slack_outbound_webhook_url.blank? && SiteSetting.slack_access_token.blank?
    end

    def topic_route(text)
      url = text.slice(text.index("<") + 1, text.index(">") -1)
      url.sub! Discourse.base_url, ''
      route = Rails.application.routes.recognize_path(url)
      raise Discourse::NotFound unless route[:controller] == 'topics' && route[:topic_id]
      route
    end

    def find_post(topic, post_number)
      topic.filtered_posts.select { |p| p.post_number == post_number}.first
    end

    def find_topic(topic_id, post_number)
      user = User.find_by_username SiteSetting.slack_discourse_username
      TopicView.new(topic_id, user, { post_number: post_number })
    end

    # ----- Access control methods -----
    def handle_unverified_request
    end

    def api_key_valid?
      true
    end

    def redirect_to_login_if_required
    end
  end

  class ::DiscourseSlack::Slack
    def self.filter_to_present(filter)
      { 'mute' => 'muting', 'follow' => 'following', 'watch' => 'watching' }[filter]
    end

    def self.filter_to_past(filter)
      { 'mute' => 'muted', 'follow' => 'followed', 'watch' => 'watched' }[filter]
    end

    def self.excerpt(html, max_length)
      doc = Nokogiri::HTML.fragment(html)
      doc.css(".lightbox-wrapper .meta").remove
      html = doc.to_html

      SlackParser.get_excerpt(html, max_length)
    end

    def self.format_channel(name)
      (name.include?("@") || name.include?("\#"))? name : "<##{name}>"
    end

    def self.status
      rows = PluginStoreRow.where(plugin_name: PLUGIN_NAME)
      text = ""


      categories = rows.map { |item| item.key.gsub('category_', '').to_i }

      Category.where(id: categories).each do | category |
        #why
        get_store(category.id).each do |row|
          text << "#{format_channel(row[:channel])} is #{filter_to_present(row[:filter])} category *#{category.name}*\n"
        end
      end

      get_store('*').each do |row|
        text << "#{format_channel(row[:channel])} is #{filter_to_present(row[:filter])} *all categories*\n"
      end
      cat_list = (CategoryList.new(Guardian.new User.find_by_username(SiteSetting.slack_discourse_username)).categories.map { |category| category.slug }).join(', ')
      text << "\nHere are your available categories: #{cat_list}"
      text
    end

    def self.help
      %(
      `/discourse [search|watch|follow|mute|help|status] [category|all|query]`
*search* - find top topics that match a query
*watch* – notify this channel for new topics and new replies
*follow* – notify this channel for new topics
*mute* – stop notifying this channel
*status* – show current notification state and categories
)
    end

    def self.slack_process_attachment(post, text)
      topic = Topic.find_by(id: post.topic_id)
      user = User.find_by(id: post.user_id)
      category = Category.find_by(id: topic.category_id)
      category_link = "#{DOMAIN}/c/#{category.slug}"

      color = category.color
      mrkdwn_in = ["text"]

      title = topic.title
      title_link = post.full_url

      author_link = "#{DOMAIN}/users/#{user.username}"
      author_name = "#{user.name}"
      if (user.name.blank?)
        author_name = "@#{user.username}"
      end

      reading_time = 1+(topic.word_count/300).round
      reply_emoji = "mailbox_with_mail"
      if (topic.posts_count == 1)
        reply_emoji = "mailbox_closed"
      end

      clock_emoji = "clock#{reading_time}"
      if (reading_time > 11)
        clock_emoji = "alarm_clock"
      end
      footer = "<#{category_link}|#{category.name}> :bookmark:   |   #{reading_time} mins :#{clock_emoji}:   |   #{post.like_count} :+1:   |   #{topic.posts_count-1} :#{reply_emoji}:   |   #{post.updated_at} :spiral_calendar_pad:"

      fallback = "<#{title_link}|#{text}>"

      return { fallback: fallback, color: color, author_name: author_name, author_link: author_link, title: title, title_link: title_link, text: text, footer: footer, mrkdwn_in: mrkdwn_in}
    end

    def self.slack_search_results_message(query)
      search = Search.new(query)
      result = search.execute
      query_encoded = CGI::escape(query)
      search_link = "#{DOMAIN}/search?q=#{query_encoded}"
      initial_text = "Top 5 results for `#{query}` #{search_link}"
      if (!result.posts.any?)
        initial_text = "No results for `#{query}` #{search_link}"
      end
      attachments = []
      result.posts.each_with_index { |post, index|
        text = result.blurb(post)
        text = text.gsub(query.downcase, "*#{query}*")
        text = text.gsub(query.titleize, "*#{query}*")
        text = text.gsub(query.upcase, "*#{query}*")
        attachments[index] = slack_process_attachment(post, text)
      }
      if (attachments.length > 5)
        remaining = attachments.length - 5
        more_text = "See #{remaining} more results for `#{query}` #{search_link}"
        more_message = { fallback: more_text, text: more_text }
        attachments = attachments[0..5]
        attachments[6] = more_message
      end
      return { username: username, icon_emoji: icon_emoji, text: initial_text, mrkdwn: true, attachments: attachments }
    end

    def self.slack_message(post, channel)
      display_name = "@#{post.user.username}"
      full_name = post.user.name || ""

      if !(full_name.strip.empty?) && (full_name.strip.gsub(' ', '_').casecmp(post.user.username) != 0) && (full_name.strip.gsub(' ', '').casecmp(post.user.username) != 0)
        display_name = "#{full_name} @#{post.user.username}"
      end

      topic = post.topic

      category = (topic.category.parent_category) ? "[#{topic.category.parent_category.name}/#{topic.category.name}]": "[#{topic.category.name}]"

      icon_url = SiteSetting.slack_icon_url
      icon_url = absolute(SiteSetting.logo_small_url) if SiteSetting.slack_icon_url.empty?

      message = {
        channel: channel,
        username: SiteSetting.title,
        icon_url: icon_url.to_s,
        attachments: []
      }

      summary = {
        fallback: "#{topic.title} - #{display_name}",
        author_name: display_name,
        author_icon: post.user.small_avatar_url,
        color: '#' + topic.category.color,
        text: ::DiscourseSlack::Slack.excerpt(post.cooked, SiteSetting.slack_discourse_excerpt_length),
        mrkdwn_in: ["text"]
      }

      record = ::PluginStore.get(PLUGIN_NAME, "topic_#{post.topic.id}_#{channel}")

      if (SiteSetting.slack_access_token.empty? || post.is_first_post? || record.blank? || (record.present? &&  ((Time.now.to_i - record[:ts].split('.')[0].to_i)/ 60) >= 5 ))
        summary[:title] = "#{topic.title} #{(category === '[uncategorized]')? '' : category} #{(topic.tags.present?)? topic.tags.map {|tag| tag.name}.join(', ') : ''}"
        summary[:title_link] = post.full_url
        summary[:thumb_url] = post.full_url
      end

      message[:attachments].push(summary)
      message
    end

    def self.absolute(raw)
      url = URI(raw) rescue nil # No icon URL if not valid
      if url && url.scheme != 'mailto'
        url.host = Discourse.current_hostname if !(url.host)
        url.scheme = (SiteSetting.force_https ? "https" : "http") if !(url.scheme)
      end
      url
    end

    def self.set_filter_by_id(id, channel, filter, channel_id = nil)
      data = get_store(id)

      update = data.index {|i| i['channel'] === channel || i['channel'] === channel_id }

      if update
        data[update]['filter'] = filter
        data[update]['channel'] = channel # fix old IDs
      else
        data.push({ channel: channel, filter: filter })
      end

      data = data.uniq { |i| i['channel'] }

      ::PluginStore.set(PLUGIN_NAME, "category_#{id}", data.uniq)
    end

    def self.delete_filter(id, channel)
      data = get_store(id)
      data.delete_if do |i|
        i['channel'] === channel
      end
      ::PluginStore.set(PLUGIN_NAME, "category_#{id}", data)
    end

    def self.get_store(id)
      (::PluginStore.get(PLUGIN_NAME, "category_#{id}") || [])
    end

    def self.notify(id)
      return if SiteSetting.slack_outbound_webhook_url.blank?

      post = Post.find_by({id: id})
      return if post.blank? || (post.topic.archetype == Archetype.private_message || post.post_type != Post.types[:regular])

      http = Net::HTTP.new( ( SiteSetting.slack_access_token.empty? ) ? "hooks.slack.com" : "slack.com" , 443)
      http.use_ssl = true

      precedence = { 'mute' => 0, 'watch' => 1, 'follow' => 1 }

      uniq_func = proc { |i| i[:channel] }
      sort_func = proc { |a, b| precedence[a] <=> precedence[b] }

      items = get_store(post.topic.category_id) | get_store("*") | get_store(0)
      responses = []

      items.sort_by(&sort_func).uniq(&uniq_func).each do | i |
        next if ( i[:filter] === 'mute') || ( !(post.is_first_post?) && i[:filter] == 'follow' )

        message = slack_message(post, i[:channel])

        if !(SiteSetting.slack_access_token.empty?)
          response = nil
          uri = ""
          record = ::PluginStore.get(PLUGIN_NAME, "topic_#{post.topic.id}_#{i[:channel]}")

          if (record.present? && ((Time.now.to_i - record[:ts].split('.')[0].to_i)/ 60) < 5 && record[:message][:attachments].length < 5)
            attachments = record[:message][:attachments]
            attachments.concat message[:attachments]

            uri = URI("https://slack.com/api/chat.update" +
              "?token=#{SiteSetting.slack_access_token}" +
              "&username=#{CGI::escape(record[:message][:username])}" +
              "&text=#{CGI::escape(record[:message][:text])}" +
              "&channel=#{record[:channel]}" +
              "&attachments=#{CGI::escape(attachments.to_json)}" +
              "&ts=#{record[:ts]}"
            )
          else
            uri = URI("https://slack.com/api/chat.postMessage" +
              "?token=#{SiteSetting.slack_access_token}" +
              "&username=#{CGI::escape(message[:username])}" +
              "&icon_url=#{CGI::escape(message[:icon_url])}" +
              "&channel=#{ message[:channel].gsub('#', '') }" +
              "&attachments=#{CGI::escape(message[:attachments].to_json)}"
            )
          end

          response = http.request(Net::HTTP::Post.new(uri))

          ::PluginStore.set(PLUGIN_NAME, "topic_#{post.topic.id}_#{i[:channel]}", JSON.parse(response.body) )
        elsif !(SiteSetting.slack_outbound_webhook_url.empty?)
          req = Net::HTTP::Post.new(URI(SiteSetting.slack_outbound_webhook_url), 'Content-Type' =>'application/json')
          req.body = message.to_json
          response = http.request(req)
        end

        responses.push(response.body) if response
      end

      responses
    end
  end

  DiscourseEvent.on(:post_created) do |post|
    Jobs.enqueue_in(SiteSetting.post_to_slack_window_secs.seconds, :notify_slack, post_id: post[:id]) if SiteSetting.slack_enabled?
  end

  DiscourseSlack::Engine.routes.draw do
    post "/knock" => "slack#knock"
    post "/command" => "slack#command"

    post "/test" => "slack#test_notification"
    post "/reset_settings" => "slack#reset_settings"

    get "/list" => "slack#list", constraints: AdminConstraint.new
    post "/list" => "slack#edit", constraints: AdminConstraint.new
    delete "/list" => "slack#delete", constraints: AdminConstraint.new

  end

  Discourse::Application.routes.prepend do
    mount ::DiscourseSlack::Engine, at: "/slack"
  end

  add_admin_route "slack.title", "slack"

  Discourse::Application.routes.append do
    get "/admin/plugins/slack" => "admin/plugins#index"
    get "/admin/plugins/slack/list" => "slack#list"
  end
end
