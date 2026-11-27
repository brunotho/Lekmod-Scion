# Claude handoff — 2026-09-30 (dev work after release 6.0.5)

## Renamed 2026-10-18: Lekmap Scion (was Lekmap Rosebranch from 2026-10-17)
- User decision: the mod is now **Lekmod Scion**, the map **Lekmap Scion**, both numbered from **1.0.0**
  (repos `brunotho/Lekmod-Scion`, `brunotho/lekmap-scion`; the Rosebranch v1.0.0 releases were re-published as Scion)
  (map 1.0.0 = 6.0.6 + the dev changes since). Lobby leaves: `LekmapScion_FractalPangaea.lua`,
  `LekmapScion_EquatorRing.lua` (were `LekmapPangaeaFractal.lua`, `Lekmap_EquatorRing.lua`).
- The mod's Multiplayer > New Game picks the map by the file name `LekmapScion_FractalPangaea.lua` only:
  keep that name. Bump the version in VERSION, README and the map name (`Name =` in the leaf) together.
- The map name is only `Lekmap Scion 1.0.0` (the lobby drop-down cut off longer names). Equator Ring is parked as
  `unused/LekmapScion_EquatorRing.lua.off` (not fleshed out; user 2026-10-17); its Lekmap_*_EquatorRing support files stay.
- 2026-10-17 on dev: fewer fish (`LEK_FISH_RING_FREQ = { 5.75, 11.5, 26 }`, the pre-6.0.5 total) and
  `LekRareResourceSpots` (15% of sugar/spices/deer move one tile to marsh / forest-jungle hill / open flat tundra;
  log `LekRareResourceSpots`). Not rolled in game yet.

