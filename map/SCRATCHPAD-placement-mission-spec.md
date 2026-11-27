# Lekmap placement — mission spec (single-map spine)

**Status:** execution SSOT after workspace reset. Deep inventories live in older scratchpads; **implement in the phase order below**, not scatter-shot.

**Archived context:** the older placement scratchpads (unified spec, hard coastal quota, tuple roadmap, master plan, placement glossary) were removed 2026-09-27; see git history before commit of that date.

---

## 1. North star

1. **Always finish one map** for the player-selected pace: after terrain/islands exist, **placement must terminate** with six major starts and downstream steps reachable (no “tuple said OK then hard assert regens layout forever” unless explicitly a **rare structural** case).
2. **Spend complexity on one fractal instance first:** a clear **relaxation ladder** on a **fixed** `GeneratePlotTypes` outcome before escalating to **layout regen** (new core roll).
3. **Tighten quality only after (1) is cheap and predictable:** geometry, coastal quota, bias strictness — measurable, logged tiers.

**Non-goals for the first execution pass:** island seed heuristics (BFS buckets), nuclear luxury repair, aggressive `runOnce` clock tuning, per-layout phase matrix expansion — unless they directly unblock (1).

---

## 2. Frozen pipeline (do not reorder casually)

1. Terrain / plot types (incl. Pangaea outer loop **inside** one layout attempt).
2. `GenerateRegions` → six regions, types, rectangles.
3. `ChooseLocations` — tuple **or** legacy — sets `startingPlots[1…6]` (region → plot).
4. `BalanceAndAssign` — assigns players ↔ those plots (legacy machine).
5. Resources / CS / asserts.

**Invariant:** tuple runs **before** B&A; tuple “virtual §5” is a **preview**, not a full B&A replay.

---

## 3. Constraint tiers (single vocabulary)

Use one table everywhere in code comments and logs.

| Tier | Scope | Rule |
|------|--------|------|
| **H** | Coastal | `N_coastal` from `BuildPlayerBiasPlist` + coastal predicate (salt/lake per options). Never softened for solver convenience. Impossible → documented failure path (see §6). |
| **S** | Non-coastal biases | Strict injective / predicates in **early** ladder steps (river, prim, avoid, pri1, flex per product). |
| **L** | Non-coastal biases | **Legacy-like** slack when **S** is infeasible on this map: same *intent* as legacy B&A, not a line-by-line copy. |
| **G** | Geometry | §1 band, §2 second-nearest, first-nearest cap, min pairwise (opt 6 mapped to plot distance), §4 cycle rule when applicable. Relaxed **only** by explicit ladder step or phase row — **not** by silently skipping post-assign checks. |

**Known past bug to fix (P0 bias):** Medium must **not** use a global “coastal soft” flag that makes `N_coastal` satisfiable in tuple but violated after B&A — see archived coastal spec §3.

---

## 4. Single-map spine (relaxation ladder)

**Goal:** For **one** successful `GeneratePlotTypes` / layout attempt, try steps **in order** before `requestRegen` / next layout.

| Step | Name | Behavior |
|------|------|----------|
| G0 | **Strict tuple** | Current strict phases: **H + S + tight G** in tuple OK checks. |
| G1 | **Loosen geometry only** | Phase table relaxes **G** (wider §1/§2, optional first-nearest off in later row). **H unchanged.** |
| G2 | **Legacy-soft non-coastal** | `biasMode = legacySoft` for **L** only; **H** still enforced in §5 predicate / feasibility. |
| G3 | **Legacy `ChooseLocations`** | Skip tuple for this layout attempt; run HB legacy start selection. Still run post-placement asserts that match product — or mark final tier in log if menu allows soft landing. |
| G4 | **Layout regen** | New fractal/layout only after G0–G3 exhausted **or** true impossibility (e.g. `N_coastal` > coastal-capable regions). |

**Critical alignment rule:** Tuple acceptance at any step must **not** contradict asserts that still run on player plots (min pairwise, Force-2 coast count, etc.). Either:

- **A)** Tuple OK includes the same checks as those asserts, or  
- **B)** Asserts are **skipped only on a documented final tier** (e.g. G3) and logs show `finalTier=legacy_skip_assert_X`.

Past failure mode: escape phases used **`skip_min_pairwise` / `proof_ok_soft`** in tuple OK but **post-tuple** still enforced opt-6 distance → **layout regen after expensive DFS**. That is **forbidden** unless (B) is explicit.

### 4.1 Implementation map (code today — **E1**)

| Step | Where | Status |
|------|--------|--------|
| **G0 / G1** | `4a_HBAssignStartingPlots.lua`: `LekGlobalSix_RunTupleSearch` + `LekGlobalSix_DefaultTupleRelaxationPhases` (and per-phase `s1_*` / `s2_*`) | Geometry relaxes across phase rows; no separate logged **`biasMode` / G2** tier yet. |
| **G2** (*spec*) | legacy-soft non-coastal biases | **Not** a distinct switch in code yet → **E4**. |
| **G3** | **(a)** Map opt 13 Legacy → `_lek_global_six_skip_tuple_use_legacy`, tuple skipped (`placement_tier=legacy_menu_skip_tuple`). **(b)** Global six + tuple `solver_return=false` → `ChooseLocations` falls through to HB legacy (`placement_tier=legacy_after_tuple_fail`). | Both land here without layout regen from tuple alone. |
| **G4** | `_lek_global_six_request_map_regen` set in `4a` (tuple fail **only if** `_lek_global_six_tuple_regen_on_solver_fail` and HB regen loop) and in **`LekmapPangaeaFractalv5.3.lua`** StartPlotSystem (e.g. post-`PlaceResources` regional lux shortfall gate, other asserts). | Live logs: **`LEK REGIONAL LUX POST-FALLBACK SHORTFALL GATE`** is G4 independent of tuple. |

