require 'rails_helper'

describe 'Slack' do
  site_setting("slack_outbound_webhook_url", "https://hooks.slack.com/services/abcde")
  site_setting("slack_enabled", true)

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
