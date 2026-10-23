# Names and in-game texts of items by type (TRAIT_X, UNIT_X, BUILDING_X, PROMOTION_X, BELIEF_X, POLICY_X, ...), read
# from the mod's Override files or from a git revision of them. Changelog lines "- New: TYPE" / "- Reworked: TYPE" show
# the item's current in-game text, so the website and the tooltips cannot drift apart (user, 2026-10-19).
require_relative "civs"

module GameRefs
  Ref = Struct.new(:type, :role, :name, :text, keyword_init: true)
  ROLES = { "Traits" => "Ability", "Units" => "Unit", "Buildings" => "Building", "Improvements" => "Improvement",
            "UnitPromotions" => "Promotion", "Beliefs" => "Belief", "Policies" => "Policy", "Projects" => "Project",
            "PolicyBranchTypes" => "Policy branch" }.freeze

  # table => [name column, text column]
  TABLES = {
    "Traits" => %w[ShortDescription Description],
    "Units" => %w[Description Help],
    "Buildings" => %w[Description Help],
    "Improvements" => %w[Description Help],
    "UnitPromotions" => %w[Description Help],
    "Beliefs" => %w[ShortDescription Description],
    "Policies" => %w[Description Help],
    "Projects" => %w[Description Help],
    "PolicyBranchTypes" => %w[Description Help],
  }.freeze

  module_function

  def load(override_dir)
    from_strings(File.read(File.join(override_dir, "CIV5Units.xml"), encoding: "UTF-8"),
                 File.read(File.join(override_dir, "CIV5Units_Mongol.xml"), encoding: "UTF-8"))
  end

  # The Override files as they were at a git revision (used to freeze a release's texts).
  def load_rev(repo_root, rev)
    show = ->(path) { IO.popen(["git", "-C", repo_root, "show", "#{rev}:#{path}"], &:read).force_encoding("UTF-8") }
    from_strings(show.("LEKMOD/Override/CIV5Units.xml"), show.("LEKMOD/Override/CIV5Units_Mongol.xml"))
  end

  def from_strings(units_xml, texts_xml)
    data = Civs.strip_comments(units_xml)
    texts = {}
    Civs.strip_comments(texts_xml).scan(%r{<(?:Row|Replace)\s+Tag\s*=\s*"([^"]+)"[^>]*>\s*<Text>(.*?)</Text>}m) do |tag, text|
      # "[NEWLINE]" + spaces is the policy tooltip wrap marker (tools/wrap_branch_texts.py), not a real line break
      texts[tag] = text.gsub(/\[NEWLINE\] {2,}/, " ").gsub(/\s+/, " ").strip
    end
    needs = Civs.rows(data, "Unit_ResourceQuantityRequirements").group_by { |r| r["UnitType"] }
    refs = {}
    TABLES.each do |table, (name_col, text_col)|
      rows = Civs.rows(data, table).each_with_object({}) { |r, acc| acc[r["Type"]] = r if r["Type"] }
      rows = Civs.apply_updates(data, table, rows)
      rows = Civs.with_free_range(data, rows) if table == "Units"
      rows.each do |type, row|
        name = texts[row[name_col]] || row[name_col]
        text = texts[row[text_col]] || texts["#{row[name_col]}_HELP"] # some rows never set their Help key
        stats = case table
                when "Units" then unit_stats(row, needs[type] || [])
                when "Buildings" then building_stats(row)
                end
        text = [stats, text].compact.reject(&:empty?).join("[NEWLINE]") if stats
        # names drop markup and the national wonder marker "*"
        refs[type] = Ref.new(type: type, role: ROLES[table], name: name.to_s.gsub(/\[[A-Z_0-9]+\]/, "").delete("*").strip, text: text)
      end
    end
    # policies name their branch: "Tradition policy", "Freedom tenet, tier 2"
    branches = Civs.rows(data, "PolicyBranchTypes").to_h { |r| [r["Type"], r] }
    Civs.rows(data, "Policies").each do |r|
      b = branches[r["PolicyBranchType"]]
      next unless b && refs[r["Type"]]
      bname = refs[b["Type"]]&.name || b["Type"]
      refs[r["Type"]].role = if b["PurchaseByLevel"] == "true" || b["PurchaseByLevel"] == "1"
                               "#{bname} tenet" + (r["Level"].to_i.positive? ? ", tier #{r['Level']}" : "")
                             else
                               "#{bname} policy"
                             end
    end
    # "UA" in a civ card ("- Reworked: UA" under CIVILIZATION_X) = the civ's trait, found through its leader
    leaders = Civs.rows(data, "Civilization_Leaders").to_h { |r| [r["CivilizationType"], r["LeaderheadType"]] }
    traits = Civs.rows(data, "Leader_Traits").to_h { |r| [r["LeaderType"], r["TraitType"]] }
    leaders.each do |civ, leader|
      t = refs[traits[leader]]
      refs["UA:#{civ}"] = t if t
    end
    refs
  end

  QUICK = 67 # quick speed: costs x 67 / 100, rounded down like the game

  # "23 Strength · 4 Movement · costs 73 · needs 6 Horses and 4 Iron" (quick-speed cost)
  def unit_stats(row, needs)
    parts = []
    parts << "#{row['Combat']} Strength" if row["Combat"].to_i.positive?
    if row["RangedCombat"].to_i.positive?
      parts << "#{row['RangedCombat']} Ranged Strength" + (row["Range"].to_i > 1 ? " (range #{row['Range']})" : "")
    end
    parts << "#{row['Moves']} Movement" if row["Moves"].to_i.positive? && row["Domain"] != "DOMAIN_AIR"
    parts << "costs #{row['Cost'].to_i * QUICK / 100}" if row["Cost"].to_i.positive?
    unless needs.empty?
      list = needs.map do |r|
        n = (r["Cost"] || "1").to_i
        res = r["ResourceType"].to_s.sub("RESOURCE_", "").capitalize
        "#{n} #{n > 1 && res == 'Horse' ? 'Horses' : res}"
      end
      parts << "needs #{list.join(' and ')}"
    end
    parts.join(" · ")
  end

  # "costs 67 · 2 Gold maintenance" (quick-speed cost)
  def building_stats(row)
    parts = []
    parts << "costs #{row['Cost'].to_i * QUICK / 100}" if row["Cost"].to_i.positive?
    parts << "#{row['GoldMaintenance']} Gold maintenance" if row["GoldMaintenance"].to_i.positive?
    parts.join(" · ")
  end

  # The type a changelog line names: "UA" means the trait of the card's civilization.
  def key_for(word, card_key)
    word == "UA" ? "UA:#{card_key}" : word
  end
end
