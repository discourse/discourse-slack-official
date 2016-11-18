class DiscourseSlackEnabledSettingValidator
  def initialize(opts={})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == 'f'
    return false if !valid_webhook_url? || SiteSetting.slack_outbound_webhook_url.blank?
    true
  end

  def error_message
    if !valid_webhook_url?
      I18n.t('site_settings.errors.invalid_webhook_url')
    elsif SiteSetting.slack_outbound_webhook_url.blank?
      I18n.t('site_settings.errors.slack_outbound_webhook_url_is_empty')
    end
  end

  private

  def valid_webhook_url?
    @valid_webhook_url ||= begin
      !!(URI(SiteSetting.slack_outbound_webhook_url).to_s =~ URI::regexp)
    end
  end
end
