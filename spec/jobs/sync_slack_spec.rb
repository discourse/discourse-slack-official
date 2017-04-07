require 'rails_helper'

describe Jobs::SyncSlack do

  before do
    SiteSetting.slack_access_token = "SLACK_ACCESS_TOKEN"
    stub_request(:get, DiscourseSlack::API.uri("channels.list")).to_return(body: '{
      "ok": true,
      "channels": [
          {
              "id": "C024BE91L",
              "name": "fun",
              "created": 1360782804,
              "creator": "U024BE7LH",
              "is_archived": false,
              "is_member": false,
              "num_members": 6,
              "topic": {
                  "value": "Fun times",
                  "creator": "U024BE7LV",
                  "last_set": 1369677212
              },
              "purpose": {
                  "value": "This channel is for fun",
                  "creator": "U024BE7LH",
                  "last_set": 1360782804
              }
          }
      ]
    }')
    stub_request(:get, DiscourseSlack::API.uri("users.list")).to_return(body: '{
      "ok": true,
      "members": [
          {
              "id": "U023BECGF",
              "team_id": "T021F9ZE2",
              "name": "bobby",
              "deleted": false,
              "color": "9f69e7",
              "real_name": "Bobby Tables",
              "tz": "America/Los_Angeles",
              "tz_label": "Pacific Daylight Time",
              "tz_offset": -25200,
              "profile": {
                  "avatar_hash": "ge3b51ca72de",
                  "current_status": ":mountain_railway: riding a train",
                  "first_name": "Bobby",
                  "last_name": "Tables",
                  "real_name": "Bobby Tables",
                  "email": "bobby@slack.com",
                  "skype": "my-skype-name",
                  "phone": "+1 (123) 456 7890",
                  "image_24": "https://...",
                  "image_32": "https://...",
                  "image_48": "https://...",
                  "image_72": "https://...",
                  "image_192": "https://..."
              },
              "is_admin": true,
              "is_owner": true,
              "updated": 1490054400,
              "has_2fa": false
          }
      ],
      "cache_ts": 1498777272,
      "response_metadata": {
          "next_cursor": "dXNlcjpVMEc5V0ZYTlo="
      }
    }')
  end

  context '#sync' do
    it "should refresh channels and users from slack" do
      Jobs::SyncSlack.new.execute({})
      expect(DiscourseSlack::Slack.channels.count).to eq(1)
      expect(DiscourseSlack::Slack.users.count).to eq(1)
    end
  end

end
