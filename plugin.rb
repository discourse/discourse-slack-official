# name: discourse-slack-official
# about: This is intended to be a feature-rich plugin for slack-discourse integration
# version: 1.1.1
# authors: Nick Sahler (nicksahler), Dave McClure (mcwumbly) for slack backdoor code.
# url: https://github.com/discourse/discourse-slack-official

enabled_site_setting :slack_enabled

register_asset "stylesheets/slack-admin.scss"

load File.expand_path('../lib/validators/discourse_slack_enabled_setting_validator.rb', __FILE__)

after_initialize do
  load File.expand_path('../lib/discourse_slack/slack.rb', __FILE__)
  load File.expand_path('../lib/discourse_slack/slack_message_formatter.rb', __FILE__)

  module ::DiscourseSlack
    PLUGIN_NAME = "discourse-slack-official".freeze

    class Engine < ::Rails::Engine
      engine_name DiscourseSlack::PLUGIN_NAME
      isolate_namespace DiscourseSlack
    end
  end

  require_dependency File.expand_path('../app/jobs/regular/notify_slack.rb', __FILE__)
  require_dependency 'application_controller'
  require_dependency 'discourse_event'
  require_dependency 'admin_constraint'

  class ::DiscourseSlack::SlackController < ::ApplicationController
    requires_plugin DiscourseSlack::PLUGIN_NAME

    before_filter :slack_token_valid?, only: :command

    skip_before_filter :check_xhr,
                       :preload_json,
                       :verify_authenticity_token,
                       :redirect_to_login_if_required,
                       only: :command

    def list
      out = []

      PluginStoreRow.where(plugin_name: DiscourseSlack::PLUGIN_NAME)
        .where("key ~* :pat", pat: "^#{DiscourseSlack::Slack::KEY_PREFIX}.*")
        .each do |row|

        PluginStore.cast_value(row.type_name, row.value).each do |rule|
          category_id =
            if row.key == DiscourseSlack::Slack.get_key
              nil
            else
              row.key.gsub!(DiscourseSlack::Slack::KEY_PREFIX, '')
              row.key
            end

          out << {
            category_id: category_id,
            channel: rule[:channel],
            filter: rule[:filter],
            tags: rule[:tags]
          }
        end
      end

      render json: out
    end

    def test_notification
      DiscourseSlack::Slack.notify(
        Topic.order('RANDOM()')
          .find_by(closed: false, archived: false)
          .ordered_posts.first.id
      )

      render json: success_json
    end

    def reset_settings
      PluginStoreRow.where(plugin_name: DiscourseSlack::PLUGIN_NAME).destroy_all
      render json: success_json
    end

    def edit
      params.permit(:tags, :category_id, :filter, :channel)

      DiscourseSlack::Slack.set_filter_by_id(params[:category_id], params[:channel], params[:filter], params[:tags])
      render json: success_json
    end

    def delete
      params.permit(:tags, :channel, :category_id)

      DiscourseSlack::Slack.delete_filter(params[:category_id], params[:channel], params[:tags])
      render json: success_json
    end

    def search
      params.permit(:query)
      DiscourseSlack::Slack.search(params[:query])
      render json: success_json
    end

    def command
      guardian = DiscourseSlack::Slack.guardian

      tokens = params[:text].split(" ")

      # channel name fix
      channel =
        case params[:channel_name]
        when 'directmessage'
          "@#{params[:user_name]}"
        when 'privategroup'
          params[:channel_id]
        else
          "##{params[:channel_name]}"
        end

      cmd = tokens[0] if tokens.size > 0

      text =
        case cmd
        when "watch", "follow", "mute"
          if (tokens.size == 2)
            value = tokens[1]
            filter_to_past = DiscourseSlack::Slack.filter_to_past(cmd).capitalize

            if SiteSetting.tagging_enabled? && value.start_with?('tag:')
              value.sub!('tag:', '')
              tag = Tag.find_by(name: value)

              if !tag
                I18n.t("slack.message.not_found.tag", name: value)
              else
                DiscourseSlack::Slack.set_filter_by_id(nil, channel, cmd, [tag.name], params[:channel_id])
                I18n.t("slack.message.success.tag", command: filter_to_past, name: tag.name)
              end
            else
              if (value.casecmp("all") == 0)
                DiscourseSlack::Slack.set_filter_by_id(nil, channel, cmd, nil, params[:channel_id])
                I18n.t("slack.message.success.all_categories", command: filter_to_past)
              elsif (category = Category.find_by(slug: value)) && guardian.can_see_category?(category)
                DiscourseSlack::Slack.set_filter_by_id(category.id, channel, cmd, nil, params[:channel_id])
                I18n.t("slack.message.success.category", command: filter_to_past, name: category.name)
              else
                cat_list = (CategoryList.new(guardian).categories.map(&:slug)).join(', ')
                I18n.t("slack.message.not_found.category", name: tokens[1], list: cat_list)
              end
            end
          else
            DiscourseSlack::Slack.help
          end
        when "search"
          if (tokens.size >= 2)
            query = tokens[1..tokens.size-1].join(" ")
            DiscourseSlack::Slack.search(query)
          else
            DiscourseSlack::Slack.help
          end
        when "status"
          DiscourseSlack::Slack.status(channel)
        else
          DiscourseSlack::Slack.help
        end

      render json: { text: text }
    end

    def slack_token_valid?
      params.require(:token)

      if SiteSetting.slack_incoming_webhook_token.blank? ||
         SiteSetting.slack_incoming_webhook_token != params[:token]

        raise Discourse::InvalidAccess.new
      end
    end

    def topic_route(text)
      url = text.slice(text.index("<") + 1, text.index(">") -1)
      url.sub!(Discourse.base_url, '')
      route = Rails.application.routes.recognize_path(url)
      raise Discourse::NotFound unless route[:controller] == 'topics' && route[:topic_id]
      route
    end

    def find_post(topic, post_number)
      topic.filtered_posts.where(post_number: post_number).first
    end

    def find_topic(topic_id, post_number)
      user = User.find_by(username: SiteSetting.slack_discourse_username)
      TopicView.new(topic_id, user, post_number: post_number)
    end
  end

  if !PluginStore.get(DiscourseSlack::PLUGIN_NAME, "not_first_time") && !Rails.env.test?
    PluginStore.set(DiscourseSlack::PLUGIN_NAME, "not_first_time", true)
    PluginStore.set(DiscourseSlack::PLUGIN_NAME, DiscourseSlack::Slack.get_key, [{ channel: "#general", filter: "follow", tags: nil }])
  end

  DiscourseEvent.on(:post_created) do |post|
    if SiteSetting.slack_enabled?
      Jobs.enqueue_in(SiteSetting.post_to_slack_window_secs.seconds,
        :notify_slack,
        post_id: post.id
      )
    end
  end

  DiscourseSlack::Engine.routes.draw do
    post "/command" => "slack#command"

    get "/list" => "slack#list", constraints: AdminConstraint.new
    put "/test" => "slack#test_notification", constraints: AdminConstraint.new
    put "/reset_settings" => "slack#reset_settings", constraints: AdminConstraint.new
    put "/list" => "slack#edit", constraints: AdminConstraint.new
    delete "/list" => "slack#delete", constraints: AdminConstraint.new
  end

  Discourse::Application.routes.prepend do
    mount ::DiscourseSlack::Engine, at: "/slack"
  end

  add_admin_route "slack.title", "slack"

  Discourse::Application.routes.append do
    get "/admin/plugins/slack" => "admin/plugins#index", constraints: StaffConstraint.new
  end
end
