# Reads every playable civilization with its ability and unique units, buildings and improvements
# straight from the mod's Override files (no game database needed). Same rules as tools/dev/civtexts.py:
# a text tag's last <Row>/<Replace> wins, rows inside XML comments are ignored.
module Civs
  Unique = Struct.new(:kind, :name, :replaces, :text, :stats, keyword_init: true)
  Civ = Struct.new(:type, :name, :leader, :ability_name, :ability, :uniques, keyword_init: true)

  module_function

  def load(override_dir)
    data = strip_comments(File.read(File.join(override_dir, "CIV5Units.xml"), encoding: "UTF-8"))
    texts = load_texts(File.join(override_dir, "CIV5Units_Mongol.xml"))
    # a few rows hold a plain name instead of a text key (the Anti-Tank Rifle's Description)
    t = ->(key) { key && (texts[key] || (key.start_with?("TXT_KEY") ? nil : key)) }
    help = ->(row) { t.(row["Help"]) || t.(row["Strategy"]) }

    by_type = lambda do |table|
      h = rows(data, table).each_with_object({}) { |r, acc| acc[r["Type"]] = r if r["Type"] }
      apply_updates(data, table, h)
    end
    civs = by_type.("Civilizations")
    leaders = by_type.("Leaders")
    traits = by_type.("Traits")
    units = by_type.("Units")
    buildings = by_type.("Buildings")
    improvements = by_type.("Improvements")
    unit_classes = by_type.("UnitClasses")
    building_classes = by_type.("BuildingClasses")

    civ_leaders = group(rows(data, "Civilization_Leaders"), "CivilizationType", "LeaderheadType")
    leader_traits = group(rows(data, "Leader_Traits"), "LeaderType", "TraitType")
    unit_overrides = rows(data, "Civilization_UnitClassOverrides").select { |r| present?(r["UnitType"]) }
    building_overrides = rows(data, "Civilization_BuildingClassOverrides").select { |r| present?(r["BuildingType"]) }
    needs = rows(data, "Unit_ResourceQuantityRequirements").group_by { |r| r["UnitType"] }

    civs.values.select { |c| c["Playable"] == "true" || c["Playable"] == "1" }.map do |c|
      type = c["Type"]
      leader = (civ_leaders[type] || []).first
      trait = (leader_traits[leader] || []).map { |tr| traits[tr] }.compact.first || {}
      uniques = []
      unit_overrides.select { |r| r["CivilizationType"] == type }.map { |r| r["UnitType"] }.uniq.each do |u|
        row = units[u] or next
        default = unit_classes.dig(row["Class"], "DefaultUnit")
        base = default && default != u ? units[default] : nil
        uniques << Unique.new(kind: "Unit", name: t.(row["Description"]), text: help.(row),
                              replaces: base ? t.(base["Description"]) : nil,
                              stats: compare_stats(unit_stats(row, needs[u]), base && unit_stats(base, needs[default]),
                                                   clean_name(base && t.(base["Description"]))))
      end
      civ_buildings = building_overrides.select { |r| r["CivilizationType"] == type }.map { |r| r["BuildingType"] }
      civ_buildings += buildings.values.select { |b| b["RequiredCivilization"] == type }.map { |b| b["Type"] }
      civ_buildings.uniq.each do |b|
        row = buildings[b] or next
        default = building_classes.dig(row["BuildingClass"], "DefaultBuilding")
        base = default && default != b ? buildings[default] : nil
        uniques << Unique.new(kind: "Building", name: t.(row["Description"]), text: help.(row),
                              replaces: base ? t.(base["Description"]) : nil,
                              stats: compare_stats(building_stats(row), base && building_stats(base),
                                                   clean_name(base && t.(base["Description"]))))
      end
      # one entry per name: the Netherlands have a land and a water Polder with the same name and text
      improvements.values.select { |i| i["SpecificCivRequired"] == "true" && i["CivilizationType"] == type }
                  .uniq { |i| i["Description"] }.each do |i|
        uniques << Unique.new(kind: "Improvement", name: t.(i["Description"]), text: help.(i), replaces: nil)
      end
      uniques.each do |u|
        u.name = clean_name(u.name)
        u.replaces = clean_name(u.replaces)
        u.replaces = nil if u.replaces == u.name
        u.text = drop_replaces_sentence(u.text, u.replaces)
      end
      Civ.new(type: type, name: t.(c["ShortDescription"]) || type, leader: t.(leaders.dig(leader, "Description")),
              ability_name: t.(trait["ShortDescription"]), ability: t.(trait["Description"]),
              uniques: uniques.select { |u| u.name })
    end.sort_by { |c| c.name.to_s }
  end

  QUICK = 67 # quick speed: costs x 67 / 100, rounded down like the game

  # Ordered [label, value] pairs of a unit's numbers (quick-speed cost); value nil = the unit doesn't have it.
  def unit_stats(row, needs)
    res = (needs || []).map do |r|
      n = (r["Cost"] || "1").to_i
      name = r["ResourceType"].to_s.sub("RESOURCE_", "").capitalize
      "#{n} #{n > 1 && name == 'Horse' ? 'Horses' : name}"
    end
    ranged = row["RangedCombat"].to_i
    [["Strength", row["Combat"].to_i.positive? ? row["Combat"].to_i : nil],
     ["Ranged Strength", ranged.positive? ? "#{ranged} at range #{row['Range'].to_i}" : nil],
     ["Movement", row["Domain"] != "DOMAIN_AIR" && row["Moves"].to_i.positive? ? row["Moves"].to_i : nil],
     ["Cost", row["Cost"].to_i.positive? ? row["Cost"].to_i * QUICK / 100 : nil],
     ["Needs", res.empty? ? nil : res.join(" and ")]]
  end

  def building_stats(row)
    [["Cost", row["Cost"].to_i.positive? ? row["Cost"].to_i * QUICK / 100 : nil],
     ["Gold maintenance", row["GoldMaintenance"].to_i.positive? ? row["GoldMaintenance"].to_i : nil]]
  end

  # "Strength 12 (Spearman 11) · Movement 2 · Cost 42 (Spearman 37) · Needs 3 Iron (Spearman: nothing)":
  # every number of the unique, and the replaced item's number where it differs.
  def compare_stats(mine, theirs, base_name)
    theirs = theirs.to_h if theirs
    mine.filter_map do |label, v|
      b = theirs && theirs[label]
      next nil if v.nil? && b.nil?
      shown = v.nil? ? "none" : v.to_s
      shown = "#{label} #{shown}"
      if theirs && b != v
        shown += v.is_a?(Integer) && b.is_a?(Integer) ? " (#{base_name} #{b})" : " (#{base_name}: #{b.nil? ? 'none' : b})"
      end
      shown
    end.join(" · ")
  end

  # In-game names mark unique national wonders with a colored "*"; the site shows plain names.
  def clean_name(name)
    return nil if name.nil?
    name.gsub(/\[COLOR_[A-Z_]+\]\s*\*\s*\[ENDCOLOR\]/, "").gsub(/\[[A-Z_0-9]+\]/, "").strip
  end

  # The site prints "replaces X" next to the name, so a text that opens with just "Replaces the X." repeats it.
  def drop_replaces_sentence(text, replaces)
    return text if text.nil? || replaces.nil?
    text.sub(/\AReplaces the (?:\[[A-Z_]+\])?#{Regexp.escape(replaces)}(?:\[ENDCOLOR\])?\.\s*(?:\[NEWLINE\]\s*)*/, "")
  end

  def strip_comments(s)
    s.gsub(/<!--.*?-->/m, "")
  end

  def load_texts(path)
    s = strip_comments(File.read(path, encoding: "UTF-8"))
    out = {}
    s.scan(%r{<(?:Row|Replace)\s+Tag\s*=\s*"([^"]+)"[^>]*>\s*<Text>(.*?)</Text>}m) do |tag, text|
      out[tag] = text.gsub(/\s+/, " ").strip
    end
    out
  end

  # Rows of a table in file order; <Delete/> clears the table so far, <Delete Col="v"/> removes matching rows
  # (removed uniques, e.g. Maurya's Missionary, are deleted this way).
  def rows(data, table)
    out = []
    data.scan(%r{<#{table}>(.*?)</#{table}>}m) do |(block)|
      block.scan(%r{<Row>(.*?)</Row>|<Delete\b([^>]*?)/>}m) do |row, del|
        if row
          out << row.scan(%r{<(\w+)>([^<]*)</\1>}).to_h { |k, v| [k, v.strip] }
        else
          cond = del.scan(/(\w+)="([^"]*)"/).to_h
          cond.empty? ? out.clear : out.reject! { |r| cond.all? { |k, v| r[k] == v } }
        end
      end
    end
    out
  end

  # <Update><Where Type="X"/><Set Col="v" .../></Update> inside the table's blocks (applied after all rows;
  # the Override files put their updates after the rows they change).
  def apply_updates(data, table, by_type)
    data.scan(%r{<#{table}>(.*?)</#{table}>}m) do |(block)|
      block.scan(%r{<Update>(.*?)</Update>}m) do |(upd)|
        type = upd[/<Where\s+Type="([^"]+)"/, 1] or next
        set = upd[%r{<Set\s+([^>]*?)/?>}, 1] or next
        row = by_type[type] or next
        set.scan(/(\w+)="([^"]*)"/) { |k, v| row[k] = v }
      end
    end
    by_type
  end

  def group(rows, key, value)
    rows.each_with_object({}) { |r, h| (h[r[key]] ||= []) << r[value] if r[key] }
  end

  def present?(v)
    v && !v.strip.empty?
  end
end
