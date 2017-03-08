module Jobs

  class MigrateLegacyData < Jobs::Onceoff
    PLUGIN_NAME = ::DiscourseSlack.plugin_name.freeze

    def execute_onceoff(args)
      rows = ::PluginStoreRow.where(plugin_name: PLUGIN_NAME).where("key ~* :pat", :pat => '^category_.*')

      rows.each do |row|
        ::PluginStore.cast_value(row.type_name, row.value).each do | rule |
          id = row.key.gsub('category_', '')
          ::DiscourseSlack::Slack.set_filter(rule[:channel], rule[:filter], id)
        end
      end

      id = SecureRandom.hex(16)
      ::PluginStore.set(PLUGIN_NAME, "filter_#{id}", { category_id: '*', channel: "#general", filter: "follow", tags: [] })
      ::PluginStore.set(PLUGIN_NAME, "_category_*_#general", id)
    end

  end
end