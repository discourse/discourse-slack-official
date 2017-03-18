require 'rails_helper'

describe Jobs::NotifySlack do
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
      ::PluginStoreRow.find_by(plugin_name: DiscourseSlack::PLUGIN_NAME, key: DiscourseSlack::Slack.get_key).destroy
      category = Fabricate(:category)
      topic = Fabricate(:topic, category_id: category.id, posts: [post])
      response = Jobs::NotifySlack.new.execute({ post_id: post[:id] })
      expect(response[0]).not_to eq("success")
      DiscourseSlack::Slack.set_filter_by_id(category.id, "#general", "follow")
      response = Jobs::NotifySlack.new.execute({ post_id: post[:id] })
      expect(response[0]).to eq("success")
    end

    it "only if topic's tag have a filter" do
      ::PluginStoreRow.find_by(plugin_name: DiscourseSlack::PLUGIN_NAME, key: DiscourseSlack::Slack.get_key).destroy
      SiteSetting.tagging_enabled = true
      tag = Fabricate(:tag)
      topic = Fabricate(:topic, tags: [tag], posts: [post])
      response = Jobs::NotifySlack.new.execute({ post_id: post[:id] })
      expect(response[0]).not_to eq("success")
      DiscourseSlack::Slack.set_filter_by_id(nil, "#general", "follow", [tag.name])
      response = Jobs::NotifySlack.new.execute({ post_id: post[:id] })
      expect(response[0]).to eq("success")
    end
  end

end
