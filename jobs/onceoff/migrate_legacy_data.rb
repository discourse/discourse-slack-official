module Jobs

  class MigrateLegacyData < Jobs::Onceoff

    def execute_onceoff(args)
      rows = ::PluginStoreRow.where(plugin_name: DiscourseSlack::PLUGIN_NAME).where("key ~* :pat", :pat => '^category_.*')

      rows.each do |row|
        ::PluginStore.cast_value(row.type_name, row.value).each do | rule |
          id = row.key.gsub('category_', '')
          ::DiscourseSlack::Slack.set_filter(rule[:channel], rule[:filter], id)
        end
      end
    end

  end

end
