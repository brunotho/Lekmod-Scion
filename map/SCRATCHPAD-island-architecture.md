# Island architecture (Compact + Equator Ring)

Living plan. **No behavior change until coastal-bonus tuning + ring re-enable of PangaeaIslands.**  
Goal: one placement engine, per-shape placers unchanged, per-variant **policy** owns draft/menu/budget/sites.

---

## Current stack (today)

| Layer | Files | Role |
|--------|--------|------|
| Placers | `XX_island_{common,uncommon,rare}_*.lua` | `TryPlace*` — paint geometry |
| Helpers | `X_IslandHelpers.lua` | hex neigh, shared draw utils |
| Orchestrator | `3_PangaeaIslands.lua` | pools + odds + budget + draft + `runOnce` + `GeneratePangaeaIslands` |
| Pipeline hook | `Lekmap_PangaeaPipeline.lua` | call / skip / minIslands / outer regen |
| Coastal bonus | `4a` `PlaceCoastalBonusIslands` | guaranteed near-capital shore isles (separate channel) |
| Inland spray | `RoundInlandSeas` in pipeline | islands *inside* inland seas (not ocean draft) |

**Pain:** draft menus, budgets, and site assumptions (EW oceans, polar basins, wrap landbridges) are hardcoded for compact blob. Ring has less usable water and different coasts → wrong shapes / fail rates if we just un-skip.

---

## Target layout

```
X_IslandHelpers.lua              -- keep
XX_island_*.lua                  -- keep (placers only)

Lekmap_IslandEngine.lua          -- extract from 3_PangaeaIslands:
                                 --   draft loop, try spots, budget, runOnce,
                                 --   snapshot/restore, GenerateIslands(self, policy)

Lekmap_IslandCatalog.lua         -- optional thin registry:
                                 --   type → TryPlace + default pullBack/budget/tags
                                 --   (or keep defaults on XX_* exports later)

Lekmap_Islands_FractalPangaea.lua -- policy: pools, odds, TOTAL_BUDGET≈8,
                                 --   siteHints = ew_ocean + polar_ok
                                 --   channels.pangaeaDraft = true

Lekmap_Islands_EquatorRing.lua   -- policy: smaller budget, allowlist,
                                 --   siteHints = polar_basins_only,
                                 --   deny wrapSoftLandbridge / polarMerge? / EdgeOfWorld
                                 --   channels.pangaeaDraft = true (when re-enabled)

3_PangaeaIslands.lua             -- shrink to: include engine + Compact policy
                                 --   GeneratePangaeaIslands → GenerateIslands(self, CompactPolicy)
                                 --   OR delete after pipeline calls engine directly
```

Pipeline stays dumb:

```lua
local policy = (ring and RingIslands_GetPolicy() or CompactIslands_GetPolicy())
GenerateIslands(self, policy, islandGenOpts)
```

---

## Policy object (contract)

```lua
{
  id = "equator_ring",           -- log tag
  totalBudget = 4,               -- ring: less water
  budgetFloor = 2,
  maxRunOnceNominal = 2,
  budgetRetry = false,           -- ring: prefer outer redraw? tune later
  minPlaced = nil,               -- or map from lobby opt 16

  -- Draft menus (odds may be 0 to disable without deleting placer)
  common = { { type="dot", odds=5, pullBack=1, effMin=0, effMax=0, budget=0.09 }, ... },
  uncommon = { ... },
  rare = { ... },

  specialPhaseTypes = { geothermalIsland=true, ... },  -- place before fill
  namedPriority = { ... },

  -- Site / water inventory (engine filters candidates)
  site = {
    basins = "polar",            -- "any_ocean" | "polar" | "ew_gaps"
    forbidTouchOpenOceanRows = 3,-- match ring hard edge reserve if needed
    maxIslLandInRing = 4,        -- optional cap vs mainland
  },

  -- Capability deny (even if in pool)
  denyTags = { "needs_ew_ocean_gap", "needs_polar_merge", "wrap_landbridge" },

  channels = {
    pangaeaDraft = true,
    coastalBonus = true,         -- PlaceCoastalBonusIslands still in 4a for now
    inlandSeaSpray = true,       -- RoundInlandSeas spray; not engine
  },
}
```

