require 'rails_helper'

describe Jobs::NotifySlack do
  let(:post) { Fabricate(:post) }
  let(:category) { Fabricate(:category) }
  let(:topic) { Fabricate(:topic, category_id: category.id, posts: [post]) }

  before do
    SiteSetting.slack_outbound_webhook_url = "https://hooks.slack.com/services/abcde"
    SiteSetting.slack_enabled = true
  end

  before do
    FakeWeb.register_uri(:post, SiteSetting.slack_outbound_webhook_url, body: "success")
  end

  context '#notify' do
    it "should notify if topic's category has a filter" do
      topic
      response = Jobs::NotifySlack.new.execute(post_id: post.id)
      expect(response[0]).to eq(nil)

      DiscourseSlack::Slack.set_filter_by_id(category.id, "#general", "follow")
      response = Jobs::NotifySlack.new.execute(post_id: post.id)

      expect(response[0]).to eq("success")
    end

    it "should notify if topic's tag have a filter" do
      SiteSetting.tagging_enabled = true
      tag = Fabricate(:tag)
      topic.tags << tag

      response = Jobs::NotifySlack.new.execute(post_id: post.id)
      expect(response[0]).to eq(nil)

      DiscourseSlack::Slack.set_filter_by_id(nil, "#general", "follow", [tag.name])
      response = Jobs::NotifySlack.new.execute(post_id: post.id)

      expect(response[0]).to eq("success")
    end
  end

end
