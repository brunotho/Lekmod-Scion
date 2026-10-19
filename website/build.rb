#!/usr/bin/env ruby
# Builds the Lekmod Scion website into website/_site (plain HTML, CSS and JS for GitHub Pages).
#
#   ruby website/build.rb                       public build: released versions only
#   ruby website/build.rb --preview             also shows the UNRELEASED block (local preview)
#   ruby website/build.rb --map PATH/CHANGELOG.txt   map changelog file (default: ../lekmap/CHANGELOG.txt)
#   ruby website/build.rb --out DIR             output folder (default: website/_site)
#
# Preview locally: python -m http.server -d website/_site 8000, then open http://localhost:8000
require "erb"
require "fileutils"
require "json"
require "optparse"
require_relative "lib/changelog"
require_relative "lib/civs"
require_relative "lib/game_text"
require_relative "lib/loose_list"
require_relative "lib/policy_trees"
require_relative "lib/wonder_tiers"
require_relative "lib/game_refs"

ROOT = File.expand_path("..", __dir__)
SITE = File.expand_path(__dir__)

options = { preview: false, out: File.join(SITE, "_site"), map: File.join(ROOT, "..", "lekmap", "CHANGELOG.txt") }
OptionParser.new do |o|
  o.on("--preview") { options[:preview] = true }
  o.on("--out DIR") { |v| options[:out] = File.expand_path(v) }
  o.on("--map FILE") { |v| options[:map] = File.expand_path(v) }
end.parse!

