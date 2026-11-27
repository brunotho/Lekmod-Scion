# Placement spec v0.11 (authoritative)

Target behaviour for **global six-start placement** (Pangaea / **6 players only** for now). Implementation: **Lane A** (new path; keep old code **commented out**, not deleted) — clean slate for the new solver; **vanilla / pre-Lekmap code paths stay in the file but are commented out rather than deleted** when superseded.

- Older glossary / balance / tuple-pool scratchpads were removed 2026-09-27 (git history).

### Plain language cheat sheet (jargon → simple)

| Term | In plain words |
|------|----------------|
| **`OK()` / “passes OK”** | **All placement rules pass** for this full set of six capitals (distance to middle, spacing, salt-water near inland starts, etc.). |
| **6-tuple / tuple** | **One complete pick**: all **six** capital tiles together (not one tile at a time in isolation). |
| **`startingPlots[r]`** | **The capital tile for “map chunk” number `r`** (1…6) **before** we know which **player** owns that chunk. |
| **`r` / region index** | **Which of the six map chunks** — not “player 3” yet, just “chunk 3.” |
| **`GenerateRegions`** | **Cut the map into six areas** (rectangles) and label each with stats / type. |
| **`regionTypes[r]`** | **Mostly “what biome flavor is chunk `r`?”** (grass / jungle / …) — used for luxuries and for scoring a capital **in** that chunk. |
| **`ChooseLocations`** | Firaxis step that **picks the six regional capitals** (we may **replace** the inside of this with our solver when the flag is on). |
| **`EvaluateCandidatePlot`** | **Is this single city site good enough?** Counts food/hills/junk in rings around the tile; **yes/no** minimums + a score. |
| **`BalanceAndAssign`** | **Who plays on which chunk** — matches **players / civs** to the six **`startingPlots[r]`** using coast, river, and XML likes/dislikes. |
| **`PlotDistance` / `d(p)`** | **How many tiles (game distance)** from a capital **`p`** to another point (e.g. map **middle**). |
| **`d₂`** | From one capital, **distance to your second-closest** rival capital (same distance measure). |
| **`PlaceImpactAndRipples`** | After placing one start, **mark “too crowded here”** on nearby tiles so the next picks stay spread out. |
| **XML bias / priority/avoid** | **From the civ database**: “I want coast / I hate tundra / I prefer forest region” — applied when **`BalanceAndAssign`** hands chunks to civs. |
| **Early bind / trial civ↔`r`** | **While searching**, pretend “Rome might take chunk 2” so we don’t pick six tiles **no** assignment could satisfy — **not** skipping **`BalanceAndAssign`**. |
| **Hook** | **Single switch in code**: “use new six-at-once solver” vs “use old flow.” |
| **Predicate** | **One checklist line** (yes/no) inside **`OK()`**. |
| **Fallback** | If our solver gives up, **use today’s placement** so the game still starts. |
| **`Map.Rand` tie-break** | If two full setups are equally good, **flip a coin** (fair random choice). |

---

## Strategy: strict first

Implement **full strictness** (every **`OK`** rule on; **no** “almost-good is fine”; full **`EvaluateCandidatePlot`** / site-quality gates; **no loosening** (`zero slack`) at first). **Log every failed check** (counts + what failed last). Measure **how many full six-capital tries** (`6-tuple attempts`), **how many map rerolls** (`map regens`), and time. **Ease rules only after you have data**, not before.

---

## Scope

- **Six majors only.** 4p / 8p **out of scope** until this path is stable.
- **`GAMEOPTION_DISABLE_START_BIAS`** (game option: **ignore start biases**): **skip** our new solver entirely — use **normal** `ChooseLocations` → `BalanceAndAssign` only.

---

## Order of operations (geographic regions vs player assignment)

1. **`GenerateRegions`** — Builds **six** fixed **geographic** areas **`r = 1…6`** on the map (each has a rectangle / candidate hunt area). **`regionTypes[r]`** (grassland, forest class, etc.) is **per region**, **not** per player. **Nothing here** picks which **human** sits where.

2. **`ChooseLocations`** / **global solver** — For **each** **`r`**, choose **one** capital plot **`startingPlots[r] = { x, y }`** (usually inside region **`r`**’s candidates). The **6-tuple is keyed by `r`**, the **map region index**. **`EvaluateCandidatePlot`** is called with **`regionTypes[r]`** for that search — you **are** “doing your thing **within** each region,” but the **labels** are **`r`**, not “player 3” yet.

