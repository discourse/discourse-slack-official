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
  end

end
