## Installation

Add this repository's `git clone` url to your container's `app.yml` file, at the bottom of the `cmd` section:

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

https://meta.discourse.org/t/configuring-slack-for-discourse-slack-plugin/52990

## Todo
- [ ] Enable unfurling on private Discourse instances
- [ ] Handle content OneBoxing on the Discourse end
