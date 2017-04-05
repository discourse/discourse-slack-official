require 'rails_helper'

describe 'Slack' do
  before do
    SiteSetting.slack_outbound_webhook_url = "https://hooks.slack.com/services/abcde"
    SiteSetting.slack_enabled = true
    SiteSetting.post_to_slack_window_secs = 20
  end

  let(:first_post) { Fabricate(:post) }
  let(:topic) { Fabricate(:topic, posts: [first_post]) }

  describe 'testing notification' do
    it 'should ping slack successfully' do
      DiscourseSlack::Slack.expects(:notify).with(first_post.id)

      post '/slack/test.json'

      expect(response).to be_success
    end
  end
end
