import RestModel from 'discourse/models/rest';

export default RestModel.extend({
  category_id: null,
  channel: '',
  filter: null,

  category: function() {
    var id = this.get('category_id');

    if (id)
      return Discourse.Category.findById(id) || Discourse.Category.create({ id: id, name: I18n.t('slack.choose.deleted_category') });
    else {
      return Discourse.Category.create({ name: I18n.t('slack.choose.all_categories'), id: null });
    }
  }.property('category_id'),

  filter_name: function() {
    return I18n.t('slack.present.' + this.get('filter') );
  }.property('filter')

});