3. **`BalanceAndAssign`** — **After** all six **`startingPlots[r]`** exist: **permute** **which player / civ** receives **which `r`**. Uses coast, river, XML **priority/avoid** (including **forest-as-region-class**, etc.): e.g. a forest-priority civ should end up on an **`r`** whose **type + plot** still validly matched scoring. It **does not** output new **`(x,y)`**; it **consumes** what step 2 wrote.

**Why this order:** capitals must exist **before** the engine can attach a **specific** civ to a **specific** region’s plot. **“Region assignment”** in the sense **player↔`r`** comes **last**. **“Region assignment”** in the sense **where on Earth is region 5’s rectangle** comes **first** (step 1).

**§5 / early bind:** To verify **OK** (“some civ can go on each **`r`** with XML satisfied”), the solver may **internally** assume a **trial** civ↔`r` matching **while** searching tuples — that is **not** **`BalanceAndAssign` running early**; it is duplicating the **same constraints** B&A will enforce later.

### Bias vs ring geometry — what runs when (FAQ)

| Phase | What “bias” means here | Player↔region? |
|--------|-------------------------|----------------|
| **Before / step 1** | **`GenerateRegions`** + **`regionTypes[r]`**: each **geographic** slice **`r`** gets a **terrain class** for lux / **`EvaluateCandidatePlot`**. That is **map metadata**, not “**Civ A** must sit here.” | **No.** |
| **Step 2 (ring / `OK` / solver)** | Pick **`startingPlots[r]`** using **`regionTypes[r]`** for site scoring. **Global geometry** (centre distance, **`d₂`**, six-cycle coastal rule, inland salt) applies to the **six plots**. Still **no** “which human is slot **`r`**.” | **No.** |
| **Step 3 (`BalanceAndAssign`)** | **XML civ bias** (coast, river, forest **priority/avoid**, …): **which player** gets **which** region index **`r`**, so needs match **`startingPlots[r]`** and **`regionTypes[r]`**. | **Yes — only step that assigns players ↔ `r`.** |

So: **vanilla does not** finish “assign players to regions” **before** your ring / **`OK`** work. The **only** step that maps **players ↔ geographic `r`** is **step 3**. Step 1 only prepares **anonymous** regions on the map; step 2 fills their capitals; step 3 attaches **identities**.

---

## Terminology + code pointers

| Term | Meaning | Where in repo |
|------|---------|----------------|
| **`region_number` `r`** | Index **1…`iNumCivs`**. Each **r** owns one rectangle from **`GenerateRegions`** (`self.regionData[r]`). | `4a_HBAssignStartingPlots.lua` — `regionData`, `GenerateRegions` |
| **`self.startingPlots[r]`** | **Table** `{ x, y, score? }` = capital **for region r** before players are attached. **`ChooseLocations` / new solver** fills this; **`BalanceAndAssign`** then gives each **player** one region’s plot. | Written ~`L3692+` in `FindStart` / virtual six; read **`BalanceAndAssign`** ~`L6508+` |
| **`self.regionTypes[r]`** | Integer **terrain/region class** for luxuries / `EvaluateCandidatePlot` (grassland, hills, …). Passed as **`region_type`** into **`EvaluateCandidatePlot`**. | `DetermineRegionTypes`, **`EvaluateCandidatePlot(plotIndex, region_type)`** ~`L3115` |
| **`self.distanceData`** | Per-plot **ripple** from placed starts; drives **`distance_bias`** in **`EvaluateCandidatePlot`**. Initialized in **`AssignStartingPlots.Create`** ~`L254`. | **`PlaceImpactAndRipples`** ~`L2847+` |
| **`distance_bias`** | `self.distanceData[plotIndex]` — if **> 0**, **`EvaluateCandidatePlot`** sets **`goodSoFar = false`** (plot treated as **fallback** tier for crowding). | ~`L3152`, ~`L3444` |
| **`EvaluateCandidatePlot`** | Returns **`finalScore`, `meets_minimums`**. For **`OK`**, only **`meets_minimums`** is a **hard** gate unless you explicitly add **`finalScore`** tie-break between two passing 6-tuples. | ~`L3115–L3459` |
| **`CivNeedsCoastalStart`**, **`CivNeedsRiverStart`** | **XML-driven** booleans. | **`1_HBMapmakerUtilities.lua`** ~`L775`, ~`L785` |
| **`PlaceImpactAndRipples(x,y)`** | Writes **`distanceData`** ripples + **resource/CS/NW** impact layers for one placed start. **`OK`** simulation uses **full** calls, not distance-only. | ~`L2847` |

