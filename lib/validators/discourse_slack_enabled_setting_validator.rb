class DiscourseSlackEnabledSettingValidator
  def initialize(opts={})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == 'f'
    return false if (SiteSetting.slack_outbound_webhook_url.blank? || !valid_webhook_url?) && SiteSetting.slack_access_token.blank?
    return false if SiteSetting.slack_discourse_username.blank? || !valid_slack_username?
    true
  end

  def error_message
    if SiteSetting.slack_outbound_webhook_url.blank? && SiteSetting.slack_access_token.blank?
      I18n.t('site_settings.errors.slack_api_configs_are_empty')
    elsif !valid_webhook_url?
      I18n.t('site_settings.errors.invalid_webhook_url')
    elsif SiteSetting.slack_discourse_username.blank?
      I18n.t('site_settings.errors.slack_discourse_username_is_empty')
    elsif !valid_slack_username?
      I18n.t('site_settings.errors.invalid_username')
    end
  end

  private

  def valid_slack_username?
    @valid_user ||= User.where(username: SiteSetting.slack_discourse_username).exists?
  end

  def valid_webhook_url?
    @valid_webhook_url ||= begin
      !!(URI(SiteSetting.slack_outbound_webhook_url).to_s =~ URI::regexp)
    end
  end
end
