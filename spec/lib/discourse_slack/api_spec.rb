require 'rails_helper'

RSpec.describe DiscourseSlack::API do

  let(:history) { '{
      "ok": true,
      "latest": "1358547726.000003",
      "messages": [
          {
              "type": "message",
              "ts": "1358546515.000008",
              "user": "U2147483896",
              "text": "Hello"
          },
          {
              "type": "message",
              "ts": "1358546515.000007",
              "user": "U2147483896",
              "text": "World",
              "is_starred": true,
              "reactions": [
                  {
                      "name": "space_invader",
                      "count": 3,
                      "users": [ "U1", "U2", "U3" ]
                  },
                  {
                      "name": "sweet_potato",
                      "count": 5,
                      "users": [ "U1", "U2", "U3", "U4", "U5" ]
                  }
              ]
                      },
          {
              "type": "something_else",
              "ts": "1358546515.000007",
              "wibblr": true
          }
      ],
      "has_more": false
    }' }

  before do
    SiteSetting.slack_access_token = "SLACK_ACCESS_TOKEN"
    stub_request(:get, DiscourseSlack::API.uri("channels.history", channel: 'myteam', count: 2)).to_return(body: history)
  end

  describe 'fetch' do
    describe 'slack channel history' do

      it 'should return messages' do
        response = DiscourseSlack::API.messages('myteam', 2)
        expect(response).to eq(JSON(history))
      end

      it 'should not return without access token' do
        SiteSetting.slack_access_token = nil
        response = DiscourseSlack::API.messages('myteam', 2)
        expect(response[:error]).to eq(I18n.t('slack.errors.access_token_is_empty'))
      end
    end
  end

end