module Helpers
  MOD_RELEASES = "https://github.com/brunotho/Lekmod-Scion/releases/latest".freeze
  MAP_RELEASES = "https://github.com/brunotho/lekmap-scion/releases/latest".freeze
  PAGES = [
    ["index.html", "Mod changelog"],
    ["map.html", "Map changelog"],
    ["install.html", "Installation"],
    ["civs.html", "Civ list"],
    ["credits.html", "Credits"],
  ].freeze

  def h(text)
    CGI.escapeHTML(text.to_s)
  end

  def tag_label(tag)
    return "UI" if tag.to_s == "ui"
    tag.to_s.gsub(/[a-z]+/) { |w| w == "and" ? w : w.capitalize }
  end

  # Small policy tree like the game's: opener on top, the policies on their grid (GridX 1-5, GridY) with
  # prerequisite lines, finisher at the bottom. Ideologies: tenets by level. Hover/focus shows the policy's
  # current text in the panel below (site.js); without JavaScript the title attribute has it.
  PT_COL = 58
  PT_ROW = 56
  PT_W = 56
  PT_BREAKS = %w[Adminis-tration Confed-eracy Entre-preneurship Infra-structure Mercan-tilism Protec-tionism
                 Represen-tation Scholas-ticism Revolu-tion Reforma-tion Sover-eignty Profes-sional Flourish-ing
                 Meritoc-racy Aristoc-racy Citizen-ship Secular-ism].to_h { |w| [w.delete("-"), w.sub("-", "­")] }.freeze
  PT_H = 44

  def policy_tree_html(tree)
    nodes = []
    if tree.ideology
      body = tree.nodes.group_by(&:level).sort.map do |level, list|
        chips = list.sort_by(&:name).map { |n| policy_node(n, nil) }.join
        %(<div class="ptier"><span class="ptier-label">Tier #{level}</span><div class="ptier-nodes">#{chips}</div></div>)
      end.join
      return %(<aside class="ptree ideology" aria-label="#{h tree.name} tenets">#{body}#{ptree_panel}</aside>)
    end
    rows = tree.nodes.map(&:y).max.to_i
    width = PT_COL * 5
    height = PT_ROW * rows
    pos = tree.nodes.to_h { |n| [n.type, [(n.x - 1) * PT_COL + (PT_COL - PT_W) / 2, (n.y - 1) * PT_ROW]] }
    lines = tree.links.filter_map do |a, b|
      next unless pos[a] && pos[b]
      ax, ay = pos[a]
      bx, by = pos[b]
      %(<line x1="#{ax + PT_W / 2}" y1="#{ay + PT_H}" x2="#{bx + PT_W / 2}" y2="#{by}"/>)
    end.join
    tree.nodes.each { |n| nodes << policy_node(n, pos[n.type]) }
    opener = tree.opener ? policy_node(tree.opener, nil, "pbar") : ""
    finisher = tree.finisher ? policy_node(tree.finisher, nil, "pbar", "Completing #{tree.name}") : ""
    %(<aside class="ptree" aria-label="#{h tree.name} policy tree">#{opener}) +
      %(<div class="pgrid" style="width:#{width}px;height:#{height}px"><svg width="#{width}" height="#{height}" aria-hidden="true">#{lines}</svg>#{nodes.join}</div>) +
      %(#{finisher}#{ptree_panel}</aside>)
  end

  def policy_node(node, pos, cls = "pnode", label = nil)
    style = pos ? %( style="left:#{pos[0]}px;top:#{pos[1]}px;width:#{PT_W}px;height:#{PT_H}px") : ""
    tip = node.help ? GameText.to_html(node.help) : ""
    plain = node.help ? CGI.unescapeHTML(tip.gsub("<br>", "\n").gsub(/<[^>]+>/, "")) : ""
    # Long words get a soft hyphen at a syllable, so they break cleanly in the small boxes.
    text = (label || node.name).split(" ").map { |w| PT_BREAKS.fetch(w, w) }.join(" ")
    %(<button type="button" class="#{cls}"#{style} data-help="#{h tip}" title="#{h plain}">#{h text}</button>)
  end

  def ptree_panel
    %(<div class="ptree-panel" aria-live="polite">Hover a policy to read it.</div>)
  end

  def slug(text)
    text.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-\z/, "")
  end

  def render(name, locals = {})
    path = File.join(SITE, "templates", "#{name}.html.erb")
    b = binding
    locals.each { |k, v| b.local_variable_set(k, v) }
    ERB.new(File.read(path, encoding: "UTF-8"), trim_mode: "-").result(b)
  end
end
include Helpers

def write_page(out, file, title, body, page_class: "")
  html = render("layout", title: title, body: body, current: file, page_class: page_class)
  File.write(File.join(out, file), html, encoding: "UTF-8")
end

out = options[:out]
FileUtils.rm_rf(out)
FileUtils.mkdir_p(out)
FileUtils.cp_r(File.join(SITE, "assets"), out)
File.write(File.join(out, ".nojekyll"), "")

# Mod changelog (home)
doc = Changelog.parse(File.read(File.join(ROOT, "changelog.txt"), encoding: "UTF-8"))
releases = doc.public_releases(include_unreleased: options[:preview])
cards = doc.cards(include_unreleased: options[:preview])
# "- New: TYPE" / "- Reworked: TYPE": the item's name and in-game text (frozen text of a release first, else the current one)
game_refs = GameRefs.load(File.join(ROOT, "LEKMOD", "Override"))
cards.each do |card|
  card.entries.each do |entry|
    entry.lines.each do |line|
      next unless Changelog::REF_KINDS.include?(line[:kind])
      ref = game_refs[GameRefs.key_for(Changelog.ref_word(line[:text]), card.key)]
      warn "changelog: unknown type #{line[:text].inspect} in #{card.name}" unless ref
      line[:ref_name] = ref ? ref.name : line[:text]
      line[:ref_role] = ref&.role
      line[:ref_text] = line[:frozen] || (ref && ref.text)
      # policy texts open with their own name, which the line already shows
      line[:ref_text] = line[:ref_text]&.sub(/\A(?:\[COLOR_[A-Z_]+\])?#{Regexp.escape(line[:ref_name])}s?(?:\[ENDCOLOR\])?:?\s*\[NEWLINE\]/i, "")
    end
  end
end
order = doc.tag_order
wonder_tiers = WonderTiers.load(File.join(ROOT, "LEKMOD", "Override"))
# Sections with a fixed card order (matched by card name), optionally split into headed subsections.
# Cards not listed follow alphabetically, wonders after the other cards in the order they become available
# (WonderTiers; "Other" when the section has headings); "Weight: minor" cards always
# come last under "Minor changes". The big reworks read rules first, wonders late (user, 2026-10-18).
SECTION_LAYOUT = {
  "world congress" => [
    [nil, ["WORLD CONGRESS: NEW PROPOSALS", "WORLD CONGRESS PROPOSALS", "WORLD CONGRESS SESSIONS",
           "WORLD CONGRESS DELEGATES"]],
  ],
  "tourism" => [
    ["The rules", ["GREAT WORKS", "TOURISM AND INFLUENCE", "VICTORY: CAPITALS AND INFLUENCE"]],
    ["Where Great Works and Tourism come from", ["GREAT WRITER, ARTIST AND MUSICIAN", "GREAT WORK BUILDINGS",
                                                "NATIONAL EPIC", "HOTEL", "CULTURAL CITY-STATES: ONE GREAT WORK",
                                                "TOURISM WONDERS"]],
    ["Policies and ideologies", ["TOURISM IN POLICIES AND IDEOLOGIES"]],
  ],
  # Split by the game data (2026-10-18): pickable = CannotBeChosen 0 and some unit combat may take it.
  "promotions" => [
    ["Promotions you can pick", ["AMPHIBIOUS LINE", "ENVELOPMENT", "EXPANDED ZOC", "MOUNTAINEERING", "WOODSMAN",
                                 "AMBUSH FORMATION", "MOBILITY", "HEAL INSTANTLY", "COASTAL RAIDER LINE",
                                 "BOARDING PARTY LINE", "ARMOR PLATING LINE", "SAMBUCA", "SUPPLY SHIP", "REPAIR CREW",
                                 "BUNKER BUSTING", "CARPET BOMBING", "AIR SIEGE LINE", "SORTIE", "HELICOPTER PROMOTIONS"]],
    ["Promotions that come with units, policies or abilities (never offered as a pick)",
     ["DISCIPLINE", "FEAR AURA", "ZEALOT", "ALTITUDE TRAINING", "SITTING DUCKS", "SWIFT TRANSPORT", "MARAUDER",
      "IAIJUTSU", "HATAMOTO", "ONE GOOD EYE / STARGAZING", "FAST SWIMMER", "SKYRANGER / EXTENDED PARADROP",
      "GLUTTON", "EMBARKATION WITH DEFENSE", "SPEAR THROW"]],
  ],
  "tiles and resources" => [
    [nil, ["STRATEGIC RESOURCES: OVERVIEW"]],
  ],
  # Espionage: the rules first, the spy wonders after them.
  "espionage" => [
    [nil, ["SPIES AND DIPLOMATS"]],
  ],
  "policies" => [
    [nil, %w[TRADITION LIBERTY HONOR PIETY PATRONAGE AESTHETICS COMMERCE EXPANSIONISM RATIONALISM
             AUTOCRACY FREEDOM ORDER]],
  ],
}.freeze
# Sections whose cards name their own block with a "Subsection:" line, in this order (alphabetical inside).
SUBSECTION_ORDER = {
  "religion" => ["Pantheons", "Founder beliefs", "Follower beliefs", "Enhancer beliefs", "Reformation beliefs"],
  "buildings" => ["Buildings", "Wonders and projects"],
}.freeze
Block = Struct.new(:heading, :minor, :cards)
groups = cards.group_by(&:group).sort_by { |g, _| [order.index(g) || order.size, g.to_s] }
groups = groups.map do |g, list|
  layout = SECTION_LAYOUT.fetch(g, [])
  if SUBSECTION_ORDER.key?(g)
    (list.map(&:subsection).compact.uniq - SUBSECTION_ORDER[g]).each { |s| warn "unknown subsection #{s.inspect} in #{g}" }
    layout = SUBSECTION_ORDER[g].map do |heading|
      [heading, list.select { |c| c.subsection == heading }.sort_by { |c| WonderTiers.sort_key(c, wonder_tiers) }.map(&:name)]
    end
  end
  # A listed card stays in its block even when minor (after the block's major cards).
  blocks = layout.map do |heading, names|
    Block.new(heading, false, names.filter_map { |n| list.find { |c| c.name == n } }.sort_by.with_index { |c, i| [c.minor ? 1 : 0, i] })
  end
  listed = layout.flat_map(&:last)
  (listed - list.map(&:name)).each { |n| warn "SECTION_LAYOUT: no card named #{n.inspect} in #{g}" }
  major, minor = list.reject { |c| listed.include?(c.name) }.partition { |c| !c.minor }
  blocks << Block.new(layout.any?(&:first) ? "Other" : nil, false, major.sort_by { |c| WonderTiers.sort_key(c, wonder_tiers) })
  blocks << Block.new("Minor changes", true, minor.sort_by { |c| WonderTiers.sort_key(c, wonder_tiers) })
  [g, blocks.reject { |b| b.cards.empty? }]
end
all_tags = order.select { |t| cards.any? { |c| c.tags.include?(t) } }
versions = [["0", "LEKMOD v35.4 (fork point)"]] + releases.map { |r| [r.index.to_s, r.title] }
write_page(out, "index.html", "Changelog",
           render("home", groups: groups, all_tags: all_tags, versions: versions, releases: releases,
                         policy_trees: PolicyTrees.load(File.join(ROOT, "LEKMOD", "Override"))),
           page_class: "with-sidebar")

# Map changelog
map_text = File.exist?(options[:map]) ? File.read(options[:map], encoding: "UTF-8") : nil
warn "map changelog not found: #{options[:map]}" unless map_text
write_page(out, "map.html", "Map changelog", render("map", map_html: map_text ? LooseList.to_html(map_text) : nil))

# Installation, civ list
write_page(out, "install.html", "Installation", render("install"))
write_page(out, "credits.html", "Credits", render("credits"))
civs = Civs.load(File.join(ROOT, "LEKMOD", "Override"))
write_page(out, "civs.html", "Civ list", render("civs", civs: civs), page_class: "with-sidebar")
# Known issues page: switched off for now (user, 2026-10-18). To bring it back, re-add it to PAGES and:
# write_page(out, "bugs.html", "Known issues",
#            render("bugs", bugs_html: LooseList.to_html(File.read(File.join(SITE, "data", "known_issues.txt"), encoding: "UTF-8"))))

puts "built #{out}: #{cards.size} changelog items in #{groups.size} sections, #{releases.size} release(s), #{civs.size} civs" \
     "#{options[:preview] ? ' (preview)' : ''}"
