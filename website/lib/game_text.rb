require "cgi"

# Converts Civ V text markup into HTML: [NEWLINE] becomes a line break, [COLOR_X]...[ENDCOLOR] bold,
# [ICON_BULLET] a bullet, other icons are dropped (the texts name the yield next to the icon anyway).
module GameText
  module_function

  def to_html(text)
    return "" if text.nil?
    s = CGI.escapeHTML(text)
    s = s.gsub("[NEWLINE]", "\n")
    s = s.gsub("[ICON_BULLET]", "&bull; ")
    s = s.gsub(/\[COLOR_[A-Z_]+\]/, "<strong>").gsub("[ENDCOLOR]", "</strong>")
    s = s.gsub(/\[[A-Z_0-9]+\]/, "")
    s = s.gsub(/[ \t]+/, " ").gsub(/ *\n */, "\n").strip
    balance_strong(s).gsub("\n", "<br>")
  end

  # Unclosed [COLOR_X] tags would leave the rest of the page bold.
  def balance_strong(s)
    open = s.scan("<strong>").size - s.scan("</strong>").size
    open.positive? ? s + ("</strong>" * open) : s
  end

  # Changelog lines are plain text; "->" reads better as an arrow.
  def line_html(text)
    CGI.escapeHTML(text.to_s).gsub(" -&gt; ", " &rarr; ")
  end
end
