# Reads every playable civilization with its ability and unique units, buildings and improvements
# straight from the mod's Override files (no game database needed). Same rules as tools/dev/civtexts.py:
# a text tag's last <Row>/<Replace> wins, rows inside XML comments are ignored.
module Civs
  Unique = Struct.new(:kind, :name, :replaces, :text, keyword_init: true)
  Civ = Struct.new(:type, :name, :leader, :ability_name, :ability, :uniques, keyword_init: true)

  module_function

  def load(override_dir)
    data = strip_comments(File.read(File.join(override_dir, "CIV5Units.xml"), encoding: "UTF-8"))
    texts = load_texts(File.join(override_dir, "CIV5Units_Mongol.xml"))
    t = ->(key) { key && texts[key] }
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

    civs.values.select { |c| c["Playable"] == "true" || c["Playable"] == "1" }.map do |c|
      type = c["Type"]
      leader = (civ_leaders[type] || []).first
      trait = (leader_traits[leader] || []).map { |tr| traits[tr] }.compact.first || {}
      uniques = []
      unit_overrides.select { |r| r["CivilizationType"] == type }.map { |r| r["UnitType"] }.uniq.each do |u|
        row = units[u] or next
        default = unit_classes.dig(row["Class"], "DefaultUnit")
        uniques << Unique.new(kind: "Unit", name: t.(row["Description"]), text: help.(row),
                              replaces: default && default != u ? t.(units.dig(default, "Description")) : nil)
      end
      civ_buildings = building_overrides.select { |r| r["CivilizationType"] == type }.map { |r| r["BuildingType"] }
      civ_buildings += buildings.values.select { |b| b["RequiredCivilization"] == type }.map { |b| b["Type"] }
      civ_buildings.uniq.each do |b|
        row = buildings[b] or next
        default = building_classes.dig(row["BuildingClass"], "DefaultBuilding")
        uniques << Unique.new(kind: "Building", name: t.(row["Description"]), text: help.(row),
                              replaces: default && default != b ? t.(buildings.dig(default, "Description")) : nil)
      end
      improvements.values.select { |i| i["SpecificCivRequired"] == "true" && i["CivilizationType"] == type }.each do |i|
        uniques << Unique.new(kind: "Improvement", name: t.(i["Description"]), text: help.(i), replaces: nil)
      end
      uniques.each { |u| u.replaces = nil if u.replaces == u.name }
      Civ.new(type: type, name: t.(c["ShortDescription"]) || type, leader: t.(leaders.dig(leader, "Description")),
              ability_name: t.(trait["ShortDescription"]), ability: t.(trait["Description"]),
              uniques: uniques.select { |u| u.name })
    end.sort_by { |c| c.name.to_s }
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

  def rows(data, table)
    out = []
    data.scan(%r{<#{table}>(.*?)</#{table}>}m) do |(block)|
      block.scan(%r{<Row>(.*?)</Row>}m) do |(row)|
        out << row.scan(%r{<(\w+)>([^<]*)</\1>}).to_h { |k, v| [k, v.strip] }
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
