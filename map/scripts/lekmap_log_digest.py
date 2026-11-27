#!/usr/bin/env python3
"""Aggregate LekmapStartSpacing6P.log across many map gens. Rolls = each GenerateMap_lua_entry block."""

from __future__ import annotations

import argparse
import collections
import os.path
import re
import sys
from typing import Dict, List, Tuple


def default_log_path() -> str:
    home = os.path.expanduser("~")
    if sys.platform == "win32":
        base = os.path.join(home, "Documents", "My Games")
    else:
        base = os.path.join(home, "Library", "Application Support")
    return os.path.join(
        base,
        "Sid Meier's Civilization 5",
        "Logs",
        "LekmapStartSpacing6P.log",
    )


def split_rolls(lines: List[str]) -> List[List[str]]:
    blocks: List[List[str]] = []
    cur: List[str] = []
    for line in lines:
        if "### LekMapGen GenerateMap_lua_entry" in line and cur:
            blocks.append(cur)
            cur = [line]
        else:
            cur.append(line)
    if cur:
        blocks.append(cur)
    return blocks


def inc(d: Dict[str, int], k: str, n: int = 1) -> None:
    d[k] = d.get(k, 0) + n


def first_match(pat: re.Pattern, block: List[str]) -> re.Match | None:
    for line in block:
        m = pat.search(line)
        if m:
            return m
    return None


RE_TUPLE_SEARCH = re.compile(r"### LekGlobalSix tupleSearch runId=\S+ status=(\S+)")
RE_MAP_LAYOUT_ATTEMPT = re.compile(r"map_layout_attempt=(\d+)")
RE_SOLVER = re.compile(
    r"### LekGlobalSixChooseLocations runId=\S+.*?solver_return=(\w+)"
)
RE_BIAS = re.compile(
    r"### LekGlobalSix tupleBiasFeasibility runId=\S+ .*?decision=(\S+) reason=(\S+)"
)
RE_BIAS_SKIP_DETAIL = re.compile(r"detail=(\S+)")
RE_PHASE_END = re.compile(
    r"### LekGlobalSix tuplePhase end runId=\S+ .*?status=(\S+)(?: .*?last_fail=(\S+))?"
)
RE_LAST_FAIL = re.compile(r"last_fail=(\S+)")
RE_OK_DIAG = re.compile(r"### LekGlobalSix_OK diag runId=\S+ .*?first_fail=(\S+)")
RE_REGEN = re.compile(r"### LekGlobalSix mapRegen request runId=\S+ .*?reason=(\S+)")
RE_MIN_ELIG = re.compile(r"minEligRegionsAmongPlayers=(\d+)")
RE_LAYOUT_RESULT = re.compile(r"### LekGlobalSix mapRegen layout_result .*?outcome=(\S+)")
RE_REGEN_SUMMARY = re.compile(
    r"### LekGlobalSix mapRegen summary total_layouts_tried=(\d+) final_outcome=(\S+)"
)
RE_ISLAND_RUNONCE_TOTAL = re.compile(r"runOnce_total_dt=([0-9.+-eE]+)")
RE_ISLAND_GEN_TOTAL = re.compile(r"generatePangaeaIslands_total_dt=([0-9.+-eE]+)")
RE_PANGAEA_ISLANDS_SEG = re.compile(r"generatePangaeaIslands_dt=([0-9.+-eE]+)")
RE_ISLANDS_OK0 = re.compile(r"islandsOk=0")
RE_TUPLE_FAIL_COMBO = re.compile(
    r"### LekGlobalSix tupleFailCombo runId=\S+ phaseIndex=(\d+) name=(\S+) "
    r"failComplete=(\d+) leafEvals=(\d+) comboHist_top=(.*?)\s+anyHist=(.+)"
)
RE_COASTAL_SALT_DISK = re.compile(
    r"### LekGlobalSix coastalSaltDiskPoolDiag runId=\S+ phase=(\S+) .*?"
    r"rejected_from_pool_by_disk=(\d+) .*?poolCells_total=(\d+)"
)
RE_TUPLE_RELAX_GATE = re.compile(
    r"### LekGlobalSix tupleRelaxGate hard_only runId=\S+ map_layout_attempt=(\d+) "
    r"relax_min_layout=(\d+)"
)
RE_TUPLE_PHASES_FOR_LAYOUT = re.compile(
    r"### LekGlobalSix tuplePhasesForLayout runId=\S+ map_layout_attempt=(\d+) "
    r"slice=(\S+) phaseNames=(.+?)\s+nPhases=(\d+)"
)
RE_G6_CAUSE = re.compile(
    r"### g6\|cause runId=\S+ status=(\S+) gate=(\S+) prune=(\S+) leaf=(\S+) combo=(\S+) why=(\S+)(?: relax_phase=(\S+))?"
)


