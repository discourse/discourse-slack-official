require 'rails_helper'

describe 'Slack' do
  site_setting("slack_outbound_webhook_url", "https://hooks.slack.com/services/abcde")
  site_setting("slack_enabled", true)
  site_setting("post_to_slack_window_secs", 20)

  let(:first_post) { Fabricate(:post) }
  let(:topic) { Fabricate(:topic, posts: [first_post]) }

  describe 'testing notification' do
    it 'should ping slack successfully' do
      DiscourseSlack::Slack.expects(:notify).with(first_post.id)

      post '/slack/test.json'

      expect(response).to be_success
    end
  end

  let(:post) { Fabricate(:post) }
  let(:delay) { SiteSetting.post_to_slack_window_secs.seconds }

  context 'post' do

    it 'should schedule a job for slack post' do
      Timecop.freeze(Time.zone.now) do
        Jobs.expects(:enqueue_in).with(delay, :notify_slack, has_entry(post_id: post.id))
        DiscourseEvent.trigger(:post_created, post)
      end
    end

    it 'should not schedule a job for slack post' do
      SiteSetting.slack_enabled = false
      Timecop.freeze(Time.zone.now) do
        Jobs.expects(:enqueue_in).with(delay, :notify_slack, has_entry(post_id: post.id)).never
        DiscourseEvent.trigger(:post_created, post)
      end
    end

  end

end
