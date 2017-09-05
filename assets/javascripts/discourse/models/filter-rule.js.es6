import RestModel from 'discourse/models/rest';
import Category from 'discourse/models/category';
import computed from "ember-addons/ember-computed-decorators";

export default RestModel.extend({
  category_id: null,
  channel: '',
  filter: null,

  @computed('category_id')
  categoryName(categoryId) {
    if (!categoryId) {
      return I18n.t('slack.choose.all_categories');
    }

    const category = Category.findById(categoryId);
    if (!category) {
      return I18n.t('slack.choose.deleted_category');
    }

    return category.get('name');
  },

  @computed('filter')
  filterName(filter) {
    return I18n.t(`slack.present.${filter}`);
  }
});