def _parse_kv_counts(blob: str) -> Dict[str, int]:
    """Parse 'k:n,k2:n2' from fmtAnyHist / fmtComboHistTop (keys have no commas)."""
    out: Dict[str, int] = {}
    if not blob or blob == "na":
        return out
    blob = blob.strip()
    trunc = blob.find(",…(+")
    if trunc != -1:
        blob = blob[:trunc]
    for part in blob.split(","):
        part = part.strip()
        if not part or ":" not in part:
            continue
        k, _, rs = part.rpartition(":")
        k = k.strip()
        try:
            out[k] = out.get(k, 0) + int(rs)
        except ValueError:
            continue
    return out


def digest_block(block: List[str]) -> dict:
    r: dict = {
        "tuple_search": None,
        "solver_return": None,
        "bias_decisions": [],
        "phase_end_status": [],
        "phase_last_fail": [],
        "ok_first_fail": None,
        "regen_reasons": [],
        "min_elig_min": None,
        "tuple_fail_combo": [],
        "coastal_salt_lines": [],
        "tuple_relax_gate_hard_only": False,
        "tuple_phases_for_layout": None,
        "tuple_search_layout": None,
        "g6_cause": None,
    }
    for line in block:
        if "### LekGlobalSix tupleSearch" not in line:
            continue
        mt = RE_TUPLE_SEARCH.search(line)
        if mt:
            r["tuple_search"] = mt.group(1)
        ml = RE_MAP_LAYOUT_ATTEMPT.search(line)
        if ml:
            r["tuple_search_layout"] = int(ml.group(1))
    m = first_match(RE_SOLVER, block)
    if m:
        r["solver_return"] = m.group(1)
    for line in block:
        mb = RE_BIAS.search(line)
        if mb:
            item = {"decision": mb.group(1), "reason": mb.group(2)}
            md = RE_BIAS_SKIP_DETAIL.search(line)
            if md:
                item["detail"] = md.group(1)
            r["bias_decisions"].append(item)
        mo = RE_OK_DIAG.search(line)
        if mo:
            r["ok_first_fail"] = mo.group(1)
        mr = RE_REGEN.search(line)
        if mr:
            r["regen_reasons"].append(mr.group(1))
        me = RE_MIN_ELIG.search(line)
        if me:
            v = int(me.group(1))
            if r["min_elig_min"] is None or v < r["min_elig_min"]:
                r["min_elig_min"] = v
    for line in block:
        mc = RE_TUPLE_FAIL_COMBO.search(line)
        if mc:
            r["tuple_fail_combo"].append(
                {
                    "phase_index": int(mc.group(1)),
                    "phase_name": mc.group(2),
                    "fail_complete": int(mc.group(3)),
                    "leaf_evals": int(mc.group(4)),
                    "combo_top": _parse_kv_counts(mc.group(5)),
                    "any_hist": _parse_kv_counts(mc.group(6)),
                }
            )
        msalt = RE_COASTAL_SALT_DISK.search(line)
        if msalt:
            r["coastal_salt_lines"].append(
                {
                    "phase": msalt.group(1),
                    "rejected": int(msalt.group(2)),
                    "pool_total": int(msalt.group(3)),
                }
            )
        if RE_TUPLE_RELAX_GATE.search(line):
            r["tuple_relax_gate_hard_only"] = True
        mpl = RE_TUPLE_PHASES_FOR_LAYOUT.search(line)
        if mpl:
            r["tuple_phases_for_layout"] = {
                "map_layout_attempt": int(mpl.group(1)),
                "slice": mpl.group(2),
                "phase_names": mpl.group(3).strip(),
                "n_phases": int(mpl.group(4)),
            }
        mg6 = RE_G6_CAUSE.search(line)
        if mg6:
            r["g6_cause"] = {
                "status": mg6.group(1),
                "gate": mg6.group(2),
                "prune": mg6.group(3),
                "leaf": mg6.group(4),
                "combo": mg6.group(5),
                "why": mg6.group(6),
                "relax_phase": mg6.group(7) or "",
            }
    for line in block:
        if "### LekGlobalSix tuplePhase end" in line:
            mp = RE_PHASE_END.search(line)
            if mp:
                r["phase_end_status"].append(mp.group(1))
                lf = mp.group(2)
                if not lf:
                    mlf = RE_LAST_FAIL.search(line)
                    lf = mlf.group(1) if mlf else ""
                if lf and lf != "na":
                    r["phase_last_fail"].append(lf)
    return r


