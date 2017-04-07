import Channel from 'discourse/plugins/discourse-slack-official/discourse/models/channel';
import { ajax } from 'discourse/lib/ajax';

export default Discourse.Route.extend({

  model() {
    return ajax("/slack/channels.json").then(result => {
      var model = result.slack.map(v => Channel.create(v));
      return model;
    });
  }

});
