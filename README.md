## Installation

Add the this repository's `git clone` url to your container's `app.yml` file, at the bottom of the `cmd` section:

```yml
hooks:
  after_code:
    - exec:
        cd: $home/plugins
        cmd:
          - mkdir -p plugins
          - git clone https://github.com/discourse/docker_manager.git
          - git clone https://github.com/nicksahler/discourse-slack-official.git
```

Rebuild your container:

```
cd /var/discourse
git pull
./launcher rebuild app
```

## Configuration

1. Go to `https://<yourteam>.slack.com/apps/new/A0F82E8CA-slash-commands` to create a new outgoing command.\*

2. Enter the name of the command and click "Add Slash Command Integration".

    ![New Slash Command](https://cloud.githubusercontent.com/assets/1386403/16739197/f925f9f6-4766-11e6-92a7-8ea7897e7150.png)  

3. Set a URL for the slash command to post to. It should be `<your-discourse-url-here>/slack/command`

4. Copy your API token from the Token field.  

    ![Add slash command](https://cloud.githubusercontent.com/assets/1386403/16739199/f92d42ec-4766-11e6-9ea5-131d5625db2e.png)

5. Go to your discourse install's settings page found at `<your-discourse-url-here>/admin/site_settings/category/plugins` and filter by "slack". Paste your API token in the incoming webook field. The next steps will describe how to get the `webhook url` setting.  

    ![Settings Page](https://cloud.githubusercontent.com/assets/1386403/16739198/f92c6b60-4766-11e6-99b2-877a370f67b5.png)  

6. Go to `https://<yourslack>.slack.com/apps/new/A0F7XDUAZ-incoming-webhooks` to create a new webhook. Discourse will use this to post to slack.\*\*  

    ![New Webhook Page](https://cloud.githubusercontent.com/assets/1386403/16739200/f92dbee8-4766-11e6-9e4a-03289337a91b.png)

7. Return to your settings page and paste your webhook URL token into the `slack outbound webhook url` setting.

8. Click enable slack in your settings and save.

Optionally, you can set a default user for slack to use and the size of the excerpts being posted to slack

<sup>\*</sup> If you have more than one Discourse, repeat steps 1 and 2 with a unique slash command  
<sup>\*\*</sup> You only need to do this once for more than one Discourse instance  

## Todo

- [ ] Enable unfurling on private Discourse instances
- [ ] User access control (restricting use to certain users, dealing with hidden posts)
