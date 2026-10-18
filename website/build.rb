#!/usr/bin/env ruby
# Builds the Lekmod Rosebranch website into website/_site (plain HTML, CSS and JS for GitHub Pages).
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

ROOT = File.expand_path("..", __dir__)
SITE = File.expand_path(__dir__)

options = { preview: false, out: File.join(SITE, "_site"), map: File.join(ROOT, "..", "lekmap", "CHANGELOG.txt") }
OptionParser.new do |o|
  o.on("--preview") { options[:preview] = true }
  o.on("--out DIR") { |v| options[:out] = File.expand_path(v) }
  o.on("--map FILE") { |v| options[:map] = File.expand_path(v) }
end.parse!

module Helpers
  MOD_RELEASES = "https://github.com/brunotho/Lekmod-Rosebranch/releases/latest".freeze
  MAP_RELEASES = "https://github.com/brunotho/lekmap-rosebranch/releases/latest".freeze
  PAGES = [
    ["index.html", "Mod changelog"],
    ["map.html", "Map changelog"],
    ["install.html", "Installation"],
    ["civs.html", "Civ list"],
    ["bugs.html", "Known issues"],
  ].freeze

  def h(text)
    CGI.escapeHTML(text.to_s)
  end

  def tag_label(tag)
    return "UI" if tag.to_s == "ui"
    tag.to_s.gsub(/[a-z]+/) { |w| w == "and" ? w : w.capitalize }
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
order = doc.tag_order
# Sections in which cards follow the game's own order instead of the alphabet (matched by card name; others after).
GAME_ORDER = {
  "policies" => %w[TRADITION LIBERTY HONOR PIETY PATRONAGE AESTHETICS COMMERCE EXPANSIONISM RATIONALISM
                   AUTOCRACY FREEDOM ORDER],
}.freeze
groups = cards.group_by(&:group).sort_by { |g, _| [order.index(g) || order.size, g.to_s] }
groups = groups.map do |g, list|
  game = GAME_ORDER.fetch(g, [])
  [g, list.sort_by { |c| [c.minor ? 1 : 0, game.index(c.name) || game.size, c.name.downcase] }]
end
all_tags = order.select { |t| cards.any? { |c| c.tags.include?(t) } }
versions = [["0", "LEKMOD v35.4 (fork point)"]] + releases.map { |r| [r.index.to_s, r.title] }
write_page(out, "index.html", "Changelog",
           render("home", groups: groups, all_tags: all_tags, versions: versions, releases: releases),
           page_class: "with-sidebar")

# Map changelog
map_text = File.exist?(options[:map]) ? File.read(options[:map], encoding: "UTF-8") : nil
warn "map changelog not found: #{options[:map]}" unless map_text
write_page(out, "map.html", "Map changelog", render("map", map_html: map_text ? LooseList.to_html(map_text) : nil))

# Installation, civ list, known issues
write_page(out, "install.html", "Installation", render("install"))
civs = Civs.load(File.join(ROOT, "LEKMOD", "Override"))
write_page(out, "civs.html", "Civ list", render("civs", civs: civs), page_class: "with-sidebar")
bugs = File.read(File.join(SITE, "data", "known_issues.txt"), encoding: "UTF-8")
write_page(out, "bugs.html", "Known issues", render("bugs", bugs_html: LooseList.to_html(bugs)))

puts "built #{out}: #{cards.size} changelog items in #{groups.size} sections, #{releases.size} release(s), #{civs.size} civs" \
     "#{options[:preview] ? ' (preview)' : ''}"
