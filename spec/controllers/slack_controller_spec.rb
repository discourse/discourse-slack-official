require 'rails_helper'

describe ::DiscourseSlack::SlackController do
  routes { ::DiscourseSlack::Engine.routes }

  PLUGIN_NAME = "discourse-slack-official".freeze

  before do
    SiteSetting.slack_outbound_webhook_url = "https://hooks.slack.com/services/abcde"
    SiteSetting.slack_enabled = true
  end

  context "when logged in" do
    let!(:user) { log_in(:admin) }

    it "default filters" do
      expect(PluginStoreRow.where(plugin_name: PLUGIN_NAME).count).to eq(4)
      expect(PluginStore.get(PLUGIN_NAME, "not_first_time")).to eq(true)
      expect(PluginStore.get(PLUGIN_NAME, "legacy_migrated")).to eq(true)
    end

    context '.index' do
      it "returns a list of filters" do
        xhr :get, :list
        expect(response).to be_success
        json = ::JSON.parse(response.body)
        expect(json['slack']).to be_present
      end
    end

    context '.create' do
      it "creates a filter" do
        expect {
          xhr :post, :edit, {channel: '#hello', category_id: 1, filter: 'follow'}
          expect(response).to be_success
        }.to change(PluginStoreRow, :count).by(2)
      end

      it "creates a filter with tags" do
        expect {
          xhr :post, :edit, {channel: '#welcome', category_id: 2, filter: 'follow', tags: ["test", "example"]}
          expect(response).to be_success
        }.to change(PluginStoreRow, :count).by(4)
      end
    end

    context '.destroy' do

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

    context '.update' do

      it "updates the filter with tags" do
        id = ::DiscourseSlack::Slack.set_filter("#hello", "follow", 1)
        new_channel = "welcome"
        new_category_id = "2"
        new_tags = ["test", "example"]
        xhr :post, :edit, {id: id, channel: new_channel, category_id: new_category_id, filter: 'watch', tags: new_tags}
        expect(response).to be_success
        filter = ::DiscourseSlack::Slack.get_filter(id)
        expect(filter[:channel]).to eq(new_channel)
        expect(filter[:category_id]).to eq(new_category_id)
        expect(filter[:filter]).to eq('watch')
        expect(filter[:tags]).to eq(new_tags)
        cid = ::PluginStore.get(PLUGIN_NAME, "_category_#{new_category_id}_#{new_channel}")
        expect(cid).to eq(id)
        new_tags.each do |t|
          tid = ::PluginStore.get(PLUGIN_NAME, "_tag_#{t}_#{new_channel}")
          expect(tid).to eq(id)
        end
      end

      it "updates the filter without tags" do
        tags = ["test", "example"]
        id = ::DiscourseSlack::Slack.set_filter("#hello", "follow", 1, tags)
        new_channel = "welcome"
        new_category_id = "2"
        xhr :post, :edit, {id: id, channel: new_channel, category_id: new_category_id, filter: 'watch', tags: []}
        expect(response).to be_success
        filter = ::DiscourseSlack::Slack.get_filter(id)
        expect(filter[:channel]).to eq(new_channel)
        expect(filter[:category_id]).to eq(new_category_id)
        expect(filter[:filter]).to eq('watch')
        expect(filter[:tags]).to eq([])
        cid = ::PluginStore.get(PLUGIN_NAME, "_category_#{new_category_id}_#{new_channel}")
        expect(cid).to eq(id)
        tags.each do |t|
          tid = ::PluginStore.get(PLUGIN_NAME, "_tag_#{t}_#{new_channel}")
          expect(tid).to eq(nil)
        end
      end

    end

  end

end
