# name: discourse-slack-official
# about: This is intended to be a feature-rich plugin for slack-discourse integration
# version: 0.0.1
# authors: Nick Sahler (nicksahler)
# url: https://github.com/nicksahler/discourse-slack-official

gem "websocket", "1.2.3"
gem "websocket-native", "1.0.0"
gem 'websocket-eventmachine-base', '1.2.0'
gem 'websocket-eventmachine-client', '1.1.0'

require 'net/http'
require 'json'
require 'optparse'

enabled_site_setting :slack_enabled

PLUGIN_NAME = "discourse-slack-official".freeze
P_FOLLOWING = "following_".freeze

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
      join_slack
    end

    def self.follow(id, set)
      f = load_set(set)
      f.push(id)
      f.uniq!

      ::PluginStore.set(PLUGIN_NAME, P_FOLLOWING + set, f)
    end
    
    def self.unfollow(id, set)
      f = load_set(set)
      f.delete(id)
      f.uniq!

      ::PluginStore.set(PLUGIN_NAME, P_FOLLOWING + set, f)
    end

    def self.following?(id, set)
      f = load_set(set)
      (f != nil && f.include?(id))
    end

    def self.load_set(set)
      f = ::PluginStore.get(PLUGIN_NAME, P_FOLLOWING + set)
      f || []
    end

    def join_slack &block
      url = 'https://slack.com/api/rtm.start?token=' + (SiteSetting.bot_token || 'null')
      uri = URI(url)
      response = JSON.parse( Net::HTTP.get(uri) )

      @me = response["self"]

   
      EM.schedule do 
        @ws = WebSocket::EventMachine::Client.connect(:uri => (response["url"] || nil))
      
        @ws.onopen do
          block.call @ws if block
        end

        @ws.onmessage do |msg, type|
          obj = JSON.parse(msg)
          puts "Received message: #{msg.to_str}"

          if obj["type"].eql?("message") && obj["text"] && obj["text"].include?(@me["id"])
            tokens = obj["text"].split(" ")
            puts tokens
            if tokens.size == 4
              cat = Category.find_by_slug(tokens[3])
              if cat
                self.follow(cat.id, 'categories')
                post_message cat.slug
              else
                post_message "No such category"
              end
            elsif tokens.size == 3
            end
          end
        end

        @ws.onclose do |code, reason|
          puts "Disconnected with status code: #{code}\n #{reason}"
        end
      end
    end

    def post_message(text)
      unless !@ws
        EventMachine.next_tick do
          message = {
            "id" => 1,
            "type" => "message",
            "channel" => "G1APTF02F",
            "text" => text
          }

          @ws.send message.to_json
        end
      else
        join_slack { post_message text }
      end
    end
  end

  require_dependency 'application_controller'
  require_dependency 'discourse_event'

  instance = ::DiscourseSlack::Slack.new

  class ::DiscourseSlack::SlackController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_filter :slack_enabled?

    def slack_enabled?
      raise Discourse::NotFound unless SiteSetting.slack_enabled
    end
  end

  DiscourseEvent.on(:post_created) do |post|
    if instance.following?(post.topic_id, "topics")
      instance.post_message("Post #{post.id} posted to tracked topic #{post.topic_id}")
    end
  end

  DiscourseEvent.on(:topic_created) do |topic|
    instance.follow(4, 'categories')    
    if instance.following?(topic.category_id, "categories")
      instance.post_message("Topic #{topic.id} posted to tracked category #{topic.category_id}\n#{topic.url}")
    end
  end

end