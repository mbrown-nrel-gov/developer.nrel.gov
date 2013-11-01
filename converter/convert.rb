require "bundler/setup"
require "find"
require "fileutils"
require "nokogiri"
require "erubis"
require "redcarpet"
require "kramdown"
require "tempfile"
require "yaml"
require "rexml/document"
require "json"
require "execjs"
require "pandoc-ruby"

mirror_path = File.expand_path("../mirror", __FILE__)
#`rm -rf #{mirror_path} && wget -m -E -P #{mirror_path} -I /doc "http://developer.nrel.gov/doc"`

markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML, {
  :fenced_code_blocks => true,
  #:disable_indented_code_blocks => true,
  :no_intra_emphasis => true,
})

def tidy(content)
  tidy = ""
  file = Tempfile.new("tidy")
  file.write(content)
  file.close

  tidy = `tidy --show-body-only true --indent auto --wrap 0 --drop-font-tags true #{file.path} 2> /dev/null`.strip
  tidy.gsub!(%r{^<h3.*?>(.*?)</h3>}i, "### \\1")
  tidy.gsub!(%r{^<p.*?>(.*?)</p>}i, "\\1")
  tidy.gsub!(%r{^<span>(.*?)</span>}i, "\\1")
  tidy.gsub!(/(>)\n\n( *<)/, "\\1\n\\2")

  file.unlink

  tidy
end

def format_extra(content)
  extra = Nokogiri::HTML(content)
  extra.search(".doc-example-url").remove
  if(extra.text.strip != "")
    extra = PandocRuby.convert(extra.inner_html, { :from => :html, :to => :markdown }, :no_wrap)
  else
    extra = nil
  end

  extra
end


#converter = PandocRuby.new('# Markdown Title', :from => :markdown, :to => :rst)

template = Erubis::Eruby.new(File.read("template.erb"))

