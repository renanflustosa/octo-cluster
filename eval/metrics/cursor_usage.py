#!/usr/bin/env python3
"""Cursor dashboard usage API client (unofficial)."""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

# Allow import from same directory when run as script
sys.path.insert(0, str(Path(__file__).resolve().parent))
from cursor_session import resolve_token  # noqa: E402

BASE = "https://cursor.com"
MAX_PAGES = 20
PAGE_SIZE = 100


def _request(method: str, path: str, token: str, body: dict | None = None) -> dict:
    url = f"{BASE}{path}"
    headers = {
        "Cookie": f"WorkosCursorSessionToken={token}",
        "Accept": "application/json",
        "User-Agent": "octo-cluster-metrics/1.0",
    }
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        headers["Origin"] = "https://cursor.com"
        data = json.dumps(body).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="ignore")[:500]
        raise RuntimeError(f"HTTP {e.code}: {err_body}") from e


def get_usage_summary(token: str) -> dict:
    return _request("GET", "/api/usage-summary", token)


def fetch_events_since(token: str, since_ms: int) -> list[dict]:
    events: list[dict] = []
    for page in range(1, MAX_PAGES + 1):
        payload = {"pageSize": PAGE_SIZE, "page": page, "startDate": 0}
        data = _request("POST", "/api/dashboard/get-filtered-usage-events", token, payload)
        batch = data.get("usageEventsDisplay") or data.get("usageEvents") or []
        if not batch:
            break
        for ev in batch:
            ts = _event_ts(ev)
            if ts >= since_ms:
                events.append(ev)
        if len(batch) < PAGE_SIZE:
            break
        oldest = min(_event_ts(ev) for ev in batch)
        if oldest < since_ms:
            break
    return [ev for ev in events if _event_ts(ev) >= since_ms]


def _event_ts(ev: dict) -> int:
    raw = ev.get("timestamp") or ev.get("createdAt") or 0
    try:
        return int(raw)
    except (TypeError, ValueError):
        return 0


def aggregate_events(events: list[dict]) -> dict:
    inp = out = cache = 0
    cents = 0.0
    for ev in events:
        usage = ev.get("tokenUsage") or ev.get("usage") or {}
        inp += int(usage.get("inputTokens") or 0)
        out += int(usage.get("outputTokens") or 0)
        cache += int(usage.get("cacheReadTokens") or usage.get("cacheReadInputTokens") or 0)
        if usage.get("totalCents") is not None:
            cents += float(usage["totalCents"])
        elif ev.get("chargedCents") is not None:
            cents += float(ev["chargedCents"])
    total = inp + out + cache
    return {
        "events": len(events),
        "tokens_input": inp,
        "tokens_output": out,
        "tokens_cache_read": cache,
        "tokens_total": total,
        "cost_usd": round(cents / 100.0, 4),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--since-ms", type=int, default=0)
    parser.add_argument("--summary-only", action="store_true")
    parser.add_argument("--token", default="")
    args = parser.parse_args()

    token = args.token.strip() or resolve_token().get("token") or ""
    if not token:
        print(json.dumps({"ok": False, "error": "no_token"}))
        return 1

    try:
        if args.summary_only:
            summary = get_usage_summary(token)
            print(json.dumps({"ok": True, "summary": summary}))
            return 0
        events = fetch_events_since(token, args.since_ms) if args.since_ms else fetch_events_since(token, 0)
        agg = aggregate_events(events)
        print(json.dumps({"ok": True, **agg}))
        return 0
    except RuntimeError as e:
        print(json.dumps({"ok": False, "error": str(e)}))
        return 1


if __name__ == "__main__":
    sys.exit(main())
