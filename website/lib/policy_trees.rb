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
               help: resolve(texts[row["Help"]], texts), x: row["GridX"].to_i, y: row["GridY"].to_i, level: row["Level"].to_i)
    end
    branches.values.map do |b|
      members = policies.values.select { |p| p["PolicyBranchType"] == b["Type"] }.map(&node)
      types = members.map(&:type)
      opener = b["FreePolicy"] && policies[b["FreePolicy"]] && node.(policies[b["FreePolicy"]])
      finisher = b["FreeFinishingPolicy"] && policies[b["FreeFinishingPolicy"]] && node.(policies[b["FreeFinishingPolicy"]])
      # The branch help holds both parts ("Adopting X: ..." and "Completing the X tree: ..."); the opener's own
      # help only refers to it, the finisher has none.
      adopt, complete = split_branch_help(resolve(texts[b["Help"]], texts))
      opener.help = adopt if opener
      finisher.help = complete if finisher
      links = prereqs.select { |r| types.include?(r["PolicyType"]) && types.include?(r["PrereqPolicy"]) }
                     .map { |r| [r["PrereqPolicy"], r["PolicyType"]] }
      Tree.new(branch: b["Type"], name: plain_name(texts[b["Description"]] || b["Type"]), opener: opener,
               finisher: finisher, nodes: members, links: links, ideology: b["PurchaseByLevel"].to_s =~ /\A(1|true)\z/ ? true : false)
    end.to_h { |t| [t.name.upcase, t] }
  end

  # "{TXT_KEY_X}" inside a text stands for that text; the branch helps are pre-wrapped for the game's
  # tooltip ("[NEWLINE]" + 5 spaces continues a bullet), which the site undoes.
  def resolve(text, texts)
    return nil if text.nil?
    text.gsub(/\{(TXT_KEY_[A-Z0-9_]+)\}/) { texts[Regexp.last_match(1)] || "" }.gsub(/\[NEWLINE\] {5}/, " ")
  end

  def split_branch_help(text)
    return [nil, nil] if text.nil?
    adopt, complete = text.split(/(?:\[NEWLINE\]){2}(?=Completing)/, 2)
    [adopt, complete]
  end

  def plain_name(s)
    s.to_s.gsub(/\[[A-Z_0-9]+\]/, "").strip
  end
end
