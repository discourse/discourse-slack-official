# name: discourse-slack-official
# about: This is intended to be a feature-rich plugin for slack-discourse integration
# version: 1.0.0
# authors: Nick Sahler (nicksahler), Dave McClure (mcwumbly) for slack backdoor code.
# url: https://github.com/nicksahler/discourse-slack-official

require 'net/http'
require 'json'
require File.expand_path('../lib/validators/discourse_slack_enabled_setting_validator.rb', __FILE__)

enabled_site_setting :slack_enabled

PLUGIN_NAME = "discourse-slack-official".freeze

register_asset "stylesheets/slack_admin.scss"

after_initialize do
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
    before_filter :slack_username_present?
    before_filter :slack_token_valid?, :except => [:list, :edit, :delete]
    skip_before_filter :check_xhr, :preload_json, :verify_authenticity_token, except: [:list, :edit, :delete]
    before_filter :slack_outbound_webhook_url_present?

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

    def is_number? string
      true if Float(string) rescue false
    end

    # "0" on the client is usde to represent "all categories" - "*" on the server, to support old versions of the plugin.
    def edit
      return render json: { message: "Error"}, status: 500 if params[:channel] == '' || !is_number?(params[:category_id])
      DiscourseSlack::Slack.set_filter_by_id(( params[:category_id] === "0") ? '*' : params[:category_id], params[:channel], params[:filter])
      render json: { message: "Success" }
    end

    def delete
      return render json: { message: "Error"}, status: 500 if params[:channel] == '' || !is_number?(params[:category_id])

      DiscourseSlack::Slack.delete_filter('*', params[:channel]) if ( params[:category_id] === "0" )
      DiscourseSlack::Slack.delete_filter(params[:category_id], params[:channel])

      render json: { message: "Success" }
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

      if tokens.size > 0 && tokens.size < 3
        cmd = tokens[0]
      end
      ## TODO Put back URL finding
      case cmd
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

    def slack_username_present?
      raise Discourse::InvalidAccess.new unless SiteSetting.slack_discourse_username
    end

    def slack_outbound_webhook_url_present?
      raise Discourse::InvalidAccess.new if SiteSetting.slack_outbound_webhook_url.blank?
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
      `/discourse [watch|follow|mute|help|status] [category|all]`
*watch* – notify this channel for new topics and new replies
*follow* – notify this channel for new topics
*mute* – stop notifying this channel
*status* – show current notification state and categories
)
    end

    def self.slack_message(post, channel)
      display_name = "@#{post.user.username}"
      full_name = post.user.name || ""

      if !(full_name.strip.empty?) && (full_name.strip.gsub(' ', '_').casecmp(post.user.username) != 0) && (full_name.strip.gsub(' ', '').casecmp(post.user.username) != 0)
        display_name = "#{full_name} @#{post.user.username}"
      end

      topic = post.topic

      category = (topic.category.parent_category) ? "[#{topic.category.parent_category.name}/#{topic.category.name}]": "[#{topic.category.name}]"

      icon_url = absolute(SiteSetting.logo_small_url)

      {
        channel: channel,
        username: SiteSetting.title,
        icon_url: icon_url.to_s,

        attachments: [
          {
            fallback: "#{topic.title} - #{display_name}",
            author_name: display_name,
            author_icon: post.user.small_avatar_url,

            color: '#' + topic.category.color,

            title: "#{topic.title} #{(category === '[uncategorized]')? '' : category} #{(topic.tags.present?)? topic.tags.map {|tag| tag.name}.join(', ') : ''}",
            title_link: post.full_url,
            thumb_url: post.full_url,

            text: ::DiscourseSlack::Slack.excerpt(post.cooked, SiteSetting.slack_discourse_excerpt_length),
            mrkdwn_in: ["text"]
          }
        ]
      }
    end

    def self.absolute(raw)
      url = URI(raw) rescue nil # No icon URL if not valid
      url.host = Discourse.current_hostname if url != nil && !(url.host)
      url.scheme = (SiteSetting.force_https ? "https" : "http") if url != nil && !(url.scheme)
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

    # TODO Post other types and PMs later
    def self.notify(id)
      post = Post.find_by({id: id})
      return if !(post) || (post.archetype == Archetype.private_message || post.post_type != Post.types[:regular])

      uri = URI(SiteSetting.slack_outbound_webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      precedence = { 'mute' => 0, 'watch' => 1, 'follow' => 1 }

      uniq_func = proc { |i| i['channel'] }
      sort_func = proc { |a, b| precedence[a] <=> precedence[b] }

      items = get_store(post.topic.category_id) | get_store("*") | get_store(0)

      items.sort_by(&sort_func).uniq(&uniq_func).each do | i |
        next if (i[:filter] === 'mute') || ( !(post.is_first_post?) && i[:filter] == 'follow' )
        req = Net::HTTP::Post.new(uri, 'Content-Type' =>'application/json')
        req.body = slack_message(post, i[:channel]).to_json
        http.request(req)
      end
    end
  end

  DiscourseEvent.on(:post_created) do |post|
    Jobs.enqueue(:notify_slack, post_id: post[:id]) if SiteSetting.slack_enabled?
  end

  DiscourseSlack::Engine.routes.draw do
    post "/knock" => "slack#knock"
    post "/command" => "slack#command"

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