def roll_summary(block: List[str], d: dict) -> str:
    bias_lines = len(d["bias_decisions"])
    bias_any_skip = any(x.get("decision") == "skip_impossible" for x in d["bias_decisions"])
    bias_any_go = any(x.get("decision") == "proceed_dfs" for x in d["bias_decisions"])
    if bias_lines == 0:
        bg = "biasLog=absent"
    elif bias_any_skip and not bias_any_go:
        bg = "bias=all_skip"
    elif bias_any_go:
        bg = "bias=had_proceed_dfs"
    else:
        bg = "bias=mixed"
    ts = d["tuple_search"] or "no_tupleSearch_line"
    sr = d["solver_return"] or "?"
    tpf = d.get("tuple_phases_for_layout")
    lay = ""
    if tpf:
        lay = f" laySlice={tpf['slice']} nPh={tpf['n_phases']}"
    gc = d.get("g6_cause")
    if gc:
        cause = (
            f" cause(status={gc['status']},gate={gc['gate']},prune={gc['prune']},"
            f"leaf={gc['leaf']},why={gc['why']})"
        )
    else:
        cause = " cause=absent"
    return f"tuple={ts} solver={sr} {bg}{lay}{cause}"


def scan_mapgen_timing(lines: List[str]) -> dict:
    """Island / Pangaea probe lines (whole file; not tied to ChooseLocations filter)."""
    r: dict = {
        "island_runOnce_lines": 0,
        "island_runOnce_dt_max": None,
        "island_full_dt_max": None,
        "island_exit_budget_exhaust": 0,
        "island_exit_budget_met": 0,
        "island_exit_no_retry": 0,
        "pangaea_gen_islands_dt_max": None,
        "pangaea_islands_ok0": 0,
    }
    for ln in lines:
        if "### LekIslandProbe" in ln:
            if "runOnce_total_dt=" in ln:
                r["island_runOnce_lines"] += 1
                m = RE_ISLAND_RUNONCE_TOTAL.search(ln)
                if m:
                    v = float(m.group(1))
                    if r["island_runOnce_dt_max"] is None or v > r["island_runOnce_dt_max"]:
                        r["island_runOnce_dt_max"] = v
            if "exit=budget_retry_exhausted" in ln:
                r["island_exit_budget_exhaust"] += 1
            if "exit=budget_met" in ln:
                r["island_exit_budget_met"] += 1
            if "exit=no_budget_retry" in ln:
                r["island_exit_no_retry"] += 1
            mtot = RE_ISLAND_GEN_TOTAL.search(ln)
            if mtot:
                v = float(mtot.group(1))
                if r["island_full_dt_max"] is None or v > r["island_full_dt_max"]:
                    r["island_full_dt_max"] = v
        if "### LekPangaeaPlotTypesProbe" in ln and "generatePangaeaIslands_dt=" in ln:
            m = RE_PANGAEA_ISLANDS_SEG.search(ln)
            if m:
                v = float(m.group(1))
                if (
                    r["pangaea_gen_islands_dt_max"] is None
                    or v > r["pangaea_gen_islands_dt_max"]
                ):
                    r["pangaea_gen_islands_dt_max"] = v
            if RE_ISLANDS_OK0.search(ln):
                r["pangaea_islands_ok0"] += 1
    return r


