require 'rails_helper'

describe Jobs::NotifySlack do
  PLUGIN_NAME = ::DiscourseSlack.plugin_name.freeze

  before do
    SiteSetting.slack_outbound_webhook_url = "https://hooks.slack.com/services/abcde"
    SiteSetting.slack_enabled = true
  end

  before do
    FakeWeb.register_uri(:post, SiteSetting.slack_outbound_webhook_url, :body => "success")
  end

  let(:post) { Fabricate(:post) }

  context 'notify' do
    it 'should try to send notification' do
      response = Jobs::NotifySlack.new.execute({post_id: post[:id]})
      expect(response[0]).to eq("success")
    end

    it "only if topic's category have a filter" do
      ::PluginStoreRow.find_by(plugin_name: PLUGIN_NAME, key: "_category_*_#general").destroy
      category = Fabricate(:category)
      topic = Fabricate(:topic, category_id: category.id, posts: [post])
      response = Jobs::NotifySlack.new.execute({post_id: post[:id]})
      expect(response[0]).not_to eq("success")
      DiscourseSlack::Slack.set_filter("#general", "follow", category.id)
      response = Jobs::NotifySlack.new.execute({post_id: post[:id]})
      expect(response[0]).to eq("success")
    end

    it "only if topic's tag have a filter" do
      ::PluginStoreRow.find_by(plugin_name: PLUGIN_NAME, key: "_category_*_#general").destroy
      SiteSetting.tagging_enabled = true
      tag = Fabricate(:tag)
      topic = Fabricate(:topic, tags: [tag], posts: [post])
      response = Jobs::NotifySlack.new.execute({post_id: post[:id]})
      expect(response[0]).not_to eq("success")
      DiscourseSlack::Slack.set_filter("#general", "follow", nil, [tag.name])
      response = Jobs::NotifySlack.new.execute({post_id: post[:id]})
      expect(response[0]).to eq("success")
    end
  end

end
