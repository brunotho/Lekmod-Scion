require "cgi"

# Converts Civ V text markup into HTML: [NEWLINE] becomes a line break, [ICON_BULLET] a bullet; colour tags and
# other icons are dropped (no emphasis inside sentences, user 2026-10-19; the texts name the yield next to the icon anyway).
module GameText
  module_function

  def to_html(text)
    return "" if text.nil?
    s = CGI.escapeHTML(text)
    s = s.gsub("[NEWLINE]", "\n")
    s = s.gsub("[ICON_BULLET]", "&bull; ")
    s = s.gsub(/\[COLOR_[A-Z_]+\]/, "").gsub("[ENDCOLOR]", "")
    s = s.gsub(/\[[A-Z_0-9]+\]/, "")
    s = s.gsub(/[ \t]+/, " ").gsub(/ *\n */, "\n").strip
    s.gsub("\n", "<br>")
  end

  # Changelog lines are plain text; "->" reads better as an arrow.
  def line_html(text)
    CGI.escapeHTML(text.to_s).gsub(" -&gt; ", " &rarr; ")
  end
end