**Civ bias vs tile quality:** XML **priority/avoid** applies **after** **`BalanceAndAssign`** picks **which civ** sits on **which `r`**. During step 2 the code scores candidates with **`regionTypes[r]`** only (terrain class for that **map region**). **Forest** in XML is that kind of **region / biome bias**, not a separate **`OK()`** forest-tile count. **Early bind** = solver may **simulate** a civ↔`r` plan **while** searching so the multiset stays **B&A-feasible** — **not** that **`BalanceAndAssign` runs before** **`startingPlots[r]`** exist.

**`MixedBias` / `CivNeedsPlaceFirstCoastalStart`:** mirror the same **pre-pass logic** `ChooseLocations` uses today (including random clearing of coastal need when **`MixedBias`** rolls), so the solver’s planned civ-needs match what **`BalanceAndAssign`** expects.

---

## Pinned — OK §5 feasibility (solver vs `BalanceAndAssign`)

**Intent:** Step 2 (**global tuple search**) must **plan ahead** for step 3: every accepted six-tuple must admit **at least one** civ↔**`r`** assignment that would satisfy **`BalanceAndAssign`** XML rules (coast, river, region priority / avoid) against the **actual** plots and **`regionTypes[r]`**.

**Implementation (pinned):** **Single source of truth** — factor **shared predicate / matching logic** out of **`BalanceAndAssign`** (or refactor B&A to call it) and invoke that from the **solver** when testing §5. **Do not** maintain a **second full copy** of B&A’s bias assignment logic (drift risk).

**Staging allowed:** cheap **necessary** checks first (e.g. counts of coastal-capable regions vs coastal-needing civs), then the **shared** feasibility routine — but **no** long-term parallel implementation of the same rules.

---

## Resolved design choices

| Topic | Decision |
|--------|----------|
| **`BalanceAndAssign` / Variation A** | **Confirmed:** global solver **only** fills **`startingPlots[1…6]`** with coordinates that satisfy **`OK()`**. **`BalanceAndAssign`** runs **after** that: it **assigns players to regions** and applies coast / river / priority / avoid — it does **not** search the map for the six plots. The solver must only output tuples for which **some** vanilla assignment exists (**`BalanceAndAssign` handoff** above). |
| **OK §5 / solver (pinned)** | **§ Pinned — OK §5 feasibility** above: shared core with **`BalanceAndAssign`**, **not** duplicated B&A logic. |
| **`d₂` metric (OK §2)** | Same as §1: **pairwise `PlotDistance` / `Map.PlotDistance`** between the **two capital plots** (each **start** vs each of the **other five**); **second-nearest** distance must be **`≤ 15`**. |
| **Map centre distance (OK §1)** | **Hard band:** **`8 < d(p) < 19`** (integer distance ⇒ **`9 ≤ d(p) ≤ 18`**) from map centre using **`Map.PlotDistance` / `PlotDistance`** on each final capital plot **`p`**. **Tie-break** among passing tuples: minimise **`maxᵢ \|d(pᵢ) − 13\|`**; further ties **`Map.Rand`** (fair pick among ties). **Replaces** v0.3 **{12,13,14}** annulus. |
| **Non-coastal (OK §3 inland salt)** | **Same logic as today for “inland civ / inland starting spot”** in **`4a`** (e.g. **`plotDataIsCoastal`** / coastal-need chain aligned with **`BalanceAndAssign`**). Inland salt counts apply only when that predicate says **non-coastal**. |
| **Map script hook** | **Chosen: A — thin hook** at **`ChooseLocations`** (or equivalent) **entry** after **`GAMEOPTION_DISABLE_START_BIAS`** check; record **`file:line`** in revision log when coded. |
| **OK §7 / site quality** | **Full** **`EvaluateCandidatePlot`** + **full** **`PlaceImpactAndRipples`** in **fixed region order 1→6**, then snapshot-restore layers after each failed tuple. |
| **Inland salt (OK §4)** | Hex **distance ≤ 3** from start; count **salt ocean** (**`IsWater` and not `IsLake`**) **`≤ 4`** per **non-coastal** start. (**Single authoritative numbers**; any older heuristic using **d≤4** in interim code is **obsolete** once the solver lands.) |
| **Coastal adjacency on ring** | **Only** when **exactly two** coastal majors: **`C`** not adjacent to **`C`** on the **geographic** six-cycle (see § **Six-cycle intuition** below). |
| **Ring geometry (2-coastal rule)** | **Random rotation** of which geometric slot is cycle index 0 (per attempt). |
| **Ripple simulation order** | **Fixed `r = 1…6`**. |
| **Player count** | **Six only** for this path. |
| **`GAMEOPTION_DISABLE_START_BIAS`** | **Vanilla path only** — no new global solver. |
| **Legacy code hygiene (Lane A)** | Prefer **commenting out** superseded **vanilla-era** branches over deleting them, so diffs stay reviewable and rollback is easy. |
| **Interim `LekVirtualSix` / heuristics** | Treated as **pre-spec** exploration; **remove or disable** when the global-`OK` solver is wired — do **not** treat **32× shuffle / inland-salt tiebreak** as the target contract. |

