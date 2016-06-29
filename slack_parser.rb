class SlackParser < Nokogiri::XML::SAX::Document

  attr_reader :excerpt

  SPAN_REGEX = /<\s*span[^>]*class\s*=\s*['|"]excerpt['|"][^>]*>/

  def initialize(length)
    @length = length
    @excerpt = ""
    @current_length = 0
    @start_excerpt = false
  end

  def self.get_excerpt(html, length)
    html ||= ''
    length = html.length if html.include?('excerpt') && SPAN_REGEX === html
    me = self.new(length)
    parser = Nokogiri::HTML::SAX::Parser.new(me)
    catch(:done) do
      parser.parse(html.gsub(/\s+/, " "))
    end
    excerpt = me.excerpt.strip
    excerpt = CGI.unescapeHTML(excerpt)
    excerpt
  end

  def escape_attribute(v)
    return "" unless v

    v = v.dup
    v.gsub!("&", "&amp;")
    v.gsub!("\"", "&#34;")
    v
  end

  def start_element(name, attributes=[])
    case name
      when "img"
        attributes = Hash[*attributes.flatten]

        if attributes["class"] == 'emoji'
          return characters(attributes["alt"])
        end

        if attributes["alt"]
          characters("#{attributes["alt"]}")
        elsif attributes["title"]
          characters("#{attributes["title"]}")
        else
          characters("#{I18n.t 'excerpt_image'}")
        end
      when "a"
        attributes = Hash[*attributes.flatten]
        url = ::DiscourseSlack::Slack.absolute(attributes['href'])
        characters("<#{url}|", false, false, false)
        @in_a = true
      when "aside"
        characters("\n> ", false, false, false)
        @in_quote = true

      when "div", "span"
        if attributes.include?(["class", "excerpt"])
          @excerpt = ""
          @current_length = 0
          @start_excerpt = true
        end
        # Preserve spoilers
        if attributes.include?(["class", "spoiler"])
          include_tag("span", attributes)
        end
    end
  end

  def end_element(name)
    case name
    when "a"
      characters(">",false, false, false)
      @in_a = false
    when "br"
      characters(" ", false, false, false)
    when "p",
      characters("", false, false, false)
    when "aside"
      characters("\n\n", false, false, false)
      @in_quote = false
    when "div", "span"
      throw :done if @start_excerpt
      characters("", false, false, false)
    end
  end

  def characters(string, truncate = true, count_it = true, encode = true)
    encode = encode ? lambda{|s| ERB::Util.html_escape(s)} : lambda {|s| s}
    if count_it && @current_length + string.length > @length
      length = [0, @length - @current_length - 1].max
      @excerpt << encode.call(string[0..length]) if truncate
      @excerpt << ("...")
      throw :done
    end
    @excerpt << encode.call(string)
    @current_length += string.length if count_it
  end
end