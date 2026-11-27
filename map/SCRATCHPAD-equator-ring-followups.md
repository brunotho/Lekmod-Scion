# Equator Ring — follow-ups / experiments

Living notes. Compact path unchanged unless stated. Ring uses Legacy starts for now (GB disabled).

Last context: Small canvas branched — Compact `44×52`, Ring `Width-12` → `32×52`. Brick 3×2 regions @ 6 civs. Snow region paint on for tuning.


## A. Placement — harsh min distance between players (TODO)

See **`SCRATCHPAD-equator-ring-placement.md`** for the full ring-native placer plan.
Legacy UI option removed; pipeline still forces Legacy until P2+.


## B. Ring landmask — N–S claim / chunky coasts (ACTIVE EXPERIMENT)

**In code now** (`Lekmap_Landmass_EquatorRing.lua`):
- `RING_HALF_THICK_FRAC = 0.26`
- Shore middle ground: `AMP=4`, `CHUNK_COLS=3`, `SMOOTH_BLEND=0.45` (between old per-col spikes and amp5/chunk5)
- `RING_POLE_REACH_PCT = 12` (was 18)
- Y-recenter off; pangaea + coastal bonus islands disabled on ring

So chaos is almost entirely **coastline amplitude**. Interior of the belt is deterministic land. On Small ring (`iH=52`): half ≈ 11 → total thick ≈ 22–23 rows (~42% of height) before wobble — narrow vs full canvas.

### Knobs (existing constants — try first)

| Knob | Now | Effect if raised / changed |
|------|-----|----------------------------|
| `RING_HALF_THICK_FRAC` | `0.21` | Primary “claim more N–S.” e.g. `0.28–0.35` fattens the mean band. |
| `RING_COAST_NOISE_AMP` | `3` | Bigger local shore jaggedness only; does **not** move the mean band much. |
| `RING_MIN_COL_THICK` | `8` | Floor per column; raising prevents skinny necks, fights chaos at thin spots. |
| `RING_POLAR_OCEAN_ROWS` | `2` | Lower (1 or 0) allows coasts closer to poles; higher reserves more polar ocean. |
| Canvas `Width` / `Height` | Ring `W-12` in `GetMapInitData` | Wider height gives more rows to spend on thickness; we already cut X. |

Fractal currently only nudges edges by ±1 via `continentsFrac` at `y=mid`. Grain `7` on InitFractal is coarse; still not a land/water mask inside the band.

### Knobs that would need new logic (not wired yet)

1. **Per-column thickness noise (low frequency)**  
   Vary `half` along X with smooth noise (or fractal) so some longitudes are fat toward poles and others stay thin — changes *which rows* are used, not just the shore line.

2. **Asymmetric N vs S half**  
   Independent `halfN` / `halfS` (or bias) so the belt isn’t mirrored about the equator.

3. **Interior mask (wild paint)**  
   Inside a *wider* soft band, set land only where fractal > threshold (or two octaves). Gives holes, peninsulas, and “claimed” polar fingers without a solid slab. Biggest lever for “chaotic on the NS axis.”

4. **Post-pass N/S fingers / bays**  
   After the solid belt, grow or carve along N/S with random walks / fractal ridges (compact-style tools, ring-gated).

5. **Relax ring seal**  
   Current seal forbids all-ocean columns in the equatorial band. Softening allows true gaps (strait-like) — more chaos, risk to wrap continuity / brick regions.

6. **Y-recenter**  
   Build still can apply a small Y shift from land centroid; a wilder mask may need to disable or soften recenter so polar claims aren’t pulled back to mid.

### Suggested experiment order (when we touch code)

1. Bump `RING_HALF_THICK_FRAC` alone — see if “narrow NS” complaint is mostly mean thickness.  
2. Raise `RING_COAST_NOISE_AMP` — confirm it only helps shore, not band usage.  
3. If still “stable band”: add **per-column half noise** and/or **interior fractal mask** inside a wider max band.  
4. Revisit land % / outer pass floor (`landFloorFrac` 0.40) and brick row split (Y half of land extent) after thickness changes.


## C. Other open ring items (parked)

- GB disabled on purpose; draft ring-native placer later (not blob force-geom).
- Brick regions are geometry-first; fertility only measured inside bricks — revisit if starts feel unfair inside a cell.
- Islands / coastal bonus islands / fjords: fjords off (`_lek_fjord_distance_setting_fixed = 1`); `PlaceCoastalBonusIslands` still shared; island odds may need ring retune later.
- Snow AABB paint is debug-only (`_lek_debug_paint_region_snow`); **off** for normal play.
- `polarMerge` **denied** on ring (EW min/max anchors wrong on full-X belt). Liked bit: sine-curved arm + splintered gaps → future dedicated placer (see island-architecture scratchpad).


## D. Ring pangaea-draft v0 (ACTIVE)

Policy: `Lekmap_Islands_EquatorRing.lua` — `totalBudget=4`, early dots=1, floor=2, `basins=polar`.
Shore/small + a few rares; no wrap / EW-gap / polarMerge. Roll and trim odds if polar basins feel cluttered vs capital shore isles.


## Pointers

- Landmask: `Lekmap_Landmass_EquatorRing.lua`
- Canvas branch: `GetMapInitData` in `Lekmap_PangaeaPipeline.lua` (`width - 12` if equator_ring)
- Brick regions: `LekLandmass_EquatorRing_ApplyBrickRegions` + `CustomOverride` in pipeline
- Flow log: `~/Library/Application Support/Sid Meier's Civilization 5/Logs/LekmapPipelineFlow.log`