- 2026-10-18 on dev: start ring 1 has no mountain that touches salt water (lakes don't count): such mountains become
  hills in `LekApplyStartRingsHillMountainPolicy` (after the 2-mountain cap; log `LekStartRingCoastMountain`). Not rolled yet.

- 2026-10-18 on dev: **hard spacing rules** for Geometric Balance (`LekSpacingRulesPass`, called in the force-geometry sampler):
  every capital's second-closest capital at most 15 tiles (`LEK_G6_S2_SECOND_NEAREST_MAX`), and at most 2 pairs exactly at the
  minimum distance (Start Distance option; 11 for two ocean capitals) with no capital in both. Before this the sampler only
  *minimized* the worst second-nearest and accepted anything (the s2 numbers of the relaxation phases were never applied in
  force-geometry mode; the 6 phases only re-run the 1000-sample draw). Now: 6 phases x 1000 samples per map; no passing set =
  map regeneration (`_lek_global_six_regen_max_layouts = 8`, `tuple_regen_on_solver_fail = true` in the pipeline); the 8th map
  takes the best failed set (log `LekSpacingRules rules_failed accepted_best`). Logs `LekSpacingRules no_passing_set` per failed map.
  Rolled by the user 2026-10-18 without visible problems. Logs (and the "starts" channel) switched off again for release 1.0.0.

- **Release 1.0.0 published 2026-10-18**: GitHub release `v1.0.0` on `brunotho/lekmap-scion` (re-published as Scion, target `b15d0c5`, zip
  built by the mod repo's `tools/release.py package`). `dev` pushed. The mod website reads this repo's `CHANGELOG.txt` from `dev`.
## Where things stand
- **Latest release: Lekmap Scion 1.0.0** (tag `v1.0.0`, commit `b15d0c5`, on `dev`; `main` still holds 6.0.6).
  Release values: logs off, `LEK_CENTRAL_VOLCANO_CHANCE = 5`. Untested in game at release: fewer fish, rare resource
  spots, ring-1 coastal mountains to hills (the user found the maps "alright").
- Before new test work on `dev`, turn the logs back on (see "Resuming test work"), and off again before a release.
- 6.0.6 (2026-10-01, old repo name brunotho/lekmap) was verified over ~16 rolls; `LekNWResourceSweep cleared=0`.
- Branches `mapgen-tuning` and `origin/release/v5.3-testing` were deleted (v5.3 snapshot commit: `27c6a13`).
- Lua.log shows `Lekmap v6.2\LekmapTeamerMapLegacy.lua:672` errors: another Lekmap copy the user keeps on purpose
  for something else. Ignore it; do not delete it.

## On dev, not released (2026-10-10)
- **Strategic deposit sizes come from Lekmod** (`Resources.AmountMajor/AmountMinor`): `GetMajor/SmallStrategicResourceQuantityValues`
  read them via `AssignStartingPlots.LekStrategicAmounts` (fallback: the old hardcoded values; resource settings keep their old
  offsets, min 1). Lekmod v3 standard: iron 9/3, horse 6/2, coal 18/4, oil 18/8, aluminum 24/12, uranium 6/2. Start
  normalization small horse/iron (was a hardcoded 2) uses the small amounts too. Log line `LekStrategicAmounts`.

## Shipped in 6.0.6 (all verified in logs over the user's test rolls)
- **Inland seas count for start distance rules**: `AssignStartingPlots.LekBuildCoastTables` (called from `__Init`
  and after the center clear) marks land 1-2 from inland-sea water "next to coast" and 3 away "three from coast";
  inland seas still are not a coast for coastal starts. Majors stay 4+ from them, city states not at 1-2.
  Log `LekInlandSeaStartRing`. Fractal only (Equator Ring has no curated inland seas).
- **Tiny cliffs noise** (`XX_island_common_SplinteredCliffsTiny.lua`): 60% of rows push 1 (35%: 2) stacks one tile
  further out (two water tiles); the first stack keeps the one-tile anchor (`OUTER_PCT`, `OUTER_TWO_PCT`).
- **No resources on natural wonders**: NW tile blocked in all resource impact layers; `LekPlotIsNaturalWonder`
  check in `ProcessResourceList` / `PlaceSpecificNumberOfResources` / `PlaceSmallQuantitiesOfStrategics`;
  `AttemptToPlaceNaturalWonder` skips candidate tiles that already hold a resource (start balancing places
  strategics before wonders; island NW spots clear the resource instead); final sweep log `LekNWResourceSweep
  cleared=N` should be 0 (last fix untested in-game — check the next rolls).
- **Coastal start center clear** (Fractal only): `LekClearCoastalStartsTowardCenter` (pipeline, after
  ChooseLocations, before BalanceAndAssign) turns salt water (ocean + inland sea, not lakes) and mountains in the
  center-facing half of rings 1-2 (3 + 6 tiles, `LekCenterFacingRingTiles`) of coastal majors into flat/hills with
  neighbour terrain. Placement rejects coastal candidates whose only ocean contact faces the center
  (`LekCoastalCandidateSurvivesCenterClear`, inside `LekGlobalSix_CoastalCandidatePassesSaltWaterDiskPct`), so the
  post-check revert never fires. Log `LekCoastalCenterClear starts/tiles/reverted` (seen: 1-3 tiles per map, reverted 0).
- **Luxury diversity** (`PlaceLuxuries`; regionals and start luxuries untouched): a city state's type may be shared by
  at most 1 of its 5 nearest city states, checked both ways (re-roll; fallback if nothing fits); log
  `LekCSLuxDiversity rejects/fallback`. A random luxury may not go where 2+ of the 6 nearest luxuries are its type —
  another eligible random type with copies left is swapped in, else the tile is skipped (`placeRandomLuxDiverse`);
  log `LekLuxDiversity randomRejects/swaps`. Seen: 0-3 rejects, fallback 0, random totals unchanged.
- **Amber** is cluster-only: never regional / city state / start or capital luxury (site allow-list,
  `LekRandomLuxNoAmber`, CS pool, `LekStripLuxuryResourcesNearStart` keeps it). When rolled as a random type,
  `LekPlaceAmberClusters` places 1-3 locations (8+ apart) on land within 3 of salt water, each 1/2/3 ambers
  (50/35/15) within 2 tiles, 75% trees (jungle |lat|<0.3 on grass/plains, else forest). Constants `LEK_AMBER_*`;
  log `LekAmber locations/tiles`.

## Resuming test work
1. Work on `dev` (`git checkout dev`); commit locally, push only when the user asks. This folder is the game's live copy, so the checked-out branch is what loads.
2. Set `_lek_mapgen_logs = true` in `LekmapScion_FractalPangaea.lua` and `LekmapScion_EquatorRing.lua`.
3. To look at the central volcano, temporarily raise `LEK_CENTRAL_VOLCANO_CHANCE` (release value 5).
4. User tests by rolling Small maps with default settings (mostly Fractal Pangaea) and reports tile coordinates.
   Answer from `Logs/LekmapIslandMap.log` (always the map currently open; check its timestamp — a release build
   writes no logs). Lookup: `grep "xy=X,Y "`.
5. Before a release: flip the values back, bump VERSION / README / both map names, add `Changelog_vX`.

## Watch list (from the 6.0.5 round)
- **Luxury crowding**: `LekmapLandStats.log` has `### LekLuxSummary randomTarget/randomWanted/randomPlaced/typesShort`
  per map. Sea regionals now sit on the mainland coast 4-6 from the capital (2+1 split between both coast
  directions, spacing radius 1, none within 3 of the capital). If random luxuries come up short, lower
  regional spacing further or loosen the placement band.
- **Flat ridge bending** (`### LekFlatRidges runs/bent/shortened`) also runs on Equator Ring; the user has not
  judged it there yet — may need to be skipped on the ring's long east-west chains.
- A very large unexplained island was seen once at 3/22 on a release map (no logs). Best guess: wrap soft
  land bridge (x=3 is next to the wrap seam). User said a one-off is fine.
- Rework candidates: `wrapSoftLandbridge` (can look like rubble on the seam), 2026-10-18 seen at 43 tiles (main piece 25, 6 on the mainland) around 0/12; user: leave it for now, `splinteredCliffs` (thin snake).
  Unbuilt idea: no islands in narrow straits (except connectors).

## Island system in one paragraph
Engine `Lekmap_IslandEngine.lua`, per-map policies `Lekmap_Islands_FractalPangaea.lua` / `_EquatorRing.lua`,
placers `XX_island_*.lua` (catalog `Lekmap_IslandCatalog.lua`, includes in `3_PangaeaIslands.lua`; commented-out
includes are parked ideas). Rules: every island keeps exactly one water tile to the mainland
(`maxMainlandGap = 2`; `mainlandGapByType` lets splinteredCliffs / shatteredRing / volcanicRing sit one further
out; hotspotTrail exempt), 2 water tiles between islands (`islandGap`), only polarMerge and wrapSoftLandbridge
may touch the mainland (they still keep `islandGap`). Crescent odds 0. Coastal bonus islands (4a,
`PlaceCoastalBonusIslands`) and shore specks follow the one-tile rule too. Central volcano: pipeline
`LekPaintCentralVolcano` (blocks the engine's JunglePeak; Geothermal skips Krakatoa if the volcano has it).
Details: `SCRATCHPAD-island-architecture.md`.

## How to verify changes
- No Lua in the shell by default: `pip install lupa`, compile-check each changed file with `lupa.lua51`
  `loadstring`. Civ5 map scripts have no `_G` — set `_G = nil` in any harness.
- **Island engine harness**: `python scripts/island_engine_harness.py [seeds] [type]` runs the whole engine on
  a synthetic pangaea and prints the per-type water gap to the mainland plus ASCII samples of `type`.
- 4a (start placement / resources) cannot be run offline. New `AssignStartingPlots:Foo` methods must be called as
  `AssignStartingPlots.Foo(self, …)` (or be plain globals); `PlaceLuxuries_OLD` duplicates much of
  `PlaceLuxuries` — edit the live one.
- Errors inside pcall'd stages are silent in-game: check `LekmapPipelineFlow.log` (`*_error`) and Lua.log
  (`PlaceResources_err`, `Runtime Error`).

## Docs kept in the repo
- `LEKMAP-DEBUG-MANUAL.txt` — log switches and log strings.
- `LEKMAP-STRATEGIC-RESOURCE-TUNING-SPEC.txt` — horse/iron requirements (code: LekStratAudit).
- `SCRATCHPAD-island-architecture.md` — island engine / policy design.
- `SCRATCHPAD-equator-ring-followups.md`, `SCRATCHPAD-equator-ring-placement.md` — ring notes and ring-native
  placer plan.
- `SCRATCHPAD-placement-spec-v0.md` (referenced from 4a comments), `SCRATCHPAD-placement-mission-spec.md` —
  global-six (Geometric Balance) start placement contract and phase plan.
- `scripts/lekmap_log_digest.py` (log batch digest), `scripts/island_engine_harness.py`.
Older placement scratchpads, the April tuple handoff, the strategic tuning batch comparison, `legacy/` and two
never-included island placers (CoastalHorn, CrescentAndStar) were removed 2026-09-27 (git history has them).
