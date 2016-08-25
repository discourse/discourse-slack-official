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

1. Go to the **[Incoming Webhooks](https://slack.com/apps/new/A0F7XDUAZ-incoming-webhooks)** configuration page for your Slack instance. Pick a channel, and click the big green "Add incoming webhook Integration" button. (You only need to do this once, even if you have multiple Discourse instances.)
 
    ![Big green button page](http://i.imgur.com/HZDncCP.png)

2. Scroll down to **Integration Settings** and copy the "Webhook URL".

    ![New Webhook Page](https://cloud.githubusercontent.com/assets/1386403/16739200/f92dbee8-4766-11e6-9e4a-03289337a91b.png)
    
3. Go to your Discourse settings page, found at `<your-discourse-url>/admin/site_settings/category/plugins`. In the **slack outbound webhook url** field, paste the webhook URL you copied from Slack.

    ![Settings Page](http://i.imgur.com/wXwkSFR.png)
    
    (You can optionally set the user that Slack will use to post, and change the size of the excerpts being posted.)

4. Select the **Enable checkbox**, and save all the changed settings. That's it! You're done! 

By default, every new post on your Discourse will now create a Slack message in the channel you specified in step one.

To change your notification defaults, go to `/admin/plugins/slack` on your Discourse, or set up [an optional slash command](./README-SLASHCOMMAND.md) to change your notifications settings directly from Slack.

![Configure](http://i.imgur.com/ea8kvbE.png)

## Todo
- [ ] Enable unfurling on private Discourse instances
- [ ] Handle content OneBoxing on the Discourse end
