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
          - git clone https://github.com/discourse/discourse-slack-official.git
```

Rebuild your container:

```
cd /var/discourse
git pull
./launcher rebuild app
```

## Configuration

To set up this slack integration, you'll need to create an incoming webhook. You'll use the settings page or an optional slash command to subscribe to notifications; Discourse will then send the notifications using the webhook.


1. Go [here](https://slack.com/apps/new/A0F7XDUAZ-incoming-webhooks) and copy the "Webhook URL" to create a webhook that Discourse will use to post to Slack. You only need to do this once, even if you have multiple  Discourse instances.  

    ![New Webhook Page](https://cloud.githubusercontent.com/assets/1386403/16739200/f92dbee8-4766-11e6-9e4a-03289337a91b.png)

2. Go to your Discourse settings page, found at `<your-discourse-url>/admin/site_settings/category/plugins`. In the "slack outbound webhook url" field, paste the webhook URL.

    ![Settings Page](https://cloud.githubusercontent.com/assets/1386403/16739198/f92c6b60-4766-11e6-99b2-877a370f67b5.png)  
    You can optionally set the user that Slack will use, and change the size of the excerpts being posted.

3. Select the "Enable the discourse-slack-official plugin" checkbox, and save all the changed settings.

You can now go to `/admin/plugins/slack` on your forum to configure notification settings or set up an optional slack command with the instructions [here](./README-SLASHCOMMAND.md) to control the plugin from slack itself.

## Todo

- [ ] Enable unfurling on private Discourse instances
- [ ] Handle content OneBoxing on the Discourse end
