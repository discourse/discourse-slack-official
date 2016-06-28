## Installation

* Add the this repository's `git clone` url to your container's `app.yml` file:

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

(Add the plugin's `git clone` url just below `git clone https://github.com/discourse/docker_manager.git`)

* Rebuild the container:

```
cd /var/discourse
./launcher rebuild app
```

## Configuring thread and category following via discourse bot.

1. Go to https://<yourslack>.slack.com/apps/build/custom-integration and click **Slash Commands ** to create a new outgoing command. **In the case that you have more than one Discourse forum one of these is needed for each install**
2. Enter the command you wish to use. If you only have one forum, `/discourse` will work fine. This is how you will interact with your forum later on.
3. Set a URL for the slash command to post to. It should be `<your-discourse-url-here>/slack/command`
3. Copy your API token into discourse-slack's `slack incoming webhook token` setting found at `<your-discourse-url-here>/admin/site_settings/category/plugins`
4. Go to https://<yourslack>.slack.com/apps/build/custom-integration and click **Incoming WebHooks** to create a new webhook. Discourse will use this to post to slack. **You only need to do this once for more than one Discourse instance**
5. Copy your webhook URL token into discourse-slack's `slack outbound webhook url` setting.
6. If you would like, set a default user for slack to use and the size of the excerpts being posted to slack
7. Enable slack in your settings.

## Enabling URL unfurling on private forums 

COMING SOON


Impending features:
- [x] Post subscription foundation
- [x] More robust command parsing 
- [ ] User access control (restricting use to certain users, dealing with hidden posts)
- [x] Subscribe by link
- [x] Installation step-by-step [WIP]
- [x] ~Eventually fewer dependencies when Discourse moves to Rails 5 (if it does)~
- [x] Move unfurl functionality to bot, for more compactness
