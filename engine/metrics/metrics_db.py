#!/usr/bin/env python3
"""SQLite metrics store for Octo Cluster kernel (stdlib only)."""

from __future__ import annotations

import argparse
import csv
import json
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path


def default_db_path() -> Path:
    root = Path(__file__).resolve().parents[2]
    return root / "state" / "metrics" / "metrics.db"


def schema_path() -> Path:
    return Path(__file__).resolve().parent / "schema.sql"


def connect(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    return conn


def init_db(db_path: Path) -> None:
    sql = schema_path().read_text(encoding="utf-8")
    with connect(db_path) as conn:
        conn.executescript(sql)
        conn.commit()


def insert_card(db_path: Path, row: dict) -> int:
    cols = [
        "recorded_at",
        "ticket",
        "arm",
        "repo",
        "tokens_input",
        "tokens_output",
        "tokens_cache_read",
        "tokens_total",
        "cost_usd",
        "usage_events",
        "usage_source",
        "diff_added",
        "diff_deleted",
        "diff_net",
        "files_changed",
        "gates_pass",
        "context_budget_alerts",
        "commands_lines",
        "skills_lines",
        "ship_verdict",
        "notes",
    ]
    values = [row.get(c) for c in cols]
    with connect(db_path) as conn:
        cur = conn.execute(
            f"INSERT INTO cards ({', '.join(cols)}) VALUES ({', '.join('?' * len(cols))})",
            values,
        )
        conn.commit()
        return int(cur.lastrowid)


def insert_harness(db_path: Path, row: dict) -> int:
    cols = [
        "recorded_at",
        "harness_score",
        "checks_ok",
        "checks_total",
        "commands_lines",
        "skills_lines",
        "audit_ok",
        "audit_warn",
        "details_json",
    ]
    values = [row.get(c) for c in cols]
    with connect(db_path) as conn:
        cur = conn.execute(
            f"INSERT INTO harness_snapshots ({', '.join(cols)}) VALUES ({', '.join('?' * len(cols))})",
            values,
        )
        conn.commit()
        return int(cur.lastrowid)


def migrate_csv(db_path: Path, workspace: Path) -> dict:
    init_db(db_path)
    log_dir = workspace / "state" / "logs" / "metrics-baseline"
    imported = {"cards": 0, "harness": 0}

    cards_csv = log_dir / "cards.csv"
    if cards_csv.is_file():
        with cards_csv.open(encoding="utf-8", newline="") as f:
            reader = csv.DictReader(f)
            for r in reader:
                insert_card(
                    db_path,
                    {
                        "recorded_at": r.get("recorded_at") or datetime.now(timezone.utc).isoformat(),
                        "ticket": r.get("ticket", "unknown"),
                        "arm": r.get("arm", "default"),
                        "repo": r.get("repo"),
                        "tokens_input": _int(r.get("tokens_input")),
                        "tokens_output": _int(r.get("tokens_output")),
                        "tokens_cache_read": _int(r.get("tokens_cache_read")),
                        "tokens_total": _int(r.get("tokens_total")),
                        "cost_usd": _float(r.get("cost_usd")),
                        "usage_events": _int(r.get("usage_events")),
                        "usage_source": r.get("usage_source", "proxy"),
                        "diff_added": _int(r.get("diff_added")),
                        "diff_deleted": _int(r.get("diff_deleted")),
                        "diff_net": _int(r.get("diff_net")),
                        "files_changed": _int(r.get("files_changed")),
                        "gates_pass": 1 if r.get("gates_pass") == "true" else 0,
                        "context_budget_alerts": _int(r.get("context_budget_alerts")),
                        "commands_lines": _int(r.get("commands_lines")),
                        "skills_lines": _int(r.get("skills_lines")),
                        "ship_verdict": r.get("ship_verdict"),
                        "notes": r.get("notes"),
                    },
                )
                imported["cards"] += 1

    harness_csv = log_dir / "harness-history.csv"
    if harness_csv.is_file():
        with harness_csv.open(encoding="utf-8", newline="") as f:
            reader = csv.DictReader(f)
            for r in reader:
                insert_harness(
                    db_path,
                    {
                        "recorded_at": f"{r.get('date', '1970-01-01')}T00:00:00Z",
                        "harness_score": _int(r.get("harness_score")),
                        "checks_ok": _int(r.get("checks_ok")),
                        "checks_total": _int(r.get("checks_total")),
                        "commands_lines": _int(r.get("commands_lines")),
                        "skills_lines": _int(r.get("skills_lines")),
                        "audit_ok": _int(r.get("audit_ok")),
                        "audit_warn": _int(r.get("audit_warn")),
                        "details_json": None,
                    },
                )
                imported["harness"] += 1

    return imported


def trends(db_path: Path, last: int = 10, arm: str | None = None) -> dict:
    init_db(db_path)
    with connect(db_path) as conn:
        arm_filter = " AND arm = ?" if arm and arm != "all" else ""
        params: list = [arm] if arm and arm != "all" else []
        params.append(last)

        cards = conn.execute(
            f"""
            SELECT ticket, arm, tokens_total, cost_usd, diff_added, diff_net, gates_pass, recorded_at
            FROM cards
            WHERE 1=1{arm_filter}
            ORDER BY id DESC LIMIT ?
            """,
            params,
        ).fetchall()

        by_arm = conn.execute(
            """
            SELECT arm, COUNT(*) AS n,
                   AVG(diff_added) AS avg_diff_added,
                   AVG(tokens_total) AS avg_tokens,
                   AVG(cost_usd) AS avg_cost
            FROM cards
            GROUP BY arm
            """
        ).fetchall()

        harness = conn.execute(
            """
            SELECT recorded_at, harness_score, commands_lines, skills_lines
            FROM harness_snapshots
            ORDER BY id DESC LIMIT 5
            """
        ).fetchall()

    return {
        "recent_cards": [dict(r) for r in cards],
        "by_arm": [dict(r) for r in by_arm],
        "harness_snapshots": [dict(r) for r in harness],
    }


def _int(v) -> int | None:
    if v is None or v == "":
        return None
    try:
        return int(float(v))
    except (TypeError, ValueError):
        return None


def _float(v) -> float | None:
    if v is None or v == "":
        return None
    try:
        return float(v)
    except (TypeError, ValueError):
        return None


def main() -> int:
    parser = argparse.ArgumentParser(description="Octo Cluster metrics DB")
    parser.add_argument("--db", type=Path, default=None)
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("init")
    p_ins = sub.add_parser("insert-card")
    p_ins.add_argument("--json", default="")
    p_ins.add_argument("--json-file", type=Path, default=None)
    p_h = sub.add_parser("insert-harness")
    p_h.add_argument("--json", default="")
    p_h.add_argument("--json-file", type=Path, default=None)
    p_mig = sub.add_parser("migrate-csv")
    p_mig.add_argument("--workspace", type=Path, required=True)
    p_tr = sub.add_parser("trends")
    p_tr.add_argument("--last", type=int, default=10)
    p_tr.add_argument("--arm", default="all")

    args = parser.parse_args()
    db = args.db or default_db_path()

    if args.cmd == "init":
        init_db(db)
        print(json.dumps({"ok": True, "db": str(db)}))
        return 0
    if args.cmd == "insert-card":
        init_db(db)
        payload = args.json
        if args.json_file:
            payload = args.json_file.read_text(encoding="utf-8-sig")
        if not payload:
            print(json.dumps({"ok": False, "error": "missing json"}))
            return 2
        row = json.loads(payload)
        rid = insert_card(db, row)
        print(json.dumps({"ok": True, "id": rid}))
        return 0
    if args.cmd == "insert-harness":
        init_db(db)
        payload = args.json
        if args.json_file:
            payload = args.json_file.read_text(encoding="utf-8-sig")
        if not payload:
            print(json.dumps({"ok": False, "error": "missing json"}))
            return 2
        row = json.loads(payload)
        rid = insert_harness(db, row)
        print(json.dumps({"ok": True, "id": rid}))
        return 0
    if args.cmd == "migrate-csv":
        stats = migrate_csv(db, args.workspace)
        print(json.dumps({"ok": True, "imported": stats, "db": str(db)}))
        return 0
    if args.cmd == "trends":
        print(json.dumps(trends(db, args.last, args.arm), indent=2))
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(main())
