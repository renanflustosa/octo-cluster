#!/usr/bin/env python3
"""Summarize AS-IS vs Octo-Full bakeoff. Primary: harness_score, tokens_total. Never promote."""

from __future__ import annotations

import argparse
import csv
import json
import math
import random
import sys
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
RESULTS = ROOT / "eval" / "agentic" / "results"
ARMS = ["asis", "full"]
BOOTSTRAP_N = 10_000


def mean(xs: list[float]) -> float:
    return sum(xs) / len(xs) if xs else float("nan")


def sd(xs: list[float]) -> float:
    if len(xs) < 2:
        return float("nan")
    m = mean(xs)
    return math.sqrt(sum((x - m) ** 2 for x in xs) / (len(xs) - 1))


def median(xs: list[float]) -> float:
    if not xs:
        return float("nan")
    s = sorted(xs)
    n = len(s)
    mid = n // 2
    if n % 2:
        return s[mid]
    return (s[mid - 1] + s[mid]) / 2


def ic95_t(xs: list[float]) -> tuple[float, float]:
    if not xs:
        return (float("nan"), float("nan"))
    m = mean(xs)
    s = sd(xs)
    if len(xs) < 2 or math.isnan(s):
        return (m, m)
    se = s / math.sqrt(len(xs))
    # t_{0.975, df=n-1} for small n
    t_crit = {1: 12.706, 2: 4.303, 3: 3.182, 4: 2.776, 5: 2.571, 6: 2.447}.get(len(xs) - 1, 1.96)
    return (m - t_crit * se, m + t_crit * se)


def bootstrap_ic95_paired(deltas: list[float], n_boot: int = BOOTSTRAP_N) -> tuple[float, float]:
    if not deltas:
        return (float("nan"), float("nan"))
    n = len(deltas)
    rng = random.Random(42)
    boots: list[float] = []
    for _ in range(n_boot):
        sample = [deltas[rng.randrange(n)] for _ in range(n)]
        boots.append(mean(sample))
    boots.sort()
    lo = boots[int(0.025 * n_boot)]
    hi = boots[int(0.975 * n_boot) - 1]
    return (lo, hi)


def cohens_d(deltas: list[float]) -> float | None:
    if len(deltas) < 2:
        return None
    s = sd(deltas)
    if math.isnan(s) or s == 0:
        return None
    return mean(deltas) / s


def wilcoxon_w(deltas: list[float]) -> dict:
    """Signed-rank W for n<=20; report W+ and direction only (no p-hacking)."""
    if not deltas:
        return {"w_plus": None, "n": 0, "direction": None}
    ranked: list[tuple[float, float]] = []
    for d in deltas:
        if d == 0:
            continue
        ranked.append((abs(d), d))
    if not ranked:
        return {"w_plus": 0, "n": 0, "direction": "all_zero"}
    ranked.sort(key=lambda x: x[0])
    w_plus = 0.0
    w_minus = 0.0
    i = 0
    while i < len(ranked):
        j = i
        while j < len(ranked) and ranked[j][0] == ranked[i][0]:
            j += 1
        tie_rank = (i + 1 + j) / 2.0
        for k in range(i, j):
            if ranked[k][1] > 0:
                w_plus += tie_rank
            else:
                w_minus += tie_rank
        i = j
    direction = "full_higher_tokens" if mean(deltas) > 0 else "full_lower_tokens"
    if mean(deltas) == 0:
        direction = "tie"
    return {
        "w_plus": w_plus,
        "w_minus": w_minus,
        "n_nonzero": len(ranked),
        "direction": direction,
    }


def mcnemar(pass_asis: list[bool], pass_full: list[bool]) -> dict:
    b = sum(1 for a, f in zip(pass_asis, pass_full) if a and not f)
    c = sum(1 for a, f in zip(pass_asis, pass_full) if not a and f)
    return {"asis_only": b, "full_only": c, "discordant": b + c}


def candidates_for(sample: str) -> list[Path]:
    return [
        RESULTS / f"bakeoff-asis-vs-full-{sample}-final.json",
        RESULTS / f"bakeoff-asis-vs-full-{sample}-checkpoint.json",
    ]


def load(sample: str) -> dict:
    for p in candidates_for(sample):
        if p.is_file():
            data = json.loads(p.read_text(encoding="utf-8"))
            if "results" in data:
                return data
    print(f"No ASIS-vs-FULL results JSON found for sample={sample}", file=sys.stderr)
    sys.exit(1)


def vals(rows: list[dict], key: str) -> list[float]:
    out = []
    for r in rows:
        v = r.get(key)
        if v is None:
            continue
        out.append(float(v))
    return out


