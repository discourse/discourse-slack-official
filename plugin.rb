# name: discourse-slack-official
# about: This is intended to be a feature-rich plugin for slack-discourse integration
# version: 2.2.2
# authors: Nick Sahler (nicksahler), Dave McClure (mcwumbly) for slack backdoor code.
# url: https://github.com/nicksahler/discourse-slack-official

require 'net/http'
require 'json'

enabled_site_setting :slack_enabled

PLUGIN_NAME = "discourse-slack-official".freeze

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

  require_relative 'slack_parser'

  class ::DiscourseSlack::SlackController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_filter :slack_enabled?
    before_filter :slack_username_present?
    before_filter :slack_token_valid?
    before_filter :slack_outbound_webhook_url_present?

    def slack_enabled?
      raise Discourse::NotFound unless SiteSetting.slack_enabled?
    end

    def command
      guardian = Guardian.new(User.find_by_username(SiteSetting.slack_discourse_username))

      tokens = params[:text].split(" ")
      channel = params[:channel_id]
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
            render json: { text: DiscourseSlack::Slack.set_filter_all(channel, cmd) }
          elsif (category && guardian.can_see_category?(category))
            render json: { text: DiscourseSlack::Slack.set_filter(category, channel, cmd) }
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
        render json: { text: DiscourseSlack::Slack.status }
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
      raise Discourse::InvalidAccess.new unless SiteSetting.slack_incoming_webhook_token
      raise Discourse::InvalidAccess.new unless SiteSetting.slack_incoming_webhook_token == params[:token]
    end

    def slack_username_present?
      raise Discourse::InvalidAccess.new unless SiteSetting.slack_discourse_username
    end

    def slack_outbound_webhook_url_present?
      raise Discourse::InvalidAccess.new unless SiteSetting.slack_outbound_webhook_url
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

    def self.status
      rows = PluginStoreRow.where(plugin_name: PLUGIN_NAME)
      text = ""

      categories = rows.map { |item| item.key.gsub('category_', '').to_i }

      Category.where(id: categories).each do | category |
        #why
        get_store(category.id).each do |row|
          text << "<##{row[:channel]}> is #{filter_to_present(row[:filter])} category *#{category.name}*\n"
        end
      end

      get_store('*').each do |row|
        text << "<##{row[:channel]}> is #{filter_to_present(row[:filter])} *all categories*\n"
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

    # TODO Not very efficient
    def self.set_filter(category, channel, filter)
      data = get_store(category.id)
      update = data.index {|i| i['channel'] === channel}

      if update
        data[update]['filter'] = filter
      else
        data.push({ channel: channel, filter: filter })
      end

      ::PluginStore.set(PLUGIN_NAME, "category_#{category.id}", data)

      "*#{filter_to_past(filter).capitalize}* category *#{category.name}*"
    end

    def self.set_filter_all(channel, filter)
      data = get_store('*')
      update = data.index {|i| i['channel'] === channel}

      if update
        data[update]['filter'] = filter
      else
        data.push({ channel: channel, filter: filter })
      end

      ::PluginStore.set(PLUGIN_NAME, "category_*", data)

      "*#{filter_to_past(filter).capitalize} all categories* on this channel."
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

      items = get_store(post.topic.category_id) | get_store("*")

      items.sort_by(&sort_func).uniq(&uniq_func).each do | i |
        next if (i[:filter] === 'mute') || (( post.is_first_post? && i[:filter] != 'follow' ) && (i[:filter] != 'watch'))
        req = Net::HTTP::Post.new(uri, 'Content-Type' =>'application/json')
        req.body = slack_message(post, i[:channel]).to_json
        http.request(req)
      end
    end
  end

  DiscourseEvent.on(:post_created) do |post|
    Jobs.enqueue(:notify_slack, post: post[:id]) if SiteSetting.slack_enabled?
  end

  DiscourseSlack::Engine.routes.draw do
    post "/knock" => "slack#knock"
    post "/command" => "slack#command"
  end

  Discourse::Application.routes.prepend do
    mount ::DiscourseSlack::Engine, at: "/slack"
  end
end
