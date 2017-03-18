require 'rails_helper'

describe ::DiscourseSlack::SlackController do
  routes { ::DiscourseSlack::Engine.routes }

  before do
    SiteSetting.slack_outbound_webhook_url = "https://hooks.slack.com/services/abcde"
    SiteSetting.slack_enabled = true
  end

  context "when logged in" do
    let!(:user) { log_in(:admin) }

    it "checking existence of default filters" do
      expect(PluginStoreRow.where(plugin_name: DiscourseSlack::PLUGIN_NAME).count).to eq(2)
      expect(PluginStore.get(DiscourseSlack::PLUGIN_NAME, "not_first_time")).to eq(true)
    end

    context '#index' do
      it "returns a list of filters" do
        xhr :get, :list
        expect(response).to be_success
        json = ::JSON.parse(response.body)
        filters = json['slack']
        expect(filters.count).to eq(1)
        expect(filters[0]).to include(
          "channel" => "#general",
          "category_id" => nil,
          "tags" => nil,
          "filter" => "follow"
        )
      end
    end

    context '#create' do
      it "creates a filter" do
        expect {
          channel, category_id, filter = "#hello", 1, "follow"
          xhr :post, :edit, { channel: channel, category_id: category_id, filter: filter }
          expect(response).to be_success
          data = DiscourseSlack::Slack.get_store(category_id)
          expect(data).to include(
            "channel" => channel,
            "filter" => filter,
            "tags" => nil
          )
        }.to change(PluginStoreRow, :count).by(1)
      end

      it "creates a filter with tags" do
        expect {
          channel, category_id, filter, tags = "#welcome", "2", "follow", ["test", "example"]
          xhr :post, :edit, { channel: channel, category_id: category_id, filter: filter, tags: tags }
          expect(response).to be_success
          data = DiscourseSlack::Slack.get_store(category_id)
          expect(data).to include(
            "channel" => channel,
            "filter" => filter,
            "tags" => tags
          )
        }.to change(PluginStoreRow, :count).by(1)
      end
    end

    context '#destroy' do

      it "deletes the filter" do
        ::DiscourseSlack::Slack.set_filter_by_id(1, "#hello", "follow")

        xhr :delete, :delete, { category_id: 1, channel: "#hello" }
        expect(response).to be_success
        expect(DiscourseSlack::Slack.get_store(1)).to eq([])
      end

      it "deletes the filter with tags" do
        ::DiscourseSlack::Slack.set_filter_by_id(1, "#hello", "follow", ["test", "example"])

        xhr :delete, :delete, { category_id: 1, channel: "#hello", tags: ["test", "example"] }
        expect(response).to be_success
        expect(DiscourseSlack::Slack.get_store(1)).to eq([])
      end

    end

    context '#update' do

      it "updates the filter with tags" do
        category_id = 1
        ::DiscourseSlack::Slack.set_filter_by_id(category_id, "#hello", "follow")
        new_channel = "welcome"
        new_tags = ["test", "example"]
        xhr :post, :edit, { channel: new_channel, category_id: category_id, filter: 'watch', tags: new_tags }
        expect(response).to be_success
        filter = ::DiscourseSlack::Slack.get_store(category_id)
        expect(filter).to include(
          "channel" => new_channel,
          "filter" => "watch",
          "tags" => new_tags
        )
      end

      it "updates the filter without tags" do
        tags = ["test", "example"]
        category_id = 1
        ::DiscourseSlack::Slack.set_filter_by_id(category_id, "#hello", "follow", tags)
        new_channel = "welcome"
        xhr :post, :edit, { channel: new_channel, category_id: category_id, filter: 'watch', tags: nil }
        expect(response).to be_success
        filter = ::DiscourseSlack::Slack.get_store(category_id)
        expect(filter).to include(
          "channel" => new_channel,
          "filter" => "watch",
          "tags" => nil
        )
      end

    end

    context 'command' do

      before do
        SiteSetting.slack_incoming_webhook_token = "SECRET TOKEN"
      end

      it 'should create filter to follow a category on slack' do
        category = Fabricate(:category)

        expect {
          xhr :post, :command, { text: "follow #{category.slug}", channel_name: "welcome", token: "SECRET TOKEN" }
          json = ::JSON.parse(response.body)
          expect(json["text"]).to eq(I18n.t("slack.message.success.category", command: "Followed", name: category.name))
          expect(DiscourseSlack::Slack.get_store(category.id)[0]).to include(
            "channel" => "#welcome",
            "filter" => "follow",
            "tags" => nil
          )
        }.to change(PluginStoreRow, :count).by(1)
      end

      it 'should create filter to watch a tag on slack' do
        tag = Fabricate(:tag)

        xhr :post, :command, { text: "watch tag:#{tag.name}", channel_name: "welcome", token: "SECRET TOKEN" }
        json = ::JSON.parse(response.body)
        expect(json["text"]).to eq(I18n.t("slack.message.success.tag", command: "Watched", name: tag.name))
        expect(DiscourseSlack::Slack.get_store[1]).to include(
          "channel" => "#welcome",
          "filter" => "watch",
          "tags" => [tag.name]
        )
      end

      it 'should add filter to mute a category on slack' do
        xhr :post, :command, { text: "mute all", channel_name: "general", token: "SECRET TOKEN" }
        json = ::JSON.parse(response.body)
        expect(json["text"]).to eq(I18n.t("slack.message.success.all_categories", command: "Muted"))
        expect(DiscourseSlack::Slack.get_store[0]).to include(
          "channel" => "#general",
          "filter" => "mute",
          "tags" => nil
        )
      end

      it 'should add filter to mute a tag on slack' do
        tag = Fabricate(:tag)

        xhr :post, :command, { text: "mute tag:#{tag.name}", channel_name: "welcome", token: "SECRET TOKEN" }
        json = ::JSON.parse(response.body)
        expect(json["text"]).to eq(I18n.t("slack.message.success.tag", command: "Muted", name: tag.name))
        expect(DiscourseSlack::Slack.get_store[1]).to include(
          "channel" => "#welcome",
          "filter" => "mute",
          "tags" => [tag.name]
        )
      end

      it 'should display slack command help' do
        tag = Fabricate(:tag)

        xhr :post, :command, { text: "help", channel_name: "welcome", token: "SECRET TOKEN" }
        json = ::JSON.parse(response.body)
        expect(json["text"]).to eq(I18n.t("slack.help"))
      end

    end

  end

end
