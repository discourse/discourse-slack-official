module DiscourseSlack
  class SlackMessageFormatter < Nokogiri::XML::SAX::Document
    attr_reader :excerpt

    def initialize
      @excerpt = ""
    end

    def self.format(html = '')
      me = self.new
      parser = Nokogiri::HTML::SAX::Parser.new(me)
      parser.parse(html)
      me.excerpt
    end

    def start_element(name, attributes = [])
      if name == "a"
        attributes = Hash[*attributes.flatten]
        @in_a = true
        @excerpt << "<#{absolute_url(attributes['href'])}|"
      end
    end

    def end_element(name)
      if name == "a"
        @excerpt << ">"
        @in_a = false
      end
    end

    def characters(string)
      string.strip! if @in_a
      @excerpt << string
    end

    private

      def absolute_url(url)
        uri = URI(url) rescue nil

        return Discourse.current_hostname unless uri
        return uri.to_s unless [nil, "http", "https"].include? uri.scheme

        begin
          uri.host = Discourse.current_hostname if !uri.host
          uri.scheme = (SiteSetting.force_https ? 'https' : 'http') if !uri.scheme
          uri.to_s
        rescue => e
          Rails.logger.error [e.message, e.backtrace.join("\n"), "current_hostname: #{Discourse.current_hostname}"].join("\n\n")
        end
      end
  end
end
