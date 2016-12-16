require 'rails_helper'

describe "Slack" do

  before do
    SiteSetting.slack_outbound_webhook_url = "https://hooks.slack.com/services/X/Y/Z"
    SiteSetting.slack_enabled = true
    SiteSetting.post_to_slack_window_mins = 10
  end

  let(:delay) { SiteSetting.post_to_slack_window_mins.minutes }

  context 'notify' do
    it 'should schedule a job for slack post' do
      post = Fabricate(:post)
      Jobs.expects(:enqueue_in).with(delay, :notify_slack, has_entry(post_id: post[:id])).never
    end
  end

end