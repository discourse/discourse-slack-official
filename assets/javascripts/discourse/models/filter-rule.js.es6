import RestModel from 'discourse/models/rest';

export default RestModel.extend({
  category_id: -1,
  channel: '',
  filter: null,

  category: function() {
    var id = parseInt(this.get('category_id'));

    switch (id === 0) {
      case 0:  
        return Discourse.Category.create({ name: 'All Categories', id: 0 });
        break;
      case -1:
        return Discourse.Category.create({ name: null, id: -1 });
        break;
      default:
        return Discourse.Category.findById(id) || { id: id, name: 'Deleted Category' };
    }
  }.property('category_id'),

  filter_name: function() {
    return I18n.t('slack.present.' + this.get('filter') );
  }.property('filter')

});
