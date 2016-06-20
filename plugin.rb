# name: discourse-slack-official
# about: This is intended to be a feature-rich plugin for slack-discourse integration
# version: 1.0.2
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
      tokens = params[:text].split(" ")
      channel = params[:channel_id]
      if tokens.size == 2
        begin
          uri = URI.parse tokens[1]
          path = Rails.application.routes.recognize_path(uri.path.sub(Discourse.base_url, ""))

          follow_words = ['follow', 'f', 'subscribe', 'sub', 's', 'track', 't', 'add', 'a']
          unfollow_words = ['unfollow', 'u', 'unsubscribe', 'unsub', 'untrack', 'remove', 'r']
          
          id = nil
          collection = nil
          name = nil

          case path[:controller]

          when "topics"
            topic = find_topic(path[:topic_id], 1)
            id = path[:topic_id]
            name = topic.title
            collection = "topics"
          when "list"
            cat = Category.find_by(slug: path[:category]) || Category.find_by(id: path[:category].to_i)
            id = cat.id
            name = cat.name
            collection = "categories"
          end

          if follow_words.include?(tokens[0])
            DiscourseSlack::Slack.follow(collection, id, channel)
            render json: { text: "Added *#{name}* to followed #{collection}" }
          elsif unfollow_words.include?(tokens[0])
            DiscourseSlack::Slack.unfollow(collection, id, channel)
            render json: { text: "Removed *#{name}* from followed #{collection}" }
          end

        rescue URI::InvalidURIError
          render json: { text: "I'm sorry, <@#{params[:user_id]}>, that's not a valid URL!" }
        rescue Exception => e 
          render json: { text: "There was an error in discourse! Please contact your admin.\n ```#{e.message}\n\n #{e.backtrace.inspect}```"}
        end  
      end
    end

    def knock
      route = topic_route params[:text]
      post_number = route[:post_number] ? route[:post_number].to_i : 1

      topic = find_topic(route[:topic_id], post_number)
      post = find_post(topic, post_number)

      render json: Slack.slack_message(post)
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


    # Access control methods
    def handle_unverified_request
    end

    def api_key_valid?
      true
    end

    def redirect_to_login_if_required
    end
  end

  class ::DiscourseSlack::Slack
    def self.slack_message(post, channel)
      display_name = "@#{post.user.username}"
      full_name = post.user.name || ""
 
      if !(full_name.strip.empty?) && (full_name.strip.gsub(' ', '_').casecmp(post.user.username) != 0)
        display_name = "#{full_name} @#{post.user.username}"
      end
      
      topic = post.topic

      #pretext = post.try(:is_first_post?) ? "#{display_name} [#{topic.category.name}]" : display_name
      category = (topic.category.parent_category) ? "#{topic.category.parent_category.name}/#{topic.category.name}": "#{topic.category.name}"

      response = {
        channel: channel,
        username: SiteSetting.title,
        icon_url: SiteSetting.logo_small_url,

        attachments: [
          {
            fallback: "#{topic.title} - #{display_name}",
            author_name: display_name,
            author_icon: post.user.small_avatar_url,

            color: '#' + topic.category.color,

            title: "#{topic.title} [#{category}] #{(topic.tags.present?)? topic.tags.map {|tag| tag.name}.join(', ') : ''}",
            title_link: post.full_url,
            thumb_url: post.full_url,

            text: post.excerpt(400, text_entities: true, strip_links: true),

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

    def self.follow(collection, id, channel)
      data = store_get(collection, id)
      data.push(channel)
      store_set(collection, id, data)
    end
    
    def self.unfollow(collection, id, channel)
      data = store_get(collection, id)
      data.delete(channel)
      store_set(collection, id, data)
    end

    def self.following?(collection, id, channel)
      d = store_get(collection, id)
      # Either you're following that list *somewhere*, or a specific channel
      (d != nil) && ((d.length > 0) || (channel != nil && d.include?(channel)))
    end

    def self.store_get(collection, id)
      d = ::PluginStore.get(PLUGIN_NAME, "following_#{collection}_#{id}")
      (d || []).uniq
    end

    def self.store_set(collection, id, data)
      ::PluginStore.set(PLUGIN_NAME, "following_#{collection}_#{id}", data.uniq)
    end

    def self.notify(post)
      uri = URI(SiteSetting.slack_outbound_webhook_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      channels = (post.is_first_post?) ? store_get("categories", post.topic.category_id) : store_get("topics", post.topic_id)

      channels.uniq.each do |channel|
        req = Net::HTTP::Post.new(uri, initheader = {'Content-Type' =>'application/json'})
        req.body = slack_message(post, channel).to_json
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
