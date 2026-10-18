# Reads the social policy trees (positions, prerequisites, current texts) from the mod's Override files,
# for the small tree diagrams next to the policy cards. Uses the same row reader as the civ list.
require_relative "civs"

module PolicyTrees
  Node = Struct.new(:type, :name, :help, :x, :y, :level, keyword_init: true)
  # opener/finisher: Node or nil; nodes: the policies of the branch; links: [[prereq, policy]] by type;
  # ideology: true for Freedom/Order/Autocracy (tenets by level instead of a grid).
  Tree = Struct.new(:branch, :name, :opener, :finisher, :nodes, :links, :ideology, keyword_init: true)

  module_function

  def load(override_dir)
    data = Civs.strip_comments(File.read(File.join(override_dir, "CIV5Units.xml"), encoding: "UTF-8"))
    texts = Civs.load_texts(File.join(override_dir, "CIV5Units_Mongol.xml"))
    by_type = lambda do |table|
      h = Civs.rows(data, table).each_with_object({}) { |r, acc| acc[r["Type"]] = r if r["Type"] }
      Civs.apply_updates(data, table, h)
    end
    policies = by_type.("Policies")
    branches = by_type.("PolicyBranchTypes")
    prereqs = Civs.rows(data, "Policy_PrereqPolicies")
    node = lambda do |row|
      Node.new(type: row["Type"], name: plain_name(texts[row["Description"]] || row["Type"]),
               help: texts[row["Help"]], x: row["GridX"].to_i, y: row["GridY"].to_i, level: row["Level"].to_i)
    end
    branches.values.map do |b|
      members = policies.values.select { |p| p["PolicyBranchType"] == b["Type"] }.map(&node)
      types = members.map(&:type)
      opener = b["FreePolicy"] && policies[b["FreePolicy"]] && node.(policies[b["FreePolicy"]])
      finisher = b["FreeFinishingPolicy"] && policies[b["FreeFinishingPolicy"]] && node.(policies[b["FreeFinishingPolicy"]])
      opener&.help ||= texts[b["Help"]]
      links = prereqs.select { |r| types.include?(r["PolicyType"]) && types.include?(r["PrereqPolicy"]) }
                     .map { |r| [r["PrereqPolicy"], r["PolicyType"]] }
      Tree.new(branch: b["Type"], name: plain_name(texts[b["Description"]] || b["Type"]), opener: opener,
               finisher: finisher, nodes: members, links: links, ideology: b["PurchaseByLevel"].to_s =~ /\A(1|true)\z/ ? true : false)
    end.to_h { |t| [t.name.upcase, t] }
  end

  def plain_name(s)
    s.to_s.gsub(/\[[A-Z_0-9]+\]/, "").strip
  end
end