**Cleanup landed (repo):** Default map script sets **`_lek_enable_virtual_six_retries = false`**, **`_lek_disable_virtual_six = true`**, **`_lek_flatten_region_start_tiers = false`**, **`_lek_global_six_solver = false`**. **`EvaluateCandidatePlot`** map-center / salt **`finalScore`** tweaks are **commented out** in `4a`; virtual-six helpers remain for dev re-enable.


---

## Six-cycle intuition (two-coastal rule)

Think of **six labelled slots** **`0…5`** laid **in order** around the map (the “ring” is that **ordering** of regions / starts, not a drawn circle in tile space). **Neighbours on the cycle** = **indices differing by **1 mod 6**** (slot **5** is neighbour of **0** and **4**). **Not** the same as **hex-adjacent** capital tiles.

Mark which slots are **coastal** majors **`C`**. The **OK** rule: **no** two **`C`** on adjacent cycle indices. **Random rotation** means: which **real** region ordering becomes index **0** is arbitrary per attempt, as long as the cyclic neighbour relation is consistent.

---

## Ring shape — Option B (reserve only)

**Option B** (e.g. minimise radial spread of the six **`d(p)`** subject to **`d₂≤15`**, inland salt, … while staying inside **§1** band **9–18**) stays a **pressure valve** if tuple search is too slow — **not** v0.4 default.

---

## River / forest wording

- **River need:** satisfiable via **`plot:IsRiverSide() or plot:IsFreshWater()`** on the **assigned** start for that civ/region (match **`FindStart`** / classification where possible).
- **Forest in XML:** civs can **prefer/avoid** **forest** as a **region terrain class**; that flows through **`regionTypes[r]`** and **`EvaluateCandidatePlot`**. There is **no separate OK() rule** like “capital must have N forest tiles.” **Ignore** unless you explicitly add such a clause later.

---

## `BalanceAndAssign` handoff

**Order:** solver (or legacy **`ChooseLocations`**) writes **`startingPlots[r]`** first → **`BalanceAndAssign`** then maps **players ↔ regions** using those plots. You **cannot** “only receive coordinates from **`BalanceAndAssign`**” for placement: **`BalanceAndAssign`** does **not** emit the six **`(x,y)`**; it **consumes** them.

The six **`startingPlots[r]`** must be compatible with **`BalanceAndAssign`**’s coast / river / priority / avoid matching **for some** assignment order consistent with **`player_ID_list`**. If impossible, change **`BalanceAndAssign`** (larger project) — not a silent mismatch. The **solver** enforces this feasibility during search using the **same** logic (**§ Pinned — OK §5**).

---

## Global `OK` checklist (v0.11)

1. **Map centre distance:** **`9 ≤ d(p) ≤ 18`** for each start (**same** as **`d > 8` and `d < 19`** in integer **`PlotDistance`**). Among passing tuples: tie-break **`min maxᵢ \|d(pᵢ) − 13\|`**, then **`Map.Rand`** on remaining ties.  
2. **`d₂ ≤ 15`:** **`PlotDistance`** between capital plots; each start’s **second-nearest** of the other five **`≤ 15`**.  
3. **Inland salt:** non-coastal starts: **≤ 4** salt-ocean hexes within **d ≤ 3**.  
4. **Two coastals:** on rotated geographic cycle, **no adjacent `C`/`C`**.  
5. **Bias:** **some** **civ↔`r`** assignment satisfies XML coast / river / region priority / avoid vs **actual** plots and **`regionTypes`**, tested with **shared** logic (**§ Pinned — OK §5**).  
6. **Site quality:** **`EvaluateCandidatePlot`** → **`meets_minimums == true`** per **`r`**, after simulating **six** **`PlaceImpactAndRipples`** in order **1→6**.

