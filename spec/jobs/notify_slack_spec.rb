require 'rails_helper'

describe Jobs::NotifySlack do

  before do
    SiteSetting.slack_outbound_webhook_url = "https://hooks.slack.com/services/X/Y/Z"
    SiteSetting.slack_enabled = true
    FakeWeb.register_uri(:post, SiteSetting.slack_outbound_webhook_url, :body => "success")
  end

  let(:post) { Fabricate(:post) }

  context 'notify' do
    it 'should try to send notification' do
      responses = Jobs::NotifySlack.new.execute({post_id: post[:id]})
      expect(responses[0]).to eq("success")
    end
  end

end