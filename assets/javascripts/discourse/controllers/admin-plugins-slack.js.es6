import FilterRule from 'discourse/plugins/discourse-slack-official/discourse/models/filter-rule';
import { ajax } from 'discourse/lib/ajax';

export default Ember.Controller.extend({
  categories: function() {
    return [Discourse.Category.create({ name: 'All Categories', id: 0, slug: '*'})].concat(Discourse.Category.list());
  }.property(),

  filters: [
    { id: 'watch', name: I18n.t('slack.future.watch'), icon:'exclamation-circle' },
    { id: 'follow', name: I18n.t('slack.future.follow'), icon: 'circle'},
    { id: 'mute', name: I18n.t('slack.future.mute'), icon: 'times-circle' }
  ],

  editing: FilterRule.create({}),

  actions: {
    edit(rule) {
      this.set( 'editing', FilterRule.create(rule.getProperties('filter', 'category_id', 'channel')));
    },

    save() {
      var rule = this.get('editing');
      var model = this.get('model');
      var self = this;
      self.set('error_message', '');

      ajax("/slack/list.json", { method: 'POST',
        data: rule.getProperties('filter', 'category_id', 'channel')
      }).then(function() {
        var obj = model.find((x) => ( x.get('category_id') === rule.get('category_id') && x.get('channel') === rule.get('channel') ));
        if (obj) {
          obj.set('channel', rule.channel);
          obj.set('filter', rule.filter);
        } else {
          model.pushObject(FilterRule.create(rule.getProperties('filter', 'category_id', 'channel')));
        }
      }).catch(err => {
        self.set( 'error_message', err.jqXHR.responseJSON.message );
      });
    },

    delete(rule) {
      var model = this.get('model');
      var self = this;
      self.set('error_message', '');

      ajax("/slack/list.json", { method: 'DELETE',
        data: rule.getProperties('filter', 'category_id', 'channel')
      }).then(function() {
        var obj = model.find((x) => ( x.get('category_id') === rule.get('category_id') && x.get('channel') === rule.get('channel') ));
        model.removeObject(obj);
      }).catch(err => {
        self.set( 'error_message', err.jqXHR.responseJSON.message );
      });
    },

    test_notification() {
      ajax("/slack/test.json", { method: 'POST' });
    },

    reset_settings() {
      ajax("/slack/reset_settings.json", { method: 'POST' });
    }
  }
});