**Parked (idea):** §1 “distance to ideal ring” could be softened when **§2 / pairwise** neighborhoods are already strong — more shape flexibility; not implemented.

---

## 5. §4 (two-coastal cycle) vs variable `N_coastal`

`LekGlobalSix_OK_Section4_TwoCoastalGeoCycle` encodes a **geometric** “two coastal on angle cycle” story tied to **Force 2 coastals** and plist. When implementing **H**, audit §4 vs option-derived **`N_coastal`** (0/1/2/…) so tuple §4, §5, and legacy asserts never disagree.

---

## 6. Failure and geometry mode (option 13)

UI is **two values:** **Legacy** (tuple skipped) and **Global six** (tuple ladder then legacy if no tuple). Tuple-fail **does not** request layout regen unless `_lek_global_six_tuple_regen_on_solver_fail` is enabled in the map script (default off).

- **Truly impossible H:** fail fast at feasibility (log `nCoastalRequired` vs `regionsCoastalCapable`) — do not burn DFS.

---

## 7. Execution checklist (do in order)

| # | Task | Done when |
|---|------|-----------|
| **E1** | Map **G0→G4** to existing flags / hooks (`ChooseLocations` early return, `requestRegen`, tuple skip). Document which step runs today vs missing. | Short table in code comment or this doc §4 **Implementation map**. |
| **E2** | **Assert/tuple alignment:** tuple `proof_ok_soft` / `skip_min_pairwise` **either** re-add min-pair + §4 (and any other post-tuple asserts) in `LekGlobalSix_OK_RunAll` **or** gate asserts on tier — no silent mismatch. | **Progress:** `_lek_global_six_placement_tier` on `ChooseLocations` / `LekGlobalSixChooseLocations`; tuple leaves use full `LekGlobalSix_OK_RunAll` (no soft OK path today). If `tuple_ok` but `LekAssertGlobalSixPlayerMinPairwiseOrRegen` fails → `### E2 tuple_OK_vs_player_minPairwise_MISMATCH` at v1 + `placement_tier` on min-pair line. Further: gate other post-steps on tier if new soft phases appear. |
| **E3** | **P0 coastal:** `N_coastal` helper; feasibility coastal block; remove Medium-only coastal-soft that drops quota; optional log `nCoastalRequired=`. | **Progress:** `iNumCoastNeeded` for ExactTwo clamped to `cap` (already `min(max(nat,cap),cap)`); `FindCoastalStart` fallbacks use **NoCoast** `FindStart` when ExactTwo so fallback cannot add a 3rd salt start; last layout **no longer errors** on Force-2 mismatch — logs `LEK FORCE2 COAST exhausted_no_regen` and proceeds (north star). |
| **E4** | **P1 `biasMode`:** log `biasMode=strict|legacySoft` per phase; switch **S→L** for non-coastal only when appeasability says so. | Phase begin lines show mode; Medium ≡ Slow on **H**. |
| **E5** | **P2 fail-fast** (optional): order cheap **G** checks in legacySoft when logs show s2-dominated waste. | Wall time down on bad maps without wrong accepts. |
| **E6** | **P4 perf:** tuple DFS snapshot/undo, pool cache; Pangaea/island caps — **after** E2–E4 stable. | Same correctness, lower `dt_startPlotSystem` / outers. |

---

## 8. Telemetry (minimum)

- One compact **chooseStarts outcome** line per attempt (existing `g6|…` or equivalent).
- On failure: `first_fail` / `biasMode` / **ladder step G0–G4** (once instrumented).
- Pangaea: keep ability to see **which** clause failed outer pass (land / islands / budget / water-slice) — reuse existing probe pattern if present after reset.

---

## 9. Parked (do not implement until spine green)

- Guided ocean ring buckets, `islS` seed stats, aggressive island clocks.
- Regional luxury “nuclear” repair and target-count tweaks.
- Expanding **per-layout** phase tables (L4/L5 matrices) before **E2** is stable.

---

## 10. Revision log

| Date | |
|------|--|
| 2026-04-05 | Initial mission spec: north star single-map + ladder G0–G4, tier table H/S/L/G, execution E1–E6, parked list; consolidates prior scratchpads into actionable order. |
| 2026-04-05 | **E1** §4.1 implementation map; note lux-shortfall G4 vs tuple; parked §1-vs-§2 flexibility note. |
| 2026-04-05 | **E2 (partial):** `placement_tier` telemetry + explicit **E2** log if tuple-accepted layout fails player min-pairwise after B&A. |
| 2026-04-05 | **E3 (partial):** Force-2 legacy — `FindCoastalStart` inland fallback; no **error** on exhausted regen (`exhausted_no_regen` probe). |
