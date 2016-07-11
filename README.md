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

1. Go to `https://<yourteam>.slack.com/apps/new/A0F82E8CA-slash-commands` to create a new outgoing command.\*
2. Enter the name of the command and click "Add Slash Command Integration".
![New Slash Command](https://cloud.githubusercontent.com/assets/1386403/16739197/f925f9f6-4766-11e6-92a7-8ea7897e7150.png)  
3. Set a URL for the slash command to post to. It should be `<your-discourse-url-here>/slack/command`
4. Copy your API token from the Token field.  
![Add slash command](https://cloud.githubusercontent.com/assets/1386403/16739199/f92d42ec-4766-11e6-9ea5-131d5625db2e.png)
4. Go to your discourse install's settings page found at `<your-discourse-url-here>/admin/site_settings/category/plugins` and filter by "slack". Paste your API token in the incoming webook field. The next steps will describe how to get the `webhook url` setting.  
![Settings Page](https://cloud.githubusercontent.com/assets/1386403/16739198/f92c6b60-4766-11e6-99b2-877a370f67b5.png)  
5. Go to https://<yourslack>https://discourse.slack.com/apps/new/A0F7XDUAZ-incoming-webhooks` to create a new webhook. Discourse will use this to post to slack.\*\*  
![New Webhook Page](https://cloud.githubusercontent.com/assets/1386403/16739200/f92dbee8-4766-11e6-9e4a-03289337a91b.png)
6. Return to your settings page and paste your webhook URL token into the `slack outbound webhook url` setting.
7. Click enable slack in your settings and save.

Optionally, you can set a default user for slack to use and the size of the excerpts being posted to slack

\* **If you have more than one Discourse forum, setps 1 and 2 must be repeated for each install with a different slash command for each**  
\*\* **You only need to do this once for more than one Discourse instance**

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
