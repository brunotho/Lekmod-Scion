require "minitest/autorun"
require_relative "../lib/changelog"
require_relative "../lib/game_text"
require_relative "../lib/loose_list"
require_relative "../lib/policy_trees"
require_relative "../lib/game_refs"
require_relative "../lib/civs"

class ChangelogTest < Minitest::Test
  SAMPLE = <<~TXT
    LEKMOD CHANGELOG
    ================
    - Tags: promotions, units, civs,
      game mechanics, ui.

    ## 1.1.0 (2026-11-01)

    HEAL INSTANTLY (PROMOTION_INSTA_HEAL)
    --------------------------------------
    Tags: promotions
    Heals the unit for 20 HP.
    - Changed: heal amount 25 -> 20
    - Dev: define INSTA_HEAL_RATE

    ## 1.0.0 (2026-10-20)
    - Dev: release-level developer line

    HEAL INSTANTLY (PROMOTION_INSTA_HEAL)
    --------------------------------------
    Tags: promotions
    Heals the unit for 25 HP.
    - Changed: heal amount 50 -> 25

    WORLD CONGRESS SCREEN (ui)
    --------------------------
    Tags: ui, game mechanics
    - Added: sorted lists

    INTERNAL ONLY (SOMETHING_X)
    ---------------------------
    Tags: units
    - DLL: nothing for players
  TXT

  def setup
    @doc = Changelog.parse(SAMPLE)
  end

  def test_tag_order_from_header
    assert_equal ["promotions", "units", "civs", "game mechanics", "ui"], @doc.tag_order
  end

  def test_releases_and_items
    assert_equal %w[1.0.0 1.1.0], @doc.releases.map(&:version)
    assert_equal [1, 2], @doc.releases.map(&:index)
    assert_equal 3, @doc.releases[0].items.size
    assert_equal 1, @doc.releases[1].items.size
  end

  def test_card_merges_releases_newest_first
    card = @doc.cards.find { |c| c.key == "PROMOTION_INSTA_HEAL" }
    assert_equal "HEAL INSTANTLY", card.name
    assert_equal %w[1.1.0 1.0.0], card.entries.map { |e| e.release.version }
    assert_equal [{ kind: "Changed", text: "heal amount 25 -> 20" }], card.entries.first.lines
  end

  def test_dev_lines_and_dev_only_items_are_dropped
    keys = @doc.cards.map(&:key)
    refute_includes keys, "SOMETHING_X"
    @doc.cards.each { |c| c.entries.each { |e| e.lines.each { |l| refute_includes Changelog::DEV_KINDS, l[:kind] } } }
  end

  def test_tag_like_bracket_is_not_part_of_the_name
    card = @doc.cards.find { |c| c.name == "WORLD CONGRESS SCREEN" }
    assert card
    assert_equal "ui", card.group
  end

  def test_unreleased_block_only_in_preview
    doc = Changelog.parse("## UNRELEASED (Lekmod Scion 1.2.0)\n\nX (X_Y)\n-------\nTags: ui\n- Added: a\n" + SAMPLE.split("\n", 6).last)
    assert_equal "1.2.0 (unreleased)", doc.releases.last.title
    refute(doc.cards.any? { |c| c.key == "X_Y" })
    assert(doc.cards(include_unreleased: true).any? { |c| c.key == "X_Y" })
  end

  def test_new_marker_and_weight
    doc = Changelog.parse("## 1.0.0 (2026-10-20)\n\nFEAR AURA (NEW) (PROMOTION_FEAR_AURA)\n---------\nTags: promotions\n" \
                          "Weight: minor\n- Added: a\n\nSTART AT WAR (NEW)\n---------\nTags: ui\n- Added: b\n")
    aura = doc.cards.find { |c| c.key == "PROMOTION_FEAR_AURA" }
    assert_equal "FEAR AURA", aura.name
    assert aura.fresh
    assert aura.minor
    war = doc.cards.find { |c| c.name == "START AT WAR" }
    assert war.fresh
    refute war.minor
  end

  def test_game_text
    html = GameText.to_html("[COLOR_GREEN]Wonders[ENDCOLOR] yield +3 [ICON_CULTURE] Culture.[NEWLINE][ICON_BULLET]a & b")
    assert_equal "Wonders yield +3 Culture.<br>&bull; a &amp; b", html
    assert_equal "open", GameText.to_html("[COLOR_RED]open")
    assert_equal "50 &rarr; 25", GameText.line_html("50 -> 25")
  end

  def test_loose_list_nesting
    html = LooseList.to_html("# Title\n- a\n\t- b\n- c\ntext")
    assert_equal "<h2>Title</h2>\n<ul>\n<li>a\n<ul>\n<li>b\n</li></ul></li>\n<li>c\n</li></ul>\n<p>text</p>", html
  end
end