def paired_deltas(by_arm: dict[str, list[dict]], key: str) -> tuple[list[float], list[dict]]:
    asis_by = {r["card"]: r for r in by_arm.get("asis", [])}
    deltas: list[float] = []
    per_card: list[dict] = []
    for r in by_arm.get("full", []):
        c = r.get("card")
        if c not in asis_by:
            continue
        a = asis_by[c]
        if r.get(key) is None or a.get(key) is None:
            continue
        d = float(r[key]) - float(a[key])
        deltas.append(d)
        per_card.append({"card": c, "delta": d, "asis": a.get(key), "full": r.get(key)})
    return deltas, per_card


def score_direction_ok(d: float) -> bool:
    return d > 0  # full better score


def token_direction_ok(d: float) -> bool:
    return d < 0  # full lower tokens


def cards_agreeing(per_card_score: list[dict], per_card_tok: list[dict]) -> int:
    tok_by = {p["card"]: p["delta"] for p in per_card_tok}
    agree = 0
    for p in per_card_score:
        c = p["card"]
        if c not in tok_by:
            continue
        if score_direction_ok(p["delta"]) and token_direction_ok(tok_by[c]):
            agree += 1
    return agree


def compute_verdict(
    paired_score: list[float],
    paired_tok: list[float],
    per_card_score: list[dict],
    per_card_tok: list[dict],
    missing_tokens: int,
    data: dict,
) -> str:
    if data.get("aborted"):
        return f"inconclusive:aborted:{data['aborted']}"
    if missing_tokens:
        return f"inconclusive:missing_tokens:{missing_tokens}"
    if not paired_score or not paired_tok:
        return "inconclusive:insufficient_pairs"

    score_lo, score_hi = bootstrap_ic95_paired(paired_score)
    tok_lo, tok_hi = bootstrap_ic95_paired(paired_tok)
    agree = cards_agreeing(per_card_score, per_card_tok)
    n_cards = len(per_card_score)

    score_ic_ok = score_lo > 0
    tok_ic_ok = tok_hi < 0
    score_mean_ok = mean(paired_score) > 0
    tok_mean_ok = mean(paired_tok) < 0

    discordant = n_cards - agree

    if score_ic_ok and tok_ic_ok and agree >= 4:
        return "moderate"
    if score_mean_ok and tok_mean_ok and (discordant <= 1) and (score_ic_ok or tok_ic_ok):
        return "weak_directional"
    if not score_ic_ok and not tok_ic_ok:
        return "inconclusive:ic_crosses_zero_both"
    if discordant >= 2:
        return "weak_directional:card_variance"
    return "weak_directional"


