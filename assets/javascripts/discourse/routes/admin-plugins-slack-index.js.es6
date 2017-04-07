export default Discourse.Route.extend({
  beforeModel: function() {
    this.transitionTo("adminPlugins.slack.rules");
  }
});
