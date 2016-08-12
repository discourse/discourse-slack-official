import FilterRule from 'discourse/plugins/discourse-slack-official/discourse/models/filter-rule';
export default Ember.Controller.extend({
  categories: function() {
    return [Discourse.Category.create({ name: 'All Categories', id: 0, slug: '*'})].concat(Discourse.Category.list())
  }.property(),

  filters: ['mute', 'follow', 'watch'],
  editing: FilterRule.create({}),

  actions: {
    edit(rule) {
      this.set( 'editing', FilterRule.create(rule.getProperties('filter', 'category_id', 'channel')));
    },

    save() {
      var rule = this.get('editing');
      var model = this.get('model');

      Discourse.ajax("/slack/list.json", { method: 'POST', 
        data: rule.getProperties('filter', 'category_id', 'channel')
      }).then(function() {
        var obj = model.find((x) => ( x.get('category_id') == rule.get('category_id') && x.get('channel') === rule.get('channel') ));
        if (obj) {
          obj.set('channel', rule.channel);
          obj.set('filter', rule.filter);
        } else {
          model.pushObject(FilterRule.create(rule.getProperties('filter', 'category_id', 'channel')));
        }
      }).catch(function() {

      });
    },

    delete(rule) {
      var model = this.get('model');
      Discourse.ajax("/slack/list.json", { method: 'DELETE', 
        data: rule.getProperties('filter', 'category_id', 'channel')
      }).then(function() {
        var obj = model.find((x) => ( x.get('category_id') == rule.get('category_id') && x.get('channel') === rule.get('channel') ));
        model.removeObject(obj);
      })
    }
  }
});