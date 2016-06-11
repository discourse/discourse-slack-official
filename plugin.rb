# name: discourse-slack-official
# about: This is intended to be a feature-rich plugin for slack-discourse integration
# version: 0.0.1
# authors: Nick Sahler (nicksahler), Dave McClure (mcwumbly) for slack backdoor code.
# url: https://github.com/nicksahler/discourse-slack-official

gem "websocket", "1.2.3"
gem "websocket-native", "1.0.0"
gem "websocket-eventmachine-base", "1.2.0"
gem "websocket-eventmachine-client", "1.1.0"

require 'net/http'
require 'json'
require 'optparse'

enabled_site_setting :slack_enabled

PLUGIN_NAME = "discourse-slack-official".freeze

after_initialize do
  module ::DiscourseSlack
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscourseSlack
    end
  end

  class ::DiscourseSlack::Slack
    @ws = nil
    @me = nil

    def initialize
      if SiteSetting.slack_enabled
        join_slack
      end
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
      d || []
    end

    def self.store_set(collection, id, data)
      data.uniq!
      ::PluginStore.set(PLUGIN_NAME, "following_#{collection}_#{id}", data)
    end

    def join_slack &block
      url = "https://slack.com/api/rtm.start?token=#{SiteSetting.slack_bot_token}"
      uri = URI(url)
      response = JSON.parse( Net::HTTP.get(uri) )

      @me = response["self"]

      # TODO move handlers
      EM.schedule do 
        @ws = WebSocket::EventMachine::Client.connect(:uri => (response["url"] || nil))
      
        @ws.onopen do
          block.call @ws if block
        end

        @ws.onmessage do |msg, type|
          obj = JSON.parse(msg, {:symbolize_names => true})
          puts "Received message: #{msg.to_str}"

          if obj[:type].eql?("message") && obj[:text] && obj[:text].include?(@me["id"])
            tokens = obj[:text].split(" ")
            puts tokens

            if tokens.size == 4
              # Fix / flesh this out later
              #cat = Category.find_by_slug(tokens[3])
              #if cat
              #  self.class.follow(cat.id, 'categories')
              #end
            elsif tokens.size == 3
              begin
                uri = URI.parse tokens[2][1.. (tokens[2].length - 2)] # Strip out slack bracket thingies.
                path = Rails.application.routes.recognize_path(uri.path.sub(Discourse.base_uri, ""))
                puts path

                follow_words = ['follow', 'f', 'subscribe', 'sub', 's', 'track', 't', 'add', 'a']
                unfollow_words = ['unfollow', 'u', 'unsubscribe', 'unsub', 'untrack', 'remove', 'r']
                
                id = nil
                collection = nil

                case path[:controller]
                when "topics"
                  # Find post.
                  id = path[:topic_id]
                  collection = "topics"
                when "list"
                  # Flatten to ID since controller gives whatever. Maybe a bit much. Might be a better way to do this. Ensures no dupes(?)
                  # same as fetch_category. Maybe a security issue? Will filter by permission later.
                  cat = Category.find_by(slug: path[:category]) || Category.find_by(id: path[:category].to_i)
                  id = cat.id
                  collection = "categories"
                end

                if follow_words.include?(tokens[1])
                  self.class.follow(collection, id, obj[:channel])
                  post_message "Added #{id} to followed #{collection}", obj[:channel]
                elsif unfollow_words.include?(tokens[1])
                  self.class.unfollow(collection, id, obj[:channel])
                  post_message "Removed #{id} from followed #{collection}", obj[:channel]
                end

              rescue URI::InvalidURIError
                post_message "I'm sorry, <@#{obj[:user]}>, that's not a valid URL!", obj[:channel]
              rescue Exception => e 
                # TODO Move to rails logger
                #post_message "```\n" + e.message + "\n```", obj[:channel] 
                #post_message  "```\n"  + e.backtrace.inspect + "\n```", obj[:channel]
                #post_message "Oopsies.", obj[:channel]
       
              end  
            end
          end
        end

        @ws.onclose do |code, reason|
          puts "Disconnected with status code: #{code}\n Message: #{reason}"
        end
      end
    end

    def post_message(text, channel)
      unless !@ws
        EventMachine.next_tick do
          message = {
            "id" => 1,
            "type" => "message",
            "channel" => channel,
            "text" => text
          }

          @ws.send message.to_json
        end
      else
        join_slack { post_message text, channel }
      end
    end
  end

  require_dependency 'application_controller'
  require_dependency 'discourse_event'

  instance = ::DiscourseSlack::Slack.new

  class ::DiscourseSlack::SlackController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_filter :slack_enabled?
    before_filter :slack_username_present?
    before_filter :slack_token_valid?

    def slack_enabled?
      raise Discourse::NotFound unless SiteSetting.slack_enabled
    end

    def knock
      route = topic_route params[:text]
      post_number = route[:post_number] ? route[:post_number].to_i : 1

      topic = find_topic(route[:topic_id], post_number)
      post = find_post(topic, post_number)

      render json: slack_message(topic, post)
    end

    def slack_token_valid?
      raise Discourse::InvalidAccess.new unless SiteSetting.slack_webhook_token
      raise Discourse::InvalidAccess.new unless SiteSetting.slack_webhook_token == params[:token]
    end

    def slack_username_present?
      raise Discourse::InvalidAccess.new unless SiteSetting.slack_discourse_username
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

    def slack_message(topic, post)
      display_name = post.user.name
      pretext = post.try(:is_first_post?) ? "topic by #{display_name}" : "reply by #{display_name}"
      response = {
        attachments: [
          {
            fallback: "#{topic.title} - #{pretext}",
            author_name: display_name,
            color: '#' + ColorScheme.hex_for_name('header_background'),
            pretext: pretext,
            title: topic.title,
            title_link: post.full_url,
            text: post.excerpt(400, text_entities: true, strip_links: true)
          }
        ]
      }
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

  DiscourseEvent.on(:post_created) do |post|
    ::DiscourseSlack::Slack.store_get("topics", post.topic_id).each do |channel|
      instance.post_message post.full_url, channel
    end
  end

  DiscourseEvent.on(:topic_created) do |topic|
    ::DiscourseSlack::Slack.store_get("categories", topic.category_id).each do |channel|
      instance.post_message topic.url, channel
    end
  end

  DiscourseEvent.on(:site_setting_saved) do |site_setting|
    if SiteSetting.slack_enabled
      instance.join_slack
    end
  end

  DiscourseSlack::Engine.routes.draw do
    post "/knock" => "slack/unfurl#knock"
  end

  Discourse::Application.routes.prepend do
    mount ::DiscourseSlack::Engine, at: "/slack/unfurl"
  end
end