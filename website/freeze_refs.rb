#!/usr/bin/env ruby
# Freezes the in-game texts of "- New: TYPE" / "- Reworked: TYPE" lines of one release block into changelog.txt
# ("  | text" under the line), from the Override files of a git revision, so a published release keeps showing what it
# shipped even after later tooltip changes. Lines that already have a frozen text are left alone.
#
#   ruby website/freeze_refs.rb <release version, e.g. 1.0.0> <git revision of that release>
#   ruby website/freeze_refs.rb 1.0.0 c21661ef
# tools/release.py prepare runs it for the new release with HEAD.
require_relative "lib/game_refs"

version, rev = ARGV
abort "usage: freeze_refs.rb <version> <git rev>" unless version && rev
root = File.expand_path("..", __dir__)
path = File.join(root, "changelog.txt")
raw = File.binread(path).force_encoding("UTF-8")
nl = raw.include?("\r\n") ? "\r\n" : "\n"
lines = raw.split(/\r?\n/, -1)
refs = GameRefs.load_rev(root, rev)

out = []
card_key = nil
in_block = false
frozen = missing = 0
i = 0
while i < lines.size
  l = lines[i]
  in_block = l.start_with?("## #{version} ") || l == "## #{version}" if l.start_with?("## ")
  # the card's TYPE_KEY (title line above a dashed line), for "UA"
  if i + 1 < lines.size && lines[i + 1] =~ /\A-{3,}\s*\z/ && !l.start_with?("- ")
    card_key = l[/\(([A-Z][A-Z0-9_]+)\)\s*\z/, 1]
  end
  out << l
  if in_block && (m = /\A- (New|Reworked): (?:\{[^}]*\} )?(\S+)/.match(l))
    j = i + 1
    j += 1 while j < lines.size && lines[j] =~ /\A\s{2,}[-|] /
    unless lines[(i + 1)...j].any? { |x| x =~ /\A\s{2,}\| / }
      ref = refs[GameRefs.key_for(m[2], card_key)]
      if ref && ref.text
        out << "  | #{ref.text}"
        frozen += 1
      else
        warn "no text for #{m[2]} at #{rev}"
        missing += 1
      end
    end
  end
  i += 1
end
File.binwrite(path, out.join(nl))
puts "froze #{frozen} texts in #{version} from #{rev}#{missing.positive? ? ", #{missing} missing" : ''}"