Placer **tags** (add gradually on XX_* or catalog only):

| Tag | Meaning | Compact | Ring |
|-----|---------|---------|------|
| `shore_close` | pullBack/eff near mainland | yes | yes (polar shores) |
| `needs_deep_ocean` | far from land | yes | polar only |
| `needs_ew_ocean_gap` | east–west open water | yes | **no** |
| `needs_polar_merge` | polar arm / merge | yes | maybe later / rare |
| `wrap_landbridge` | soft landbridge across wrap | yes | **no** (ring already wraps land) |
| `nw_forced` | sets NW plot globals | yes | yes if wanted |

---

## First-pass ring allowlist (when re-enabling draft)

**Likely keep (shore / small):**  
`dot`, `pebble`, `strip`, `splinteredCliffsTiny`, `chunk`, `barbell`, `snake`, `wishbone`, `lollipop`, `clusterOfTiny`, `splinteredCliffs`, `mountainWall`, `drownedRidge`, `twinBay`, `shatteredRing`, `crescent`, `volcanicRing`, `junglePeak`, `sinaiIsland`, `solomonsMinesIsland` (odds 0 today), `geothermalIsland`

**Likely deny or odds=0 on ring:**  
`wrapSoftLandbridge`, `polarMerge` (EW-extent anchors meaningless on full-X belt; arms cluster at wrap), `steppingStone` (maybe keep with polar basins later), `EdgeOfWorld`, `EllipseArchipelago`, `fjordPeninsula`, `WaterRift` (deep far rings)

**Future placer (from polarMerge, not the embrace):**  
`XX_island_rare_ShoreSineChain.lua` — **done (ring v0):** EW shore-parallel sine spine + islet gaps (not polar fingers). Once/map; ring rare odds high for A/B.

Tune odds/budget after coastal-bonus A/B — don’t freeze this list yet.

---

## Channels (don’t merge yet)

1. **Pangaea draft** — `GenerateIslands` + policy (this refactor)  
2. **Coastal bonus** — keep in `4a` until draft is stable; later policy flag only  
3. **Inland-sea spray** — stays with `RoundInlandSeas` / ring seed  

Engine should not own (2)(3) in v1.

---

## Migration steps (ordered, each shippable)

1. **Doc only** — this file (now).  
2. **Extract engine no behavior change** — move `GeneratePangaeaIslands` body → `Lekmap_IslandEngine.lua`; Compact policy = current pools/constants; pipeline still calls `GeneratePangaeaIslands`.  
3. **Add Ring policy file** — still `skipIslands` or `policy.channels.pangaeaDraft=false` until ready.  
4. **Wire ring draft** — enable channel; lower budget; allowlist; polar site filter.  
5. **Catalog/tags** — optional cleanup; deny by tag instead of commented includes.  
6. **Coastal bonus** — policy-driven stub vs real (drop ring override hack).

---

## Pipeline touchpoints

- `GeneratePlotTypes` outer pass: `GeneratePangaeaIslands` / skip  
- Lobby opt 16 → `minIslands` / budgetRetry  
- `StartPlotSystem`: `PlaceCoastalBonusIslands`  
- Flow log stages: `islands_*`, later `islands_policy=equator_ring budget=…`

---

## Non-goals (for now)

- Merging all XX_* into one file  
- Full generator clone per variant  
- Rewriting placer math  
- Island org blocking inland-seed / coastal-bonus tuning  

---

## Status

| Item | State |
|------|--------|
| Architecture decision | **policy + shared engine** (confirmed) |
| Coastal bonus on ring | on (tuning); stays in `4a` |
| Inland-sea spray | stays in `RoundInlandSeas` / ring seed |
| Pangaea draft on ring | **on** — v0 allowlist, `totalBudget=4`, polar basins; `polarMerge` denied |
| Engine extract | **done** — `Lekmap_IslandEngine.lua` |
| Fractal Pangaea policy | `Lekmap_Islands_FractalPangaea.lua` |
| Ring policy | `Lekmap_Islands_EquatorRing.lua` |
| Catalog | `Lekmap_IslandCatalog.lua` |
| Loader | `3_PangaeaIslands.lua` (includes only) |
