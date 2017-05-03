import FilterRule from 'discourse/plugins/discourse-slack-official/discourse/models/filter-rule';
import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import computed from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  filters: [
    { id: 'watch', name: I18n.t('slack.future.watch'), icon: 'exclamation-circle' },
    { id: 'follow', name: I18n.t('slack.future.follow'), icon: 'circle'},
    { id: 'mute', name: I18n.t('slack.future.mute'), icon: 'times-circle' }
  ],

  editing: FilterRule.create({}),

  @computed('editing.channel')
  saveDisabled(channel) {
    return Ember.isEmpty(channel);
  },

  actions: {
    // TODO: Properly implement logic on the backend
    // edit(rule) {
    //   this.set(
    //     'editing',
    //     FilterRule.create(rule.getProperties('filter', 'category_id', 'channel', 'tags'))
    //   );
    // },

    save() {
      const rule = this.get('editing');

      ajax("/slack/list.json", {
        method: 'PUT',
        data: rule.getProperties('filter', 'category_id', 'channel', 'tags')
      }).then(() => {
        const model = this.get('model');
        const obj = model.find(x => (x.get('category_id') === rule.get('category_id') && x.get('channel') === rule.get('channel') && x.get('tags') === rule.get('tags')));

        if (obj) {
          obj.setProperties({
            channel: rule.channel,
            filter: rule.filter,
            tags: rule.tags
          });
        } else {
          model.pushObject(FilterRule.create(rule.getProperties('filter', 'category_id', 'channel', 'tags')));
        }
      }).catch(popupAjaxError);
    },

    delete(rule) {
      const model = this.get('model');

      ajax("/slack/list.json", {
        method: 'DELETE',
        data: rule.getProperties('filter', 'category_id', 'channel', 'tags')
      }).then(() => {
        const obj = model.find((x) => (x.get('category_id') === rule.get('category_id') && x.get('channel') === rule.get('channel') && x.get('tags') === rule.get('tags')));
        model.removeObject(obj);
      }).catch(popupAjaxError);
    },

    testNotification() {
      this.set('testingNotification', true);

      ajax("/slack/test.json", { method: 'PUT' })
        .catch(popupAjaxError)
        .finally(() => {
          this.set('testingNotification', false);
        });
    },

    resetSettings() {
      ajax("/slack/reset_settings.json", { method: 'PUT' }).catch(popupAjaxError);
    }
  }
});
