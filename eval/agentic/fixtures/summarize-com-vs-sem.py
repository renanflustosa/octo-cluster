#!/usr/bin/env python3
"""Summarize COM vs SEM bakeoff (2 arms, directional n=3). Never promotes a winner."""

from __future__ import annotations

import json
import math
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
RESULTS = ROOT / "eval" / "agentic" / "results"
CANDIDATES = [
    RESULTS / "bakeoff-com-vs-sem-n3-final.json",
    RESULTS / "bakeoff-com-vs-sem-n3-checkpoint.json",
]
ARMS = ["sem", "com"]
PRIMARY = "assistant_chars"


def mean(xs: list[float]) -> float:
    return sum(xs) / len(xs) if xs else float("nan")


def sd(xs: list[float]) -> float:
    if len(xs) < 2:
        return float("nan")
    m = mean(xs)
    return math.sqrt(sum((x - m) ** 2 for x in xs) / (len(xs) - 1))


def load() -> dict:
    for p in CANDIDATES:
        if p.is_file():
            data = json.loads(p.read_text(encoding="utf-8"))
            if "results" in data:
                return data
    print("No COM-vs-SEM results JSON found", file=sys.stderr)
    sys.exit(1)


def metric_rows(rows: list[dict], key: str) -> list[float]:
    out = []
    for r in rows:
        v = r.get(key)
        if v is None:
            continue
        out.append(float(v))
    return out


def main() -> int:
    data = load()
    rows = data["results"]
    by_arm: dict[str, list[dict]] = defaultdict(list)
    for r in rows:
        by_arm[r["arm"]].append(r)

    print("== COM vs SEM (directional; do NOT promote) ==")
    summary: dict = {}
    for arm in ARMS:
        arm_rows = by_arm.get(arm, [])
        chars = metric_rows(arm_rows, PRIMARY)
        passes = [1.0 if r.get("pass") else 0.0 for r in arm_rows]
        diffs = metric_rows(arm_rows, "diff_net")
        durs = metric_rows(arm_rows, "run_duration_ms")
        summary[arm] = {
            "n": len(arm_rows),
            "assistant_chars_mean": mean(chars) if chars else None,
            "assistant_chars_sd": sd(chars) if len(chars) > 1 else None,
            "pass_rate": mean(passes) if passes else None,
            "diff_net_mean": mean(diffs) if diffs else None,
            "run_duration_ms_mean": mean(durs) if durs else None,
        }
        print(
            f"  {arm:4} n={len(arm_rows)} "
            f"chars_mean={mean(chars) if chars else float('nan'):.1f} "
            f"chars_sd={sd(chars) if len(chars)>1 else float('nan'):.1f} "
            f"pass_rate={mean(passes) if passes else float('nan'):.2f} "
            f"|diff|_mean={mean([abs(x) for x in diffs]) if diffs else float('nan'):.2f}"
        )

    # paired delta com - sem by card
    sem_by = {r["card"]: r for r in by_arm.get("sem", [])}
    paired_chars = []
    paired_pass = []
    for r in by_arm.get("com", []):
        c = r.get("card")
        if c not in sem_by:
            continue
        s = sem_by[c]
        if r.get("assistant_chars") is not None and s.get("assistant_chars") is not None:
            paired_chars.append(float(r["assistant_chars"]) - float(s["assistant_chars"]))
        paired_pass.append((1 if r.get("pass") else 0) - (1 if s.get("pass") else 0))

    print("\n== Paired delta (com - sem) ==")
    print(
        f"  assistant_chars mean_delta={mean(paired_chars) if paired_chars else float('nan'):+.1f} "
        f"sd={sd(paired_chars) if len(paired_chars)>1 else float('nan'):.1f}"
    )
    print(f"  pass mean_delta={mean(paired_pass) if paired_pass else float('nan'):+.2f}")

    chars_sd = summary.get("sem", {}).get("assistant_chars_sd")
    com_sd = summary.get("com", {}).get("assistant_chars_sd")
    primary_sd_zero = (
        (chars_sd == 0 or chars_sd is None)
        and (com_sd == 0 or com_sd is None)
        and paired_chars
        and all(d == 0 for d in paired_chars)
    )

    verdict = "directional"
    if data.get("aborted") == "phase2_tie" or primary_sd_zero:
        verdict = "inconclusivo — sd=0 / empate no sinal primario; NAO promote"
    elif abs(mean(paired_chars)) < 1 if paired_chars else True:
        if paired_chars and all(d == 0 for d in paired_chars):
            verdict = "inconclusivo — Δ chars=0; NAO promote"

    print(f"\nVerdict: {verdict}")
    print("NOTE: n<30 — directional only; never write winner into platform.json.")

    out = {
        "summary": summary,
        "paired_com_minus_sem": {
            "assistant_chars": {
                "n": len(paired_chars),
                "mean_delta": mean(paired_chars) if paired_chars else None,
                "sd": sd(paired_chars) if len(paired_chars) > 1 else None,
            },
            "pass": {
                "n": len(paired_pass),
                "mean_delta": mean(paired_pass) if paired_pass else None,
            },
        },
        "verdict": verdict,
        "promote": False,
        "directional": True,
        "total_rows": len(rows),
    }
    out_path = RESULTS / "bakeoff-com-vs-sem-n3-summary.json"
    out_path.write_text(json.dumps(out, indent=2), encoding="utf-8")
    print(f"Wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