### Log / code quick ref (`s1`…`s6`)

Authority: **`4a_HBAssignStartingPlots.lua`** (`LekGlobalSix_OK_RunAll`); logs tag **`s1`…`s6`** = same order. *(Spec table below once said **`d₂ ≤ 15`**; current code constant is often **`16`** — trust **`tuplePhase … s2max=`** and **`s2_secondNearest_leNN`** in the live log.)*

| Tag | One line |
|-----|----------|
| **s1** | Each start’s **map-centre ring**: distance from capital to **(iW/2, iH/2)** must lie in **`[s1_min, s1_max]`** (see **`tuplePhase s1=…`**). |
| **s2** | **`d₂` spacing:** for each start, sort distances to the **other five**; **2nd smallest** must be **`≤ s2max`** ( **`tupleHeadSecondNearest` / `s2_cap`** ). |
| **s3** | **Inland salt:** non-coastal starts: at most **4** salt-ocean tiles within **`PlotDistance ≤ 3`**. |
| **s4** | **Two-coastal cycle:** six regions around the map → **no two adjacent coastals** in that order ( **`IsCoastalLand`-style** coastal ). |
| **s5** | **Civ↔region feasibility:** some **injective** matching of players to **`r`** satisfies XML **coast / river / priority / avoid** vs **`startingPlots`** + **`regionTypes`**. |
| **s6** | **Site mins:** **`EvaluateCandidatePlot`** **`meets_minimums`** for every **`r`** after full **ripple** simulation. |

---

## Search + regen + fallback

- **100** failed **complete** 6-tuples **per map layout**.  
- **4** map layouts total (**1** initial **+** **3** regens) ⇒ **400** failed tuples max before **fallback**.  
- **First implementation target** for the above counts; **tune after metrics** (regen rate, wall-clock), not preemptively.  
- **Fallback:** **`ChooseLocations`** as today (**including** interim virtual-six block **until** removed/disabled per Lane A).  
- Log **failure kind** each time (ring, **d₂**, salt, 2-coastal, bias, **`meets_minimums`**, ripples, …).

---

## Map script hook (where the solver runs — options)

**Meaning:** Civ runs **`AssignStartingPlots`** → **`ChooseLocations`** fills **`startingPlots[r]`** → **`BalanceAndAssign`** matches players. The **hook** is the **chosen place** that decides “run **global six-tuple `OK()` solver**” vs “legacy **`ChooseLocations`** / virtual-six / **`FindStart`** per region”. A clear hook keeps **`_lek_global_six_solver`** / **`GAMEOPTION_DISABLE_START_BIAS`** behaviour auditable.

| Option | Idea | Pros | Cons |
|--------|------|------|------|
| **A — Thin hook** | **One** branch at **`ChooseLocations`** (or equivalent) **entry** after setup: e.g. `if _lek_global_six_solver and conditions then LekGlobalSixPlace() else vanilla end`. | Easy to **grep**; one place to enforce **disable-bias** short-circuit; obvious fallback path. | Must thread any **pre-`ChooseLocations`** setup the solver needs into that entry. |
| **B — Scattered guards** | Multiple **`if solver`** checks inside **`FindStart`**, virtual six, drafts, etc. | Can reuse small bits of legacy path. | Easy to **miss a branch**; hard to prove **every** route respects flags and **fallback**. |
| **C — Map script only** | Hook lives in **`LekmapPangaeaFractal…lua`** (or one map file): set flags / call a thin override so **other** map types never see the solver. | **Isolates** Pangaea experiments. | **Duplicate** if a second map script wants the same solver; core **`4a`** may still need a **callable entry** API. |

**Chosen:** **A** — hook **`ChooseLocations`** + **`LekGlobalSixChooseLocations`** (see **revision log** for `file:line`).

---

## Post-wiring cleanup (eject interim code)

**Run once** the global **`OK()`** solver is the real path, **fallback** is defined, and you no longer need the old experiments side-by-side.

