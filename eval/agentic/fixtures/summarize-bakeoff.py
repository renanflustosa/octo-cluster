#!/usr/bin/env python3
"""Summarize bakeoff results: mean/sd/IC95% per arm + paired delta vs baseline."""

from __future__ import annotations

import json
import math
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
RESULTS = ROOT / "eval" / "agentic" / "results"
CANDIDATES = [
    RESULTS / "bakeoff-n5-final.json",
    RESULTS / "bakeoff-n5-checkpoint.json",
    RESULTS / "bakeoff-n30-final.json",
    RESULTS / "bakeoff-n30-checkpoint.json",
]


def mean(xs: list[float]) -> float:
    return sum(xs) / len(xs) if xs else float("nan")


def sd(xs: list[float]) -> float:
    if len(xs) < 2:
        return float("nan")
    m = mean(xs)
    return math.sqrt(sum((x - m) ** 2 for x in xs) / (len(xs) - 1))


def ic95(xs: list[float]) -> tuple[float, float]:
    if not xs:
        return (float("nan"), float("nan"))
    m = mean(xs)
    s = sd(xs)
    if len(xs) < 2 or math.isnan(s):
        return (m, m)
    se = s / math.sqrt(len(xs))
    # normal approx z=1.96
    return (m - 1.96 * se, m + 1.96 * se)


def load() -> dict:
    for p in CANDIDATES:
        if p.is_file():
            data = json.loads(p.read_text(encoding="utf-8"))
            if "results" in data:
                return data
    print("No bakeoff results JSON found", file=sys.stderr)
    sys.exit(1)


def main() -> int:
    data = load()
    rows = data["results"]
    by_arm: dict[str, list[dict]] = defaultdict(list)
    for r in rows:
        if r.get("harness_score") is None:
            continue
        by_arm[r["arm"]].append(r)

    print("== Per-arm harness_score ==")
    summary = {}
    for arm in ["nada", "baseline", "compress-on", "octo-full"]:
        xs = [float(r["harness_score"]) for r in by_arm.get(arm, [])]
        lo, hi = ic95(xs)
        summary[arm] = {
            "n": len(xs),
            "mean": mean(xs) if xs else None,
            "sd": sd(xs) if len(xs) > 1 else None,
            "ic95": [lo, hi] if xs else None,
        }
        print(
            f"  {arm:12} n={len(xs):2} mean={mean(xs) if xs else float('nan'):.2f} "
            f"sd={sd(xs) if len(xs)>1 else float('nan'):.2f} "
            f"IC95=[{lo:.2f}, {hi:.2f}]"
        )

    # paired deltas vs baseline by card
    print("\n== Paired delta vs baseline (harness_score) ==")
    base = {r["card"]: float(r["harness_score"]) for r in by_arm.get("baseline", []) if r.get("card") and r.get("harness_score") is not None}
    paired_report = {}
    for arm in ["nada", "compress-on", "octo-full"]:
        diffs = []
        for r in by_arm.get(arm, []):
            c = r.get("card")
            if c in base and r.get("harness_score") is not None:
                diffs.append(float(r["harness_score"]) - base[c])
        lo, hi = ic95(diffs)
        paired_report[arm] = {
            "n": len(diffs),
            "mean_delta": mean(diffs) if diffs else None,
            "sd": sd(diffs) if len(diffs) > 1 else None,
            "ic95": [lo, hi] if diffs else None,
        }
        print(
            f"  {arm:12} n={len(diffs):2} mean_delta={mean(diffs) if diffs else float('nan'):+.2f} "
            f"IC95=[{lo:+.2f}, {hi:+.2f}]"
        )

    # winner: highest mean among arms with n>=1
    ranked = sorted(
        ((a, s["mean"], s["n"]) for a, s in summary.items() if s["mean"] is not None),
        key=lambda t: (t[1], t[2]),
        reverse=True,
    )
    winner = ranked[0][0] if ranked else None
    print(f"\nWinner (highest mean harness_score): {winner}")
    n_winner = summary.get(winner, {}).get("n", 0) if winner else 0
    if winner and n_winner < 30:
        print(f"NOTE: n={n_winner} per arm — directional (not CLT-grade); treat IC95 as rough.")

    out = {
        "summary": summary,
        "paired_vs_baseline": paired_report,
        "winner": winner,
        "total_rows": len(rows),
        "directional": n_winner < 30,
    }
    out_path = RESULTS / "bakeoff-n5-summary.json"
    out_path.write_text(json.dumps(out, indent=2), encoding="utf-8")
    print(f"Wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
