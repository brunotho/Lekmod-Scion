# Reads changelog.txt (format: see the header of that file) into releases, items and cards.
#
# A release is a "## <name>" block. Its items describe the net change compared to the release before.
# A card is one item across all releases (same key = the TYPE_KEY in brackets, or the name), with one
# entry per release, newest first. Developer lines (Note/DLL/Dev) are dropped.
module Changelog
  PLAYER_KINDS = %w[Added Changed Removed Fixed].freeze
  DEV_KINDS = %w[Note DLL Dev].freeze

  Release = Struct.new(:index, :version, :label, :unreleased, :items, keyword_init: true) do
    def title
      unreleased ? "#{version_from_label || 'Next'} (unreleased)" : version
    end

    # "UNRELEASED (Lekmod Rosebranch 1.0.0, based on LEKMOD v35.4)" -> "1.0.0"
    def version_from_label
      label.to_s[/\b(\d+\.\d+\.\d+)\b/, 1]
    end
  end

  # weight: "major" (default) or "minor" (from a "Weight: minor" line); fresh: the title carries "(NEW)";
  # collects: the section a collection card copies its lines from ("Collects: policies"), shown as a note;
  # subsection: the heading the card is listed under inside its section ("Subsection: Pantheons").
  Item = Struct.new(:key, :name, :tags, :weight, :fresh, :collects, :subsection, :summary, :lines, keyword_init: true) do
    def group
      tags.first
    end

    def minor?
      weight == "minor"
    end

    def player_lines
      lines.select { |l| PLAYER_KINDS.include?(l[:kind]) }
    end

    def player_facing?
      !summary.to_s.empty? || !player_lines.empty?
    end
  end

  Entry = Struct.new(:release, :summary, :lines, keyword_init: true)

  Card = Struct.new(:key, :name, :group, :tags, :minor, :fresh, :collects, :subsection, :entries, keyword_init: true) do
    def search_text
      ([name] + entries.flat_map { |e| [e.summary] + e.lines.map { |l| l[:text] } }).join(" ").downcase
    end
  end

  Document = Struct.new(:tag_order, :releases, keyword_init: true) do
    def cards(include_unreleased: false)
      by_key = {}
      releases.each do |rel|
        next if rel.unreleased && !include_unreleased
        rel.items.each do |item|
          next unless item.player_facing?
          card = (by_key[item.key] ||= Card.new(key: item.key, entries: [], tags: []))
          card.name = item.name
          card.group = item.group
          card.minor = item.minor?
          card.fresh ||= item.fresh
          card.collects = item.collects
          card.subsection = item.subsection
          card.tags = (card.tags + item.tags).uniq
          card.entries.unshift(Entry.new(release: rel, summary: item.summary, lines: item.player_lines))
        end
      end
      by_key.values
    end

    def public_releases(include_unreleased: false)
      releases.reject { |r| r.unreleased && !include_unreleased }
    end
  end

  # "NAME (TYPE_KEY)": the bracket is a developer key when it has _ * . or camelCase, or is all lowercase
  # (a tag-like note such as "(ui)"). Only real type keys identify an item across releases; otherwise the name does.
  TRAILING_BRACKET = /\A(.*?)\s*\(([^()]*)\)\s*\z/
  LINE = /\A- (\w+): (.*)\z/

  def self.split_title(title)
    m = TRAILING_BRACKET.match(title)
    return [title, title] unless m
    name, inner = m[1], m[2]
    type_key = inner =~ /[_*.]|[a-z][A-Z]/ || inner =~ /\A[A-Z0-9]+\z/
    dev_note = type_key || inner =~ /\A[a-z ]+\z/
    return [title, title] unless dev_note
    [name, type_key ? inner : name]
  end

  # Lines of a collection card start with "{Source Card} ": the card the line is copied from.
  def self.split_source(text)
    m = /\A\{([^{}]+)\}\s*(.*)\z/.match(text.to_s)
    m ? [m[1], m[2]] : [nil, text]
  end

  module_function

  def parse(text)
    lines = text.gsub("\r\n", "\n").split("\n")
    tag_order = parse_tag_order(lines)
    releases = []
    i = 0
    while i < lines.size
      line = lines[i]
      if line.start_with?("## ")
        name = line[3..].strip
        unreleased = name.start_with?("UNRELEASED")
        version, label = if unreleased
                           ["UNRELEASED", name[/\((.*)\)/, 1]]
                         else
                           [name.split(/\s+/, 2)[0], name[/\((.*)\)/, 1]]
                         end
        releases << Release.new(index: nil, version: version, label: label,
                                unreleased: unreleased, items: [])
        i += 1
      elsif releases.any? && i + 1 < lines.size && lines[i + 1] =~ /\A-{3,}\s*\z/ && !line.strip.empty?
        item, i = parse_item(lines, i)
        releases.last.items << item
      else
        i += 1
      end
    end
    # The file lists the newest release first; index 1 is the oldest (index 0 = the fork point, LEKMOD v35.4).
    releases.reverse!
    releases.each_with_index { |r, n| r.index = n + 1 }
    Document.new(tag_order: tag_order, releases: releases)
  end

  # The header lists the tag vocabulary ("- Tags: a, b," possibly over several lines); it sets the section order.
  def parse_tag_order(lines)
    start = lines.index { |l| l.start_with?("- Tags:") }
    return [] unless start
    text = lines[start].sub("- Tags:", "")
    j = start + 1
    while j < lines.size && lines[j] =~ /\A\s+\S/ && !lines[j].strip.start_with?("-")
      text += " " + lines[j].strip
      j += 1
    end
    text.split(",").map { |t| t.strip.sub(/\.\z/, "") }.reject(&:empty?)
  end

  # "NAME (NEW) (TYPE_KEY)" or "NAME (NEW)": the marker is shown as a badge, not as part of the name or key.
  NEW_MARKER = /\s*\(NEW\)(?=\s*(?:\([^()]*\))?\s*\z)/

  def parse_item(lines, i)
    title = lines[i].strip
    fresh = !title.match(NEW_MARKER).nil?
    name, key = split_title(title.sub(NEW_MARKER, ""))
    i += 2
    tags = []
    weight = "major"
    collects = nil
    subsection = nil
    while i < lines.size && (m = /\A(Tags|Weight|Collects|Subsection):(.*)\z/.match(lines[i]))
      case m[1]
      when "Tags" then tags = m[2].split(",").map(&:strip).reject(&:empty?)
      when "Weight" then weight = m[2].strip.downcase
      when "Collects" then collects = m[2].strip
      else subsection = m[2].strip
      end
      i += 1
    end
    summary = []
    entries = []
    while i < lines.size
      l = lines[i]
      break if l.start_with?("## ")
      break if i + 1 < lines.size && lines[i + 1] =~ /\A-{3,}\s*\z/ && !l.strip.empty? && !l.start_with?("- ")
      if (m = LINE.match(l))
        entries << { kind: m[1], text: m[2].strip }
      elsif !l.strip.empty? && entries.empty?
        summary << l.strip
      end
      i += 1
    end
    [Item.new(key: key, name: name, tags: tags, weight: weight, fresh: fresh, collects: collects, subsection: subsection, summary: summary.join(" "), lines: entries), i]
  end
end
