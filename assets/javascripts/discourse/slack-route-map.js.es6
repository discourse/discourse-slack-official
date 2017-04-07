export default {
  resource: 'admin.adminPlugins',
  path: '/plugins',
  map() {
    this.route('slack', function () {
      this.route('rules');
      this.route('generate');
    });
  }
};
