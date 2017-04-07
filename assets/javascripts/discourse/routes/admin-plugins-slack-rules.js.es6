import FilterRule from 'discourse/plugins/discourse-slack-official/discourse/models/filter-rule';
import { ajax } from 'discourse/lib/ajax';

export default Discourse.Route.extend({
  model() {
    return ajax("/slack/list.json").then(result => {
      return result.slack.map(v => FilterRule.create(v));
    });
  }
});