def main() -> int:
    ap = argparse.ArgumentParser(description="Digest Lekmap placement logs across map gens.")
    ap.add_argument("logfile", nargs="?", default=None, help="Path to LekmapStartSpacing6P.log")
    ap.add_argument(
        "--per-roll",
        action="store_true",
        help="Print one summary line per roll (tupleSearch + solver + bias logging era).",
    )
    ap.add_argument(
        "--full",
        action="store_true",
        help="Print extended histograms (ok_first_fail, phase last_fail, minElig, etc.). "
        "Default is a focused digest for current tuple / salt-disk / regen tuning.",
    )
    args = ap.parse_args()
    path = args.logfile or default_log_path()
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
    except OSError as e:
        print(e, file=sys.stderr)
        return 1

    raw_lines = [ln.rstrip("\n") for ln in lines]
    mg = scan_mapgen_timing(raw_lines)
    layout_outcome_hist: Dict[str, int] = {}
    for ln in raw_lines:
        mlr = RE_LAYOUT_RESULT.search(ln)
        if mlr:
            inc(layout_outcome_hist, mlr.group(1))
    summary_lines: List[Tuple[str, str]] = []
    for ln in raw_lines:
        ms = RE_REGEN_SUMMARY.search(ln)
        if ms:
            summary_lines.append((ms.group(1), ms.group(2)))

    rolls = split_rolls(raw_lines)
    tuple_status: Dict[str, int] = {}
    solver_status: Dict[str, int] = {}
    bias_decision: Dict[str, int] = {}
    bias_reason: Dict[str, int] = {}
    phase_status: Dict[str, int] = {}
    last_fail: Dict[str, int] = {}
    ok_first: Dict[str, int] = {}
    regen_reason: Dict[str, int] = {}
    min_elig_hist: Dict[str, int] = collections.Counter()
    cause_status: Dict[str, int] = {}
    cause_gate: Dict[str, int] = {}
    cause_prune: Dict[str, int] = {}
    cause_leaf: Dict[str, int] = {}
    cause_why: Dict[str, int] = {}
    cause_combo: Dict[str, int] = {}
    rolls_with_tuple = 0
    tuple_relax_hard_only_rolls = 0
    tuple_ok_with_layout = 0
    tuple_ok_layout_le3 = 0
    coastal_salt_file_lines = 0
    coastal_reject_max = 0
    coastal_reject_sum = 0
    combo_fail_agg: Dict[str, int] = {}
    any_fail_agg: Dict[str, int] = {}

    roll_summaries: List[str] = []

    for block in rolls:
        if not any("ChooseLocations begin" in L for L in block):
            continue
        rolls_with_tuple += 1
        d = digest_block(block)
        if d["tuple_relax_gate_hard_only"]:
            tuple_relax_hard_only_rolls += 1
        for salt in d["coastal_salt_lines"]:
            coastal_salt_file_lines += 1
            coastal_reject_sum += salt["rejected"]
            if salt["rejected"] > coastal_reject_max:
                coastal_reject_max = salt["rejected"]
        for tfc in d["tuple_fail_combo"]:
            for k, v in tfc["combo_top"].items():
                inc(combo_fail_agg, k, v)
            for k, v in tfc["any_hist"].items():
                inc(any_fail_agg, k, v)
        if args.per_roll:
            roll_summaries.append(roll_summary(block, d))
        if d["tuple_search"]:
            inc(tuple_status, d["tuple_search"])
        ts = d.get("tuple_search")
        lay = d.get("tuple_search_layout")
        if ts in ("ok", "ok_minimal_s2_plus1") and lay is not None:
            tuple_ok_with_layout += 1
            if lay <= 3:
                tuple_ok_layout_le3 += 1
        if d["solver_return"]:
            inc(solver_status, d["solver_return"])
        gc = d.get("g6_cause")
        if gc:
            inc(cause_status, gc["status"])
            inc(cause_gate, gc["gate"])
            inc(cause_prune, gc["prune"])
            inc(cause_leaf, gc["leaf"])
            inc(cause_why, gc["why"])
            inc(cause_combo, gc["combo"])
        for b in d["bias_decisions"]:
            inc(bias_decision, b["decision"])
            inc(bias_reason, b["reason"])
        for ps in d["phase_end_status"]:
            inc(phase_status, ps)
        for lf in d["phase_last_fail"]:
            inc(last_fail, lf)
        if d["ok_first_fail"]:
            inc(ok_first, d["ok_first_fail"])
        for rr in d["regen_reasons"]:
            inc(regen_reason, rr)
        if d["min_elig_min"] is not None:
            min_elig_hist[str(d["min_elig_min"])] += 1

    def dump(title: str, d: Dict[str, int]) -> None:
        if not d:
            return
        print(title)
        for k, v in sorted(d.items(), key=lambda kv: (-kv[1], kv[0])):
            print(f"  {k}: {v}")

    def dump_top(title: str, d: Dict[str, int], limit: int = 12) -> None:
        if not d:
            return
        print(title)
        for k, v in sorted(d.items(), key=lambda kv: (-kv[1], kv[0]))[:limit]:
            print(f"  {k}: {v}")

    print(f"file: {path}")
    print(
        "scopes: tuple/solver/combo/salt/relax_gate = only lines inside mapgen blocks that contain "
        '"ChooseLocations begin" (one block per ### LekMapGen GenerateMap_lua_entry … next entry); '
        "island timing + mapRegen layout_result = entire file."
    )
    print(f"rolls (ChooseLocations blocks): {rolls_with_tuple}")
    print(
        f"tupleRelaxGate hard_only rolls: {tuple_relax_hard_only_rolls} "
        f"(layout 1..relax_min-1 strict phases only)"
    )
    print(
        "tupleSearch ok / ok_minimal with map_layout_attempt field: "
        f"ok_on_layout<=3={tuple_ok_layout_le3} "
        f"ok_with_any_layout_tagged={tuple_ok_with_layout} "
        "(needs map_layout_attempt on tupleSearch lines in this log)"
    )
    print("island / pangaea timing (whole file)")
    print(
        f"  LekIslandProbe runOnce lines={mg['island_runOnce_lines']} "
        f"max_runOnce_total_dt={mg['island_runOnce_dt_max']}"
    )
    print(
        f"  LekIslandProbe max_generatePangaeaIslands_total_dt={mg['island_full_dt_max']} "
        f"exit: exhaust={mg['island_exit_budget_exhaust']} met={mg['island_exit_budget_met']} "
        f"no_retry={mg['island_exit_no_retry']}"
    )
    print(
        f"  LekPangaeaPlotTypesProbe max_generatePangaeaIslands_dt={mg['pangaea_gen_islands_dt_max']} "
        f"lines_with_islandsOk=0={mg['pangaea_islands_ok0']}"
    )
    if coastal_salt_file_lines:
        print(
            "coastalSaltDiskPoolDiag (verbosity≥2, lines this file): "
            f"n_lines={coastal_salt_file_lines} sum_rejected_disk={coastal_reject_sum} "
            f"max_rejected_single_phase={coastal_reject_max}"
        )
    else:
        print("coastalSaltDiskPoolDiag: no lines (need log level ≥2 or feature off)")

    dump_top(
        "tupleFailCombo comboHist_top (sum of leaf-fail counts; multiple phases per roll)",
        combo_fail_agg,
        16,
    )
    if args.full:
        dump_top("tupleFailCombo anyHist (aggregated)", any_fail_agg, 16)

    dump("tupleSearch status", tuple_status)
    dump("solver_return", solver_status)
    dump("g6|cause status", cause_status)
    dump("g6|cause gate", cause_gate)
    dump("g6|cause prune", cause_prune)
    dump("g6|cause leaf", cause_leaf)
    dump("g6|cause why", cause_why)
    if args.full:
        dump("g6|cause combo", cause_combo)
    bias_skip = bias_decision.get("skip_impossible", 0)
    bias_go = bias_decision.get("proceed_dfs", 0)
    print(
        f"tupleBiasFeasibility log lines (not rolls; up to ~4 phases × rolls): "
        f"proceed_dfs={bias_go} skip_impossible={bias_skip} "
        f"(histograms: --full)"
    )
    dump("mapRegen layout_result outcome (every layout attempt line in file)", layout_outcome_hist)
    if summary_lines:
        print("mapRegen summary (last 5 in file)")
        for nt, fo in summary_lines[-5:]:
            print(f"  total_layouts_tried={nt} final_outcome={fo}")

    if args.full:
        if roll_summaries:
            print("per-roll:")
            for i, s in enumerate(roll_summaries, 1):
                print(f"  {i}: {s}")
        dump("tupleBiasFeasibility decision", bias_decision)
        dump("tupleBiasFeasibility reason", bias_reason)
        dump("tuplePhase end status", phase_status)
        dump("tuplePhase last_fail (when present)", last_fail)
        dump("LekGlobalSix_OK first_fail", ok_first)
        dump("mapRegen request reason", regen_reason)
        if min_elig_hist:
            print("minEligRegionsAmongPlayers (min over tupleBias lines per roll)")
            for k, v in sorted(min_elig_hist.items(), key=lambda kv: int(kv[0])):
                print(f"  {k}: {v}")
    elif roll_summaries:
        print("per-roll (tuple solver bias):")
        for i, s in enumerate(roll_summaries, 1):
            print(f"  {i}: {s}")

    if not args.full:
        print(
            "\nTip: ~25–40 full mapgens for coarse mix (tuple ok vs fail, dominant combo keys); "
            "~80–120 if you care about rare tails (<10% events). Use --full for bias reasons / phase_fail histograms."
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