# The real changelog must stay machine-readable for the website.
class RealChangelogTest < Minitest::Test
  PATH = File.expand_path("../../changelog.txt", __dir__)

  def test_real_file_is_well_formed
    doc = Changelog.parse(File.read(PATH, encoding: "UTF-8"))
    refute_empty doc.releases
    vocabulary = doc.tag_order
    problems = []
    doc.releases.each do |rel|
      dups = rel.items.group_by(&:key).select { |_, v| v.size > 1 }.keys
      problems << "#{rel.version}: items with the same key: #{dups.join(', ')}" unless dups.empty?
      rel.items.each do |item|
        problems << "#{item.name}: no Tags line" if item.tags.empty?
        unknown = item.tags - vocabulary
        problems << "#{item.name}: tags not in the header vocabulary: #{unknown.join(', ')}" unless unknown.empty?
        bad = item.lines.reject { |l| (Changelog::PLAYER_KINDS + Changelog::DEV_KINDS).include?(l[:kind]) }
        problems << "#{item.name}: unknown line prefix #{bad.map { |l| l[:kind] }.uniq.join(', ')}" unless bad.empty?
      end
    end
    assert_empty problems, problems.join("\n")
  end

  # "- New: TYPE" / "- Reworked: TYPE" name an item the mod defines ("UA" = the civ's trait); a released block must
  # carry the frozen text ("  | text", website/freeze_refs.rb), so it keeps showing what that release shipped.
  def test_ref_lines_resolve_and_releases_are_frozen
    doc = Changelog.parse(File.read(PATH, encoding: "UTF-8"))
    refs = GameRefs.load(File.expand_path("../../LEKMOD/Override", __dir__))
    problems = []
    doc.releases.each do |rel|
      rel.items.each do |item|
        item.lines.select { |l| Changelog::REF_KINDS.include?(l[:kind]) }.each do |l|
          word = Changelog.ref_word(l[:text])
          problems << "#{item.name}: #{l[:kind]} #{word} is no item type" unless word == "UA" || refs.key?(word) || l[:frozen]
          problems << "#{item.name}: UA but #{item.key} has no trait" if word == "UA" && !refs.key?("UA:#{item.key}") && !l[:frozen]
          problems << "#{rel.version}: #{item.name}: #{word} has no frozen text" if !rel.unreleased && !l[:frozen]
        end
      end
    end
    assert_empty problems, problems.join("\n")
  end

  # Collection cards copy lines from other cards; a copy that no longer matches its source is out of date.
  def test_collection_lines_match_their_source
    doc = Changelog.parse(File.read(PATH, encoding: "UTF-8"))
    problems = []
    doc.releases.each do |rel|
      rel.items.select(&:collects).each do |coll|
        coll.player_lines.each do |line|
          source, text = Changelog.split_source(line[:text])
          src = source && rel.items.find { |it| it.name.casecmp?(source) && !it.collects }
          ok = src&.player_lines&.any? { |l| l[:kind] == line[:kind] && l[:text] == text && l[:items] == line[:items] }
          problems << "#{coll.name}: no matching line on #{source.inspect}: #{text[0, 80]}" unless ok
        end
      end
    end
    assert_empty problems, problems.join("\n")
  end

  # Some civs exist twice (Venice: the playable CIVILIZATION_VENEZ and the unplayable base-game CIVILIZATION_VENICE).
  # A civ card or a trait change on the unplayable copy never reaches the game (2026-10-20: Venice's new UA did).
  # A card for a civ that was made unplayable on purpose says so with a Removed line.
  def test_civ_changes_target_playable_civs
    doc = Changelog.parse(File.read(PATH, encoding: "UTF-8"))
    data = Civs.strip_comments(File.read(File.expand_path("../../LEKMOD/Override/CIV5Units.xml", __dir__), encoding: "UTF-8"))
    playable = Civs.rows(data, "Civilizations").select { |r| %w[true 1].include?(r["Playable"]) }.map { |r| r["Type"] }
    leaders = Civs.rows(data, "Civilization_Leaders").select { |r| playable.include?(r["CivilizationType"]) }.map { |r| r["LeaderheadType"] }
    live_traits = Civs.rows(data, "Leader_Traits").select { |r| leaders.include?(r["LeaderType"]) }.map { |r| r["TraitType"] }
    problems = []
    doc.releases.flat_map(&:items).each do |item|
      next unless item.key.to_s.start_with?("CIVILIZATION_") && !playable.include?(item.key)
      problems << "#{item.name}: #{item.key} is not playable" unless item.lines.any? { |l| l[:kind] == "Removed" }
    end
    data.scan(%r{<Traits>(.*?)</Traits>}m) do |(block)|
      block.scan(/<Where\s+Type="(TRAIT_[A-Z0-9_]+)"/) do |(t)|
        problems << "Traits update on #{t}, which no playable civ has" unless live_traits.include?(t)
      end
    end
    assert_empty problems.uniq, problems.uniq.join("\n")
  end
end

# The policy tree diagrams read the mod's own data; every non-ideology branch has 5 policies, an opener and a finisher.
class PolicyTreesTest < Minitest::Test
  def test_trees_load
    trees = PolicyTrees.load(File.expand_path("../../LEKMOD/Override", __dir__))
    branches = trees.values.reject(&:ideology)
    assert_equal 9, branches.size
    branches.each do |t|
      assert_equal 5, t.nodes.size, t.name
      assert t.opener && t.finisher, t.name
      t.nodes.each { |n| assert (1..5).cover?(n.x) && n.y >= 1, "#{t.name}: #{n.name} off the grid" }
    end
    assert_equal 3, trees.values.count(&:ideology)
  end
end
