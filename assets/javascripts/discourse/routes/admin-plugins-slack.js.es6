import FilterRule from 'discourse/plugins/discourse-slack-official/discourse/models/filter-rule';

export default Discourse.Route.extend({
  model() {
    return Discourse.ajax("/slack/list.json")
    .then(function(result) {
      var final = result.slack;

      return final.map(function(v) {
        return FilterRule.create(v);
      });
    });
  }
});