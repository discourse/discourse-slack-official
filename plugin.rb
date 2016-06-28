# name: discourse-slack-official
# about: This is intended to be a feature-rich plugin for slack-discourse integration
# version: 2.0.2
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

  require_dependency 'application_controller'
  require_dependency 'discourse_event'

  class ::DiscourseSlack::SlackController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_filter :slack_enabled?
    before_filter :slack_username_present?
    before_filter :slack_token_valid?
    before_filter :slack_outbound_webhook_url_present?

    def slack_enabled?
      raise Discourse::NotFound unless SiteSetting.slack_enabled
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
            cat_list = (CategoryList.new(Guardian.new User.find_by_username(SiteSetting.slack_discourse_username)).categories.map { |category| category.slug }).join(', ')
            render json: { text: "I can't find the *#{tokens[1]}* category. Did you mean: #{cat_list}" }
          end
        else
          render json: { text: (DiscourseSlack::Slack.help()) }
        end
      when "help"
        render json: { text: (DiscourseSlack::Slack.help()) }
      when "status"
        render json: { text: (DiscourseSlack::Slack.status()) }
      else
        render json: { text: (DiscourseSlack::Slack.help()) }
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
    # TODO Inefficient
    def self.status()
      rows = PluginStoreRow.where(plugin_name: PLUGIN_NAME)
      text = ""

      categories = rows.map { |item| item.key.gsub('category_', '').to_i }

      Category.where(id: categories).each do | category |
        #why
        get_store(category.id).each do |row|
          unless row[:filter] === 'mute'
            text << "<##{row[:channel]}> is #{row[:filter]}ing category *#{category.name}*\n"
          end
        end
      end

      get_store('*').each do |row|
        unless row[:filter] === 'mute'
          text << "<##{row[:channel]}> is #{row[:filter]}ing *all categories*\n"
        end
      end

      text
    end

    def self.help()
      response = %(
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
 
      if !(full_name.strip.empty?) && (full_name.strip.gsub(' ', '_').casecmp(post.user.username) != 0)
        display_name = "#{full_name} @#{post.user.username}"
      end
      
      topic = post.topic

      category = (topic.category.parent_category) ? "[#{topic.category.parent_category.name}/#{topic.category.name}]": "[#{topic.category.name}]"
      
      icon_url = URI(SiteSetting.logo_small_url) rescue nil # No icon URL if not valid
      icon_url.host = Discourse.current_hostname if icon_url != nil && !(icon_url.host)
      icon_url.scheme = (SiteSetting.use_https ? "https" : "http") if icon_url != nil && !(icon_url.scheme)

      response = {
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

            text: post.excerpt(SiteSetting.slack_discourse_excerpt_length, text_entities: true, strip_links: true),

            fields: [
              #{
              #  "title": "Likes",
              #  "value": "#{post.like_count} \xF0\x9F\x92\x9A",
              #  "short": true
              #},

              #{
              #  "title": "Responses",
              #  "value": "#{topic.posts_count} \xE2\x9C\x89",
              #  "short": true
              #}
              # {
              #   "title": "Reading time",
              #   "value": "#{TODO TopicView} mins \xF0\x9F\x95\x91",
              #   "short": true
              # }
            ]

            #ts: post.topic.created_at.to_i,
            #footer: SiteSetting.title,
            #footer_icon: SiteSetting.favicon_url
          }
        ]
      }
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

      response = "*#{filter.capitalize}ed* category *#{category.name}*"
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

      response = "*#{filter.capitalize}ed all categories* on this channel."
    end

    def self.get_store(id)
      (::PluginStore.get(PLUGIN_NAME, "category_#{id}") || [])
    end

    def self.notify(post)
      # TODO Post other types and PMs later 
      return if (post.archetype == Archetype.private_message || post.post_type != Post.types[:regular])

      uri = URI(SiteSetting.slack_outbound_webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      filter = proc { |i| (post.is_first_post?) ? (i['filter'] === 'watch' || i['filter'] === 'follow') : (i['filter'] === 'watch') }
      items = []

      items |= get_store(post.topic.category_id).select(&filter)
      items |= get_store("*").select(&filter)

      (items.uniq { |i| i['channel'] } ).each do | i |
        req = Net::HTTP::Post.new(uri, initheader = {'Content-Type' =>'application/json'})
        req.body = slack_message(post, i['channel']).to_json
        res = http.request(req)
      end
    end
  end

  DiscourseEvent.on(:post_created) do |post|
    DiscourseSlack::Slack.notify(post)
  end
    
  DiscourseSlack::Engine.routes.draw do
    post "/knock" => "slack#knock"
    post "/command" => "slack#command" 
  end

  Discourse::Application.routes.prepend do
    mount ::DiscourseSlack::Engine, at: "/slack"
  end
end
