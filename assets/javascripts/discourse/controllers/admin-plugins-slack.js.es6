import FilterRule from 'discourse/plugins/discourse-slack-official/discourse/models/filter-rule';
import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';

export default Ember.Controller.extend({
  categories: function() {
    return [
      Discourse.Category.create({ name: I18n.t('slack.choose.category'), id: '' }),
      Discourse.Category.create({ name: I18n.t('slack.choose.all_categories'), id: '*' })
    ].concat(Discourse.Category.list());
  }.property(),

  filters: [
    { id: 'watch', name: I18n.t('slack.future.watch'), icon:'exclamation-circle' },
    { id: 'follow', name: I18n.t('slack.future.follow'), icon: 'circle'},
    { id: 'mute', name: I18n.t('slack.future.mute'), icon: 'times-circle' }
  ],

  editing: FilterRule.create({}),

  taggingEnabled: function() {
    return this.siteSettings.tagging_enabled;
  }.property(),

  actions: {
    edit(rule) {
      this.set( 'editing', FilterRule.create(rule.getProperties('id', 'channel', 'filter', 'category_id', 'tags')));
    },

    save() {
      const rule = this.get('editing');
      const model = this.get('model');

      ajax("/slack/list.json", {
        method: 'POST',
        data: rule.getProperties('id', 'channel', 'filter', 'category_id', 'tags')
      }).then(() => {
        var obj = model.find((x) => ( x.get('id') === rule.get('id') ));
        if (obj) {
          obj.setProperties({ id: rule.channel, channel: rule.channel, filter: rule.filter, category_id: rule.category_id, tags: rule.tags});
        } else {
          model.pushObject(FilterRule.create(rule.getProperties('id', 'channel', 'filter', 'category_id', 'tags')));
        }
      }).catch(popupAjaxError);
    },

    delete(rule) {
      const model = this.get('model');

      ajax("/slack/list.json", { method: 'DELETE',
        data: rule.getProperties('id')
      }).then(() => {
        var obj = model.find((x) => ( x.get('id') === rule.get('id') ));
        model.removeObject(obj);
      }).catch(popupAjaxError);
    },

    testNotification() {
      this.set('testingNotification', true);

      ajax("/slack/test.json", { method: 'POST' })
        .catch(popupAjaxError)
        .finally(() => {
          this.set('testingNotification', false);
        });
    },

    resetSettings() {
      ajax("/slack/reset_settings.json", { method: 'POST' });
    }
  }
});