def metric_stats(deltas: list[float], per_card: list[dict]) -> dict:
    lo_b, hi_b = bootstrap_ic95_paired(deltas)
    lo_t, hi_t = ic95_t(deltas)
    return {
        "n": len(deltas),
        "mean_delta": mean(deltas) if deltas else None,
        "sd": sd(deltas) if len(deltas) > 1 else None,
        "median_delta": median(deltas) if deltas else None,
        "cohens_d": cohens_d(deltas),
        "ic95_bootstrap": [lo_b, hi_b] if deltas else None,
        "ic95_t": [lo_t, hi_t] if deltas else None,
        "per_card": per_card,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sample", default="n5", choices=["n3", "n5"])
    parser.add_argument("--csv", action="store_true", help="Export per-card CSV")
    args = parser.parse_args()

    data = load(args.sample)
    rows = data["results"]
    by_arm: dict[str, list[dict]] = defaultdict(list)
    for r in rows:
        by_arm[r["arm"]].append(r)

    print(f"== AS-IS vs Octo-Full sample={args.sample} (primary: harness_score, tokens_total) ==")
    print(f"{'arm':4} {'n':>2}  {'score_mean':>10} {'score_sd':>8}  {'tok_mean':>10} {'tok_sd':>8}  pass")
    summary: dict = {}
    for arm in ARMS:
        arm_rows = by_arm.get(arm, [])
        scores = vals(arm_rows, "harness_score")
        toks = vals(arm_rows, "tokens_total")
        passes = [1.0 if r.get("pass") else 0.0 for r in arm_rows]
        summary[arm] = {
            "n": len(arm_rows),
            "harness_score_mean": mean(scores) if scores else None,
            "harness_score_sd": sd(scores) if len(scores) > 1 else None,
            "tokens_total_mean": mean(toks) if toks else None,
            "tokens_total_sd": sd(toks) if len(toks) > 1 else None,
            "tokens_input_mean": mean(vals(arm_rows, "tokens_input")) if arm_rows else None,
            "tokens_output_mean": mean(vals(arm_rows, "tokens_output")) if arm_rows else None,
            "tokens_cache_read_mean": mean(vals(arm_rows, "tokens_cache_read")) if arm_rows else None,
            "pass_rate": mean(passes) if passes else None,
            "tokens_missing": sum(1 for r in arm_rows if r.get("tokens_total") is None),
        }
        print(
            f"  {arm:4} {len(arm_rows):2}  "
            f"{mean(scores) if scores else float('nan'):10.1f} "
            f"{sd(scores) if len(scores)>1 else float('nan'):8.1f}  "
            f"{mean(toks) if toks else float('nan'):10.1f} "
            f"{sd(toks) if len(toks)>1 else float('nan'):8.1f}  "
            f"{mean(passes) if passes else float('nan'):.2f}"
        )

    paired_score, per_card_score = paired_deltas(by_arm, "harness_score")
    paired_tok, per_card_tok = paired_deltas(by_arm, "tokens_total")

    stats_score = metric_stats(paired_score, per_card_score)
    stats_tok = metric_stats(paired_tok, per_card_tok)
    stats_tok["wilcoxon"] = wilcoxon_w(paired_tok)

    cards = sorted({r["card"] for r in rows if r.get("card")})
    pass_asis = [bool(asis_by.get(c, {}).get("pass")) for c in cards for asis_by in [{r["card"]: r for r in by_arm.get("asis", [])}]][0:1]
    asis_map = {r["card"]: r for r in by_arm.get("asis", [])}
    full_map = {r["card"]: r for r in by_arm.get("full", [])}
    pass_asis_list = [bool(asis_map.get(c, {}).get("pass")) for c in cards]
    pass_full_list = [bool(full_map.get(c, {}).get("pass")) for c in cards]

    missing = sum(s.get("tokens_missing", 0) for s in summary.values())
    verdict = compute_verdict(paired_score, paired_tok, per_card_score, per_card_tok, missing, data)
    agree = cards_agreeing(per_card_score, per_card_tok)

    print("\n== Paired delta (full - asis) ==")
    if stats_score["mean_delta"] is not None:
        lo, hi = stats_score["ic95_bootstrap"] or (float("nan"), float("nan"))
        print(
            f"  harness_score mean_delta={stats_score['mean_delta']:+.1f} sd={stats_score['sd']:.1f} "
            f"d={stats_score['cohens_d']} IC95%_boot=[{lo:+.1f}, {hi:+.1f}]"
        )
    if stats_tok["mean_delta"] is not None:
        lo, hi = stats_tok["ic95_bootstrap"] or (float("nan"), float("nan"))
        print(
            f"  tokens_total  mean_delta={stats_tok['mean_delta']:+.1f} median={stats_tok['median_delta']:+.1f} "
            f"sd={stats_tok['sd']:.1f} d={stats_tok['cohens_d']} IC95%_boot=[{lo:+.1f}, {hi:+.1f}]"
        )
        print(f"  wilcoxon: {stats_tok['wilcoxon']}")

    print("\n== Per-card paired ==")
    tok_by = {p["card"]: p for p in per_card_tok}
    for p in per_card_score:
        c = p["card"]
        t = tok_by.get(c, {})
        print(
            f"  {c}: d_score={p['delta']:+.0f} d_tokens={t.get('delta', float('nan')):+.0f} "
            f"pass_asis={asis_map.get(c, {}).get('pass')} pass_full={full_map.get(c, {}).get('pass')}"
        )

    print(f"\nCards agreeing (score up, tokens down): {agree}/{len(per_card_score)}")
    print(f"Verdict: {verdict}")
    print("NOTE: n<30 - directional only; never write winner into platform.json.")

    out = {
        "sample": args.sample,
        "summary": summary,
        "paired_full_minus_asis": {
            "harness_score": stats_score,
            "tokens_total": stats_tok,
        },
        "statistics": {
            "cards_agreeing": agree,
            "cards_total": len(per_card_score),
            "mcnemar": mcnemar(pass_asis_list, pass_full_list),
            "verdict": verdict,
            "power_note": "n=5 paired: low power (~25-35% for d=0.8); not CLT-grade",
        },
        "verdict": verdict,
        "promote": False,
        "directional": True,
        "primary_metrics": ["harness_score", "tokens_total"],
        "total_rows": len(rows),
        "run_meta": {
            "model": data.get("model"),
            "run_date": data.get("run_date"),
            "order_mode": data.get("order_mode"),
            "pause_ms": data.get("pause_ms"),
        },
    }
    out_path = RESULTS / f"bakeoff-asis-vs-full-{args.sample}-summary.json"
    out_path.write_text(json.dumps(out, indent=2), encoding="utf-8")
    print(f"Wrote {out_path}")

    if args.csv:
        csv_path = RESULTS / f"bakeoff-asis-vs-full-{args.sample}.csv"
        with csv_path.open("w", newline="", encoding="utf-8") as f:
            w = csv.DictWriter(
                f,
                fieldnames=[
                    "card",
                    "arm",
                    "pass",
                    "harness_score",
                    "tokens_total",
                    "tokens_input",
                    "tokens_output",
                    "tokens_cache_read",
                    "assistant_chars",
                    "run_duration_ms",
                    "diff_net",
                ],
            )
            w.writeheader()
            for r in sorted(rows, key=lambda x: (x.get("card", ""), x.get("arm", ""))):
                w.writerow({k: r.get(k) for k in w.fieldnames})
        print(f"Wrote {csv_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
