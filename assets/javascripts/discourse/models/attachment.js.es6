import RestModel from 'discourse/models/rest';

export default RestModel.extend({

  html(text) {
    let html = "";
    let prefix = "";

    if (text) prefix += "\n> ";

    if (this.get('title_link')) {
      html += prefix + this.get('title_link')
    } else if (this.get('text')) {
      html += prefix + this.get('text');
    }

    return html;
  }

});
