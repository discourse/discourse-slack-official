require 'rails_helper'

describe 'Slack', type: :request do
  let(:first_post) { Fabricate(:post) }
  let(:topic) { Fabricate(:topic, posts: [first_post]) }
  let(:admin) { Fabricate(:admin) }
  let(:category) { Fabricate(:category) }
  let(:tag) { Fabricate(:tag) }

  before do
    SiteSetting.slack_outbound_webhook_url = "https://hooks.slack.com/services/abcde"
    SiteSetting.slack_enabled = true
  end

  shared_examples 'admin constraints' do |action, route|
    context 'when user is not signed in' do
      it 'should raise the right error' do
        expect { send(action, route) }.to raise_error(ActionController::RoutingError)
      end
    end

    context 'when user is not an admin' do
      it 'should raise the right error' do
        sign_in(Fabricate(:user))
        expect { send(action, route) }.to raise_error(ActionController::RoutingError)
      end
    end
  end

  describe 'viewing filters' do
    include_examples 'admin constraints', 'get', '/slack/list.json'

    context 'when signed in as an admin' do
      before do
        sign_in(admin)
      end

      it 'should return the right response' do
        DiscourseSlack::Slack.set_filter_by_id(category.id, '#some', 'follow', [tag.name])

        get '/slack/list.json'

        expect(response).to be_success

        filters = JSON.parse(response.body)['slack']

        expect(filters.count).to eq(1)

        expect(filters.first).to eq(
          "channel" => "#some",
          "category_id" => category.id.to_s,
          "tags" => [tag.name],
          "filter" => "follow"
        )
      end
    end
  end

  describe 'adding a filter' do
    include_examples 'admin constraints', 'put', '/slack/list.json'

    context 'as an admin' do
      let(:tag) { Fabricate(:tag) }

      before do
        sign_in(admin)
      end

      it 'should be able to add a new filter' do
        channel = '#hello'
        category_id = 1
        filter = 'follow'

        put '/slack/list.json',
          channel: channel,
          category_id: category_id,
          filter: filter,
          tags: [tag.name, 'sometag']

        expect(response).to be_success

        data = DiscourseSlack::Slack.get_store(category_id)

        expect(data).to eq([
          "channel" => channel,
          "filter" => filter,
          "tags" => [tag.name]
        ])
      end
    end
  end

  describe 'removing a filter' do
    include_examples 'admin constraints', 'delete', '/slack/list.json'

    describe 'as an admin' do
      before do
        sign_in(admin)
      end

      it 'should be able to delete a filter' do
        DiscourseSlack::Slack.set_filter_by_id(category.id, '#some', 'follow', [tag.name])

        delete '/slack/list.json',
          category_id: category.id,
          channel: '#some',
          tags: [tag.name]

        expect(DiscourseSlack::Slack.get_store(category.id)).to eq([])
      end
    end
  end

  describe 'testing notification' do
    include_examples 'admin constraints', 'put', '/slack/test.json'
  end

  describe 'slash commands endpoint' do
    describe 'when forum is private' do
      it 'should not redirect to login page' do
        SiteSetting.login_required = true
        token = 'sometoken'
        SiteSetting.slack_incoming_webhook_token = token

        post '/slack/command.json', text: 'help', token: token

        expect(response.status).to eq(200)
      end
    end

    describe 'when the token is invalid' do
      it 'should raise the right error' do
        expect { post '/slack/command.json', text: 'help' }
          .to raise_error(ActionController::ParameterMissing)
      end
    end

    describe 'when incoming webhook token has not been set' do
      it 'should raise the right error' do
        post '/slack/command.json', text: 'help', token: 'some token'

        expect(response.status).to eq(403)
      end
    end

    describe 'when token is valid' do
      let(:token) { "Secret Sauce" }

      before do
        SiteSetting.slack_incoming_webhook_token = token
      end

      describe 'follow command' do
        it 'should add the new filter correctly' do
          post "/slack/command.json",
            text: "follow #{category.slug}",
            channel_name: 'welcome',
            token: token

          json = JSON.parse(response.body)

          expect(json["text"]).to eq(I18n.t(
            "slack.message.success.category", command: "Followed", name: category.name
          ))

          expect(DiscourseSlack::Slack.get_store(category.id)).to eq([
            "channel" => "#welcome",
            "filter" => "follow",
            "tags" => nil
          ])
        end

        it 'should add the a new tag filter correctly' do
          SiteSetting.tagging_enabled = true

          post "/slack/command.json",
            text: "follow tag:#{tag.name}",
            channel_name: 'welcome',
            token: token

          json = JSON.parse(response.body)

          expect(json["text"]).to eq(I18n.t(
            "slack.message.success.tag", command: "Followed", name: tag.name
          ))

          expect(DiscourseSlack::Slack.get_store).to eq([
            "channel" => "#welcome",
            "filter" => "follow",
            "tags" => [tag.name]
          ])
        end
      end

      describe 'mute command' do
        it 'should the new filter correctly' do
          post "/slack/command.json",
            text: "mute #{category.slug}",
            channel_name: 'welcome',
            token: token

          json = JSON.parse(response.body)

          expect(json["text"]).to eq(I18n.t(
            "slack.message.success.category", command: "Muted", name: category.name
          ))

          expect(DiscourseSlack::Slack.get_store(category.id)).to eq([
            "channel" => "#welcome",
            "filter" => "mute",
            "tags" => nil
          ])
        end

        it 'should add the a new tag filter correctly' do
          SiteSetting.tagging_enabled = true

          post "/slack/command.json",
            text: "mute tag:#{tag.name}",
            channel_name: 'welcome',
            token: token

          json = JSON.parse(response.body)

          expect(json["text"]).to eq(I18n.t(
            "slack.message.success.tag", command: "Muted", name: tag.name
          ))

          expect(DiscourseSlack::Slack.get_store).to eq([
            "channel" => "#welcome",
            "filter" => "mute",
            "tags" => [tag.name]
          ])
        end
      end

      describe 'help command' do
        it 'should return the right response' do
          post '/slack/command.json', text: "help", channel_name: "welcome", token: token

          expect(response).to be_success

          json = JSON.parse(response.body)

          expect(json["text"]).to eq(I18n.t("slack.help"))
        end
      end
    end
  end
end
