# When each wonder becomes available: the tech tree column (Technologies.GridX) of its prerequisite tech, read
# from the mod's Override files. Wonder cards are listed in this order, then by name (user, 2026-10-18).
require_relative "civs"

module WonderTiers
  module_function

  # { "BUILDING_X" => column } for world and national wonders (building classes with an instance limit)
  def load(override_dir)
    data = Civs.strip_comments(File.read(File.join(override_dir, "CIV5Units.xml"), encoding: "UTF-8"))
    by_type = lambda do |table|
      h = Civs.rows(data, table).each_with_object({}) { |r, acc| acc[r["Type"]] = r if r["Type"] }
      Civs.apply_updates(data, table, h)
    end
    techs = by_type.("Technologies")
    classes = by_type.("BuildingClasses")
    by_type.("Buildings").each_with_object({}) do |(type, row), acc|
      cls = classes[row["BuildingClass"]]
      next unless cls && (cls["MaxGlobalInstances"].to_i.positive? || cls["MaxPlayerInstances"].to_i.positive?)
      next if row["Cost"].to_i.negative? # removed wonders (Arsenal of Venice) keep their row with Cost -1
      tech = techs[row["PrereqTech"]]
      acc[type] = tech ? tech["GridX"].to_i : 0
    end
  end

  # Sort key for a card: other cards first (by name), then wonders by column and name. A card naming several
  # wonders counts with its earliest one.
  def sort_key(card, tiers)
    tier = card.key.to_s.scan(/BUILDING_[A-Z0-9_]+/).filter_map { |k| tiers[k] }.min
    tier ? [1, tier, card.name.downcase] : [0, 0, card.name.downcase]
  end
end
