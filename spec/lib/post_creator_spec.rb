require 'rails_helper'

RSpec.describe PostCreator do
  let(:first_post) { Fabricate(:post) }
  let(:topic) { Fabricate(:topic, posts: [first_post]) }

  before do
    SiteSetting.slack_outbound_webhook_url = "https://hooks.slack.com/services/abcde"
    SiteSetting.queue_jobs = true
    Jobs::NotifySlack.jobs.clear
  end

  describe 'when a post is created' do
    describe 'when plugin is enabled' do
      before do
        SiteSetting.slack_enabled = true
      end

      it 'should schedule a job for slack post' do
        freeze_time

        post = PostCreator.new(topic.user,
          raw: 'aaaaaaaaaaaaaaaaasdddddddddd sorry cat walked over my keyboard',
          topic_id: topic.id
        ).create!

        job = Jobs::NotifySlack.jobs.last

        expect(job['at'])
          .to eq((Time.zone.now + SiteSetting.post_to_slack_window_secs.seconds).to_f)

        expect(job['args'].first['post_id']).to eq(post.id)
      end
    end

    describe 'when plugin is not enabled' do
      before do
        SiteSetting.slack_enabled = false
      end

      it 'should not schedule a job for slack post' do
        PostCreator.new(topic.user,
          raw: 'aaaaaaaaaaaaaaaaasdddddddddd sorry cat walked over my keyboard',
          topic_id: topic.id
        ).create!

        expect(Jobs::NotifySlack.jobs).to eq([])
      end
    end
  end
end
