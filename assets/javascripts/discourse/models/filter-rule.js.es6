import RestModel from 'discourse/models/rest';

export default RestModel.extend({
  category_id: '',
  channel: '',
  filter: null,

  category: function() {
    var id = this.get('category_id');

    switch (id) {
      case '*':
        return Discourse.Category.create({ name: I18n.t('slack.choose.all_categories'), id: '*' });
        break;
      case '':
        return Discourse.Category.create({ name: '', id: '' });
        break;
      default:
        return Discourse.Category.findById(id) || Discourse.Category.create({ name: I18n.t('slack.choose.deleted_category'), id: id });
    }
  }.property('category_id'),

  filter_name: function() {
    return I18n.t('slack.present.' + this.get('filter') );
  }.property('filter')

});
