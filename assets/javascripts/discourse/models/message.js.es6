import Attachment from 'discourse/plugins/discourse-slack-official/discourse/models/attachment';
import RestModel from 'discourse/models/rest';

export default RestModel.extend({

  html() {
    var html = '';
    const text = this.get('text');
    var username = this.get('user');
    if (!username) username = this.get('username');

    html += '[quote="@' + username + '"]\n';

    if (text) html += text;

    if (this.get('attachments')) {
      this.get('attachments').map(a => html += Attachment.create(a).html(text));
    }

    html += "\n[/quote]\n\n";

    return html;
  }

});
