import Message from 'discourse/plugins/discourse-slack-official/discourse/models/message';
import { ajax } from 'discourse/lib/ajax';
import { popupAjaxError } from 'discourse/lib/ajax-error';
import Composer from 'discourse/models/composer';

export default Ember.Controller.extend({
  channel: null,
  count: 20,
  messages: [],

  openComposer(topicTitle, topicBody, topicCategoryId) {
    const applicationRoute = Discourse.__container__.lookup('route:application');
    applicationRoute.controllerFor('composer').open({
      action: Composer.CREATE_TOPIC,
      topicTitle,
      topicBody,
      topicCategoryId,
      draftKey: "slack_chat_transcript",
      draftSequence: 1
    });
  },

  actions: {

    fetch() {
      ajax("/slack/messages.json", {
        type: "get",
        data: {
          channel: this.get('channel'),
          count: this.get('count')
        }
      }).then(result => {
        let html = "";
        result.messages.map(m => html += Message.create(m).html());
        this.openComposer("", html, 4);
      }).catch(popupAjaxError);
    }

  }
});
