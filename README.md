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

1. Go to https://discourse.slack.com/apps/build/custom-integration and click **bots** to create a new bot.

2. Give your bot a name, this is how you will call it later on.

3. Copy your API token into discourse-slack's `bot token` setting.

## Enabling URL unfurling on private forums 

COMING SOON


Impending features:
- [x] Post subscription foundation
- [x] More robust command parsing 
- [ ] User access control (restricting use to certain users, dealing with hidden posts)
- [x] Subscribe by link
- [x] Installation step-by-step [WIP]
- [ ] Eventually fewer dependencies when Discourse moves to Rails 5 (if it does)
- [ ] Move unfurl functionality to bot, for more compactness