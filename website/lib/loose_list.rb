require "cgi"

# Renders loosely written notes (the map changelog, the known-issues list) as HTML:
# "# Title" / "## Title" are headings, "- text" are bullets (indent with a tab or two spaces to nest),
# other non-empty lines are paragraphs. `code` spans are kept.
module LooseList
  module_function

  def to_html(text)
    out = []
    depth = 0
    text.gsub("\r\n", "\n").each_line do |raw|
      line = raw.rstrip
      if line.strip.empty?
        next
      elsif (m = line.match(/\A(#+)\s+(.*)\z/))
        out << close_lists(depth); depth = 0
        level = [m[1].size + 1, 4].min
        out << "<h#{level}>#{inline(m[2])}</h#{level}>"
      elsif (m = line.match(/\A((?:\t|  )*)- (.*)\z/))
        level = m[1].gsub("  ", "\t").size + 1
        if level > depth
          (level - depth).times { out << "<ul>" }
        elsif level < depth
          out << ("</li></ul>" * (depth - level)) + "</li>"
        else
          out << "</li>"
        end
        depth = level
        out << "<li>#{inline(m[2])}"
      else
        out << close_lists(depth); depth = 0
        out << "<p>#{inline(line.strip)}</p>"
      end
    end
    out << close_lists(depth)
    out.reject(&:empty?).join("\n")
  end

  def close_lists(depth)
    depth.positive? ? "</li></ul>" * depth : ""
  end

  def inline(text)
    CGI.escapeHTML(text).gsub(/`([^`]+)`/, '<code>\1</code>').gsub(/\*\*([^*]+)\*\*/, '<strong>\1</strong>')
  end
end
