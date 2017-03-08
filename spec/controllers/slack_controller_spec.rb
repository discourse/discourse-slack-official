require 'rails_helper'

describe ::DiscourseSlack::SlackController do
  routes { ::DiscourseSlack::Engine.routes }

  PLUGIN_NAME = ::DiscourseSlack.plugin_name.freeze

  before do
    SiteSetting.slack_outbound_webhook_url = "https://hooks.slack.com/services/abcde"
    SiteSetting.slack_enabled = true
  end

  context "when logged in" do
    let!(:user) { log_in(:admin) }

    it "checking existence of default filters" do
      expect(PluginStoreRow.where(plugin_name: PLUGIN_NAME).count).to eq(3)
    end

    context '#index' do
      it "returns a list of filters" do
        xhr :get, :list
        expect(response).to be_success
        json = ::JSON.parse(response.body)
        expect(json['slack'].count).to eq(1)
      end
    end

    context '#create' do
      it "creates a filter" do
        expect {
          channel, category_id, filter = "#hello", "1", "follow"
          xhr :post, :edit, { channel: channel, category_id: category_id, filter: filter }
          expect(response).to be_success
          id = PluginStore.get(PLUGIN_NAME, "_category_#{category_id}_#{channel}")
          data = PluginStore.get(PLUGIN_NAME, "filter_#{id}")
          expect(data[:channel]).to eq(channel)
          expect(data[:category_id]).to eq(category_id)
          expect(data[:filter]).to eq(filter)
        }.to change(PluginStoreRow, :count).by(2)
      end

      it "creates a filter with tags" do
        expect {
          xhr :post, :edit, { channel: '#welcome', category_id: 2, filter: 'follow', tags: ["test", "example"] }
          expect(response).to be_success
        }.to change(PluginStoreRow, :count).by(4)
      end
    end

    context '#destroy' do

      it "deletes the filter" do
        id = ::DiscourseSlack::Slack.set_filter("#hello", "follow", 1)

        expect {
          xhr :delete, :delete, id: id
          expect(response).to be_success
        }.to change(PluginStoreRow, :count).by(-2)
      end

      it "deletes the filter with tags" do
        id = ::DiscourseSlack::Slack.set_filter("#hello", "follow", 1, ["test", "example"])

        expect {
          xhr :delete, :delete, id: id
          expect(response).to be_success
        }.to change(PluginStoreRow, :count).by(-4)
      end

    end

    context '#update' do

      it "updates the filter with tags" do
        id = ::DiscourseSlack::Slack.set_filter("#hello", "follow", 1)
        new_channel = "welcome"
        new_category_id = "2"
        new_tags = ["test", "example"]
        xhr :post, :edit, { id: id, channel: new_channel, category_id: new_category_id, filter: 'watch', tags: new_tags }
        expect(response).to be_success
        filter = ::DiscourseSlack::Slack.get_filter(id)
        expect(filter[:channel]).to eq(new_channel)
        expect(filter[:category_id]).to eq(new_category_id)
        expect(filter[:filter]).to eq('watch')
        expect(filter[:tags]).to eq(new_tags)
        value = ::PluginStore.get(PLUGIN_NAME, "_category_#{new_category_id}_#{new_channel}")
        expect(value).to eq(id)
        new_tags.each do |t|
          value = ::PluginStore.get(PLUGIN_NAME, "_tag_#{t}_#{new_channel}")
          expect(value).to eq(id)
        end
      end

      it "updates the filter without tags" do
        tags = ["test", "example"]
        id = ::DiscourseSlack::Slack.set_filter("#hello", "follow", 1, tags)
        new_channel = "welcome"
        new_category_id = "2"
        xhr :post, :edit, { id: id, channel: new_channel, category_id: new_category_id, filter: 'watch', tags: [] }
        expect(response).to be_success
        filter = ::DiscourseSlack::Slack.get_filter(id)
        expect(filter[:channel]).to eq(new_channel)
        expect(filter[:category_id]).to eq(new_category_id)
        expect(filter[:filter]).to eq('watch')
        expect(filter[:tags]).to eq([])
        value = ::PluginStore.get(PLUGIN_NAME, "_category_#{new_category_id}_#{new_channel}")
        expect(value).to eq(id)
        tags.each do |t|
          value = ::PluginStore.get(PLUGIN_NAME, "_tag_#{t}_#{new_channel}")
          expect(value).to eq(nil)
        end
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
          expect(response).to be_success
        }.to change(PluginStoreRow, :count).by(2)
      end

      it 'should create filter to watch a tag on slack' do
        tag = Fabricate(:tag)

        expect {
          xhr :post, :command, { text: "watch tag:#{tag.name}", channel_name: "welcome", token: "SECRET TOKEN" }
          expect(response).to be_success
        }.to change(PluginStoreRow, :count).by(2)
      end

      it 'should remove filter to mute a category on slack' do
        expect {
          xhr :post, :command, { text: "mute all", channel_name: "general", token: "SECRET TOKEN" }
          expect(response).to be_success
        }.to change(PluginStoreRow, :count).by(0)
      end

      it 'should remove filter to mute a tag on slack' do
        tag = Fabricate(:tag)
        xhr :post, :command, { text: "watch tag:#{tag.name}", channel_name: "welcome", token: "SECRET TOKEN" }

        expect {
          xhr :post, :command, { text: "mute tag:#{tag.name}", channel_name: "welcome", token: "SECRET TOKEN" }
          expect(response).to be_success
        }.to change(PluginStoreRow, :count).by(0)
      end

    end

  end

end
