# Equator Ring — player placement plan (replace Legacy)

Living draft. Fractal Pangaea keeps Geometric Balance / Legacy UI. Ring currently forces Legacy + brick 3×2 regions; this doc is the intended ring-native placer.

---

## Gameplay intent (from Fractal Pangaea, in plain words)

What you care about on Fractal is not “pretty hexes” — it’s **fair contested geography**:

1. **Six majors always get a real game** — placement finishes; no silent dead loads / infinite regen.
2. **Spacing is gameplay** — capitals far enough that early contact is interesting, not a knife-fight or a lonely island. Pairwise floor + “second nearest” shape matter more than raw fertility.
3. **Coastal quota is sacred** — if the lobby asks for coastal civs / Force-2, that count is hard (**H**). Don’t soft-cheat inland because the solver got stuck.
4. **Biases are real, then soft** — river / avoid / priority should try hard first; only then legacy-like slack (**S → L**). Don’t pretend XML bias means nothing.
5. **Geometry before fertility theater** — Global Six / force-geom was about **annulus / packing / cycle**, not “richest tile wins.” Fertility is a tie-break inside a fair cell, not the cut.
6. **One map, relax ladder** — spend complexity on the current landmask (G0→G3) before burning a new fractal roll (G4).

Ring inherits that philosophy. The landmass is different, so the **machinery** changes; the **goals** don’t.

---

## What the ring already fixes (don’t throw away)

| Piece | Role |
|-------|------|
| **Brick 3×2** (6 civs) | Topology: three wrap cells × north/south rows. Each civ owns a cell — like Forced fair partitions without fertility chops. |
| **Polar-merge excl from brick Y** | Scenic arms don’t steal region extent. |
| **Coastal Spawns option** | Still live UI → still drives **H**. |
| **Soft pairwise** | Narrow W made compact G6 `error()` fatal; soft-proceed was triage, not the end state. |

Legacy `ChooseLocations` inside bricks = fertility/coast scoring with HB ripples. That **ignores wrap social graph** and doesn’t own a ring min-distance story.

---

## Target: ring-native placer (not blob Global Six)

**Do not** port force-geometry annulus as-is (blob-centered). Build a **brick-aware** placer:

```
GenerateRegions → ApplyBrickRegions (keep)
       ↓
RingChooseLocations (new) — pick 1 capital per brick
       ↓
BalanceAndAssign (keep bias assign; soft gates ring-aware)
       ↓
Ring spacing assert (harsh H, ring-calibrated)
```

### Constraints (same tiers as Fractal)

| Tier | Ring meaning |
|------|----------------|
| **H** | Coastal count from option 17 + coastal predicate. Prefer N/S shore of the belt; inland-sea coast optional later. |
| **G** | Per-brick pick + **wrap-aware** pairwise min distance; prefer “not all stacked on same latitude band”; second-nearest / neighbor-brick targets. |
| **S/L** | Bias tags after geometry: try coastal/river/priority inside the assigned brick first; soft fall back inside brick, then (rare) swap bricks. |

### Geometry sketch (v0)

1. **One start per brick** (identity: region index = brick).
2. Candidate pool = land in brick AABB ∩ biggest area, exclude snow / polar edge / island-reserved plots (same filters as today).
3. Score inside brick: coastal if needed, food/prod rings (reuse EvaluateCandidatePlot or slimmed), mild preference for brick interior vs wrap seam if seam is crowded.
4. **Global pass:** after six picks, check wrap PlotDistance matrix:
   - `minPair ≥ H_ring` (calibrate on Small W≈38; likely **lower** than compact’s 9 — measure from `player_distances_summary`).
   - Optional: boost H for coastal–coastal pairs.
5. Fail → repair: nudge within brick → swap two bricks’ candidates → only then layout regen.

### What we explicitly won’t do first

- Full Global Six DFS tuple on the ring.
- Fertility-based region *cuts* (bricks stay geometry-first).
- Fatal `error()` out of B&A on spacing (log + repair/regen instead).

---

## Implementation phases

| Phase | Deliverable | Done when |
|-------|-------------|-----------|
| **P0** | Hide Starting Locations UI; force Legacy (this commit) | Lobby clean |
| **P1** | Ring spacing assert after starts: log `ring_spacing_ok/fail` with H; soft or regen flag | Measurable distances |
| **P2** | `RingChooseLocations`: one pick/brick, reuse coastal pools | Starts feel “in cell” |
| **P3** | Wrap min-distance repair loop inside one layout | Fewer knife-fight maps |
| **P4** | Wire Coastal Spawns **H** into ring picker (Force-2 / all inland) | Matches lobby |
| **P5** | Bias soft ladder inside bricks; optional brick swaps | XML biases feel real |
| **P6** | Turn off snow debug paint; document H table per world size | Soft deploy |

---

## Calibration notes

- Current logs: `player_distances_summary` often minPair ≈ 13 on Soft Legacy — use that as **baseline**, then decide harsh H (e.g. floor 10–12 on Small) without recreating the old “d≥9 impossible → dead load” bug.
- Brick stagger (north offset) already helps wrap neighbors; placer should **prefer** starts that use that stagger, not fight it.

---

## Open questions (decide together)

1. Is **one capital per brick** inviolable, or may two civs share a brick if spacing repair needs it? (Recommend: inviolable.)
2. Should Force-2 coastals be **one N + one S** shore preference, or any two salt coasts?
3. Do city-states keep HB placement, or later a ring CS ring-along-belt pass?
4. When is layout regen allowed vs soft-proceed for multiplayer reliability?

---

## Status

| Item | State |
|------|--------|
| Starting Locations UI on ring | **hidden** (Legacy forced in pipeline) |
| Brick regions | live |
| Ring-native ChooseLocations | **not started** |
| Harsh min-distance | TODO (followups §A) |