Find.find(mirror_path) do |path|
  if(path =~ %r{api/.*\.html$})
    puts path

    File.open(path) do |file|
      html = file.read
      html.gsub!("\u00A0", " ")
      html.gsub!("\u2013", "-")
      html.gsub!("\u200b", "")

      doc = Nokogiri::HTML(html)
      doc.css("noscript").remove
      doc.css("script").remove
      doc.css(".dsq-brlink").remove
      doc.css(".linenodiv").remove
      doc.xpath("//@style").remove

      before_text = doc.css("#content").first.text
      before_text.gsub!(%r{" />$}m, '"/>')
      before_text = before_text.split(/\s+/).join("\n").strip
      File.open("#{path}-before.txt", 'w') {|f| f.write(before_text) }

      title = doc.css("h1").first.text.strip

      output_path = "#{path.chomp(File.extname(path))}.md"
      #output_path.gsub!(%r{/converter/mirror.*?doc/api/}, "/content/blah/")
      output_path.gsub!(%r{/converter/mirror.*?doc/api/}, "/content/docs/")

      url = title.dup

      case(output_path)
      when %r{utility_rates/v3.md$}
        output_path.gsub!(%r{utility_rates/v3.md$}, "electricity/utility-rates-v3.md")
        title = "Utility Rates"
      when %r{alt-fuel-stations/v1}
        output_path.gsub!(%r{alt-fuel-stations/v1}, "transportation/alt-fuel-stations-v1")
        output_path.gsub!(%r{:id.md$}, "get.md")
        output_path.gsub!(%r{v1.md$}, "v1/all.md")

        case(output_path)
        when %r{/all.md$}
          title = "All Stations"
        when %r{/get.md$}
          title = "Get Station by ID"
        when %r{/nearby-route.md$}
          title = "Stations Nearby Route"
        when %r{/nearest.md$}
          title = "Nearest Stations"
        when %r{/last-updated.md$}
          title = "Last Updated Date"
        end
      when %r{commercial-building-resources/v1}
        output_path.gsub!(%r{commercial-building-resources/v1}, "buildings/commercial-building-resource-database-v1")

        case(output_path)
        when %r{/resources.md$}
          title = "Commercial Building Resources"
        when %r{/vocabulary-name.md$}
          title = "Commercial Building Resource Vocabularies"
        when %r{/events.md$}
          title = "Commercial Building Resource Events"
        end
      when %r{pvdaq/v3}
        output_path.gsub!(%r{pvdaq/v3}, "solar/pvdaq-v3")

        case(output_path)
        when %r{/data.md$}
          title = "Raw Data"
        when %r{/site_data.md$}
          title = "Aggregated Site Data"
        when %r{/sites.md$}
          title = "Sites Metadata"
        end
      when %r{pvwatts/v4.md$}
        output_path.gsub!(%r{pvwatts/v4.md$}, "solar/pvwatts-v4.md")
        title = "PVWatts (Version 4)"
      when %r{georeserv/app/sam/pvwatts.md$}
        output_path.gsub!(%r{georeserv/app/sam/pvwatts.md$}, "solar/pvwatts-v2.md")
        title = "PVWatts (Version 2 - Deprecated)"
      when %r{census_rate/v3.md$}
        output_path.gsub!(%r{census_rate/v3.md$}, "electricity/census-rate-v3.md")
        title = "Utility Rates by Census Region"
      when %r{standard-work-specs/spec/v1.md$}
        output_path.gsub!(%r{standard-work-specs/spec/v1.md$}, "buildings/standard-work-spec-v1.md")
        title = "Standard Work Specifications"
      when %r{georeserv/app/pvdaq}
        output_path.gsub!(%r{georeserv/app/pvdaq}, "solar/pvdaq-v2")

        case(output_path)
        when %r{/data.md$}
          title = "Raw Data (Deprecated)"
        when %r{/site_data.md$}
          title = "Aggregated Site Data (Deprecated)"
        when %r{/sites.md$}
          title = "Sites Metadata (Deprecated)"
        end
      when %r{georeserv/login_handler/post.md$}
        output_path.gsub!(%r{georeserv/login_handler/post.md$}, "solar/pvdaq-v2/login_handler.md")
        title = "Login (Deprecated)"
      when %r{energy-incentives/v1.md$}
        output_path.gsub!(%r{energy-incentives/v1.md$}, "electricity/energy-incentives-v1.md")
        title = "Energy Incentives"
      when %r{georeserv/service/utility_rates.md$}
        output_path.gsub!(%r{georeserv/service/utility_rates.md$}, "electricity/utility-rates-v2.md")
        title = "Utility Rates (Version 2 - Deprecated)"
      when %r{georeserv/service/solar/dni.md$}
        output_path.gsub!(%r{georeserv/service/solar/dni.md$}, "solar/dni.md")
        title = "Direct Normal Irradiance (Deprecated)"
      when %r{georeserv/service/incentives.md$}
        output_path.gsub!(%r{georeserv/service/incentives.md$}, "electricity/incentives.md")
        title = "Incentives (Deprecated)"
      when %r{solar/data_query/v1.md$}
        output_path.gsub!(%r{solar/data_query/v1.md$}, "solar/data-query-v1.md")
        title = "Solar Dataset Query"
      when %r{solar/solar_resource/v1.md$}
        output_path.gsub!(%r{solar/solar_resource/v1.md$}, "solar/solar-resource-v1.md")
        title = "Solar Resource Data"
      end

#converter = PandocRuby.new('# Markdown Title', :from => :markdown, :to => :rst)
      header_texts = PandocRuby.convert(doc.css("h1").first.next_element.inner_html, { :from => :html, :to => :markdown }, :no_wrap).strip.split(/\n+/)
      summary = header_texts.shift

      extended_description = nil
      if(header_texts.any?)
        extended_description = header_texts.join("\n\n")
      end

      request_table = nil
      request_extra = nil
      if(doc.inner_html =~ %r{Request Parameters\s*</h2>(((?!<h2).)*?)(<table.*?)<h2}im)
        request_extra = PandocRuby.convert(Nokogiri::HTML($1).inner_html, { :from => :html, :to => :markdown }, :no_wrap)
        request_table = $3
      end

      response_table = nil
      if(doc.inner_html =~ %r{Response Fields\s*</h2>(((?!<h2).)*?)(<table.*?)<h2}im)
        response_extra = PandocRuby.convert(Nokogiri::HTML($1).inner_html, { :from => :html, :to => :markdown }, :no_wrap)
        response_table = $3
      end

      json_url = nil
      json_extra = nil
      json_body = nil
      original_json = nil
      if(doc.inner_html =~ %r{JSON Output Format</h3>(((?!<h3|h2).)*?)<div class="highlight">(<pre>.*?</pre>)}im)
        json_url = Nokogiri::HTML($1).css(".doc-example-url").inner_html.strip
        json_extra = format_extra($1)
        json_body = Nokogiri::HTML($3).text
        original_json = json_body.dup
        if(!json_body.include?("..."))
          begin
            json_data = JSON.parse(json_body)
            json_body = JSON.pretty_generate(json_data)
          rescue
            begin
              json_body = ExecJS.eval "JSON.stringify(#{json_body})"
              json_data = JSON.parse(json_body)
              json_body = JSON.pretty_generate(json_data)
            rescue
              puts $!.inspect
            end
          end
        end
      end

      xml_url = nil
      xml_extra = nil
      xml_body = nil
      original_xml = nil
      if(doc.inner_html =~ %r{XML Output Format</h3>(((?!<h3|h2).)*?)<div class="highlight">(<pre>.*?</pre>)}im)
        xml_url = Nokogiri::HTML($1).css(".doc-example-url").inner_html.strip
        xml_extra = format_extra($1)
        xml_body = Nokogiri::HTML($3).text
        original_xml = xml_body.dup
        if(!xml_body.include?("..."))
          begin
            xml_body.gsub!(%r{>\s*</}m, "></")
            xml_body = `echo #{xml_body.inspect} | xmllint --format -`
            #xml_body_doc = Nokogiri::XML(xml_body, &:noblanks)
            #xml_body = xml_body_doc.to_xhtml(:indent => 2)
          rescue
            puts $!.inspect
          end
        end
      end

      csv_url = nil
      csv_extra = nil
      csv_body = nil
      if(doc.inner_html =~ %r{CSV Output Format</h3>(((?!<h3|h2).)*?)<div class="highlight">(<pre>.*?</pre>)}im)
        csv_url = Nokogiri::HTML($1).css(".doc-example-url").inner_html.strip
        csv_extra = format_extra($1)
        csv_body = Nokogiri::HTML($3).text
      end

      errors_extra = nil
      errors_table = nil
      if(doc.inner_html =~ %r{may be returned.( In addition.*?)</p>\s*(<table.*?</table>)}im)
        errors_extra = $1
        errors_table = $2
      end

      front_matter = {
        "title" => title,
        "summary" => summary,
        "url" => url,
        "disqus" => true,
      }

      if(title =~ /deprecated/i)
        front_matter["deprecated"] = true
      end

      result = template.result(binding)

      result.gsub!(/\^(\d+)\^/, '<sup>\1</sup>')
      result.gsub!('\$', '$')
      result.gsub!(/ \\$/, '')
      result.gsub!(/\n\n+/, "\n\n")
      result.gsub!("/doc/api-key", "/docs/api-key/")

      test_result = result.gsub(/^---.*?---/m, "")
      test_result.gsub!("{{title}}", url)
      test_result.gsub!("{{summary}}", summary)
      test_result.gsub!("({{url}})", "")
      if original_json
        test_result.gsub!(/```json.*?```/m, "```json\n#{original_json.gsub("\\'", "\\\\\\\\'")}\n```")
      end

      if original_xml
        test_result.gsub!(/```xml.*?```/m, "```xml\n#{original_xml.gsub("\\'", "\\\\\\\\'")}\n```")
      end
      test_result.gsub!(%r{" />$}m, '"/>')

      #rendered_html = markdown.render(test_result)
      rendered_html = Kramdown::Document.new(test_result, :smart_quotes => ['apos', 'apos', 'quot', 'quot'], :input => 'GFM').to_html
      rendered_doc = Nokogiri::HTML(rendered_html)
      after_text = rendered_doc.text.split(/\s+/).join("\n").strip
      File.open("#{path}-after.txt", 'w') {|f| f.write(after_text) }

      if(before_text != after_text)
        puts "  DIFF"
        puts `diff -urBB #{path}-before.txt #{path}-after.txt`
      end

      if(result =~ /(<h([1-6]).*)/i)
        puts "  HEADER: #{$1}"
      end

      if(result =~ /(^ {0,4}<p( |>).*)/i)
        puts "  PARAGRAPH: #{$1}"
      end

      #result.gsub!(%r{developer.nrel.gov/api/}, "api.data.gov/nrel/")
      #result.gsub!(%r{/api/}, "/nrel/")

      #puts output_path
      FileUtils.mkdir_p(File.dirname(output_path))
      File.open(output_path, 'w') {|f| f.write(result) }
    end
  end
end