| Item | Where / what |
|------|----------------|
| **Virtual-six retry block** | **`4a_HBAssignStartingPlots.lua`** — **`ChooseLocations`** branch **`iNumCivs == 6`**, `_lek_enable_virtual_six_retries`, snapshot/restore, **`LEK_VIRTUAL_SIX_ATTEMPTS`**, tie-break **`LekVirtualSixInlandOceanUndesirable`**. **Remove** the block (or replace with `assert(not …)` in dev only) so only **global solver** + **one vanilla fallback** path remain. |
| **Virtual-six helpers** | **`LekVirtualSixInlandOceanUndesirable`**, comments at **`LEK_VIRTUAL_SIX_ATTEMPTS`**. Drop if unused after block removal; keep **`LekRunOneStartPlacementPass`** if vanilla fallback still calls it. |
| **Flags** | **`_lek_enable_virtual_six_retries`**, **`_lek_disable_virtual_six`**: delete from **`LekmapPangaeaFractalv5.3.lua`** (and **`Create` / self** if mirrored) once branches are gone. |
| **Commented `EvaluateCandidatePlot` steering** | Map-center / salt **`finalScore`** blocks (~`L3134`, ~`L3413`): delete **if** you no longer want Lane A **history** in-file; otherwise leave commented until tuning is fully in **`OK()`** only. |
| **Spec / map script comments** | Remove stale “until solver lands” lines after cleanup; set **`_lek_global_six_solver = true`** by default when ready. |

---

## Still TBD (on implementation only)

- None for hook A (see **v0.11** revision log).

---

## Revision log

| Date | Note |
|------|------|
| 2026-03-27 | Split from start-balance; folding + open questions. |
| 2026-03-27 | v0.1–v0.2: pointer table, random ring, **400** tries, full ripples, bias clarity. |
| 2026-03-27 | **v0.3 authoritative:** **R/δ** locked, **inland salt** **d≤3 / max4** canonical, **`GAMEOPTION`**, **Lane A** + comment-not-delete, **`MixedBias` parity**, **forest** = region class only unless extended, interim virtual-six **non-contract**, **`finalScore`** optional tie-break only. |
| 2026-03-27 | **v0.4:** **§1** centre band **`9 ≤ d ≤ 18`** (**`>8`/`<19`**); **ideal `d = 13`** for tie-break; dropped **{12,13,14}**; merged old **`dCenter ≤ 18`** into this band. |
| 2026-03-27 | **v0.5:** **Variation A** locked for **`BalanceAndAssign`**; tie-break **`min maxᵢ\|d−13\|`** then **`min Σ\|d−13\|`**; search/regen = **first-version target**; **map hook** options table; **`file:line` TBD** on implement. |
| 2026-03-27 | **v0.6:** Hook **A** chosen; **`d₂`** = **`PlotDistance`**; coastal predicate for §3 aligned with **`4a`**; **six-cycle** intuition; B&A order clarified; tie-break after **`min max|d−13|`** = **`Map.Rand`**; forest = **no extra OK**. |
| 2026-03-30 | **v0.7:** **Order of operations** (GenerateRegions → `startingPlots[r]` → **`BalanceAndAssign`**); inland/coastal = **same as `4a`**; forest / XML = **vanilla B&A** + **`regionTypes[r]`** scoring. |
| 2026-03-30 | **v0.8:** **FAQ table** — **civ/player bias** only in **`BalanceAndAssign`**; step 1 = **`regionTypes[r]`** only. |
| 2026-03-30 | **v0.9:** **Plain language cheat sheet** after intro; light plain phrasing in strategy/scope. |
| 2026-03-31 | **v0.10:** **Pinned** — OK §5 feasibility via **shared** B&A predicate/matching core; **no** duplicate full B&A implementation (**§ Pinned — OK §5 feasibility**). |
| 2026-03-31 | **v0.11:** **Hook A** — **`LekGlobalSixChooseLocations`** stub **`4a_HBAssignStartingPlots.lua` ~4541** (`return false`); **`ChooseLocations`** hook **`self._lek_global_six_solver`** + **`GAMEOPTION_DISABLE_START_BIAS`** **~4571–4575**; **`findStarts`** **`LekGlobalSixChooseLocations`** **~146**. **§ Post-wiring cleanup** for ejecting virtual-six / flags after solver replaces patches. |
| 2026-03-31 | **Implementation note:** **`LekGlobalSix_OK_LogDiagnostics`** — legacy six-tuple vs **`OK` §1–§3** in log **`### LekGlobalSix_OK diag`** when **`_lek_global_six_solver=true`**; **`AssignStartingPlots.*(self)`** dispatch (methods not on **`findStarts`** except **`LogDiagnostics`**). §4–§6 + full **`OK()`** search still to do. |
