#!/usr/bin/env python3
"""Resolve Cursor WorkosCursorSessionToken from vscdb, vault, or env."""

from __future__ import annotations

import json
import os
import sqlite3
import sys
from pathlib import Path

TOKEN_KEYS = (
    "WorkosCursorSessionToken",
    "workosCursorSessionToken",
    "cursorAuth/workosSessionToken",
    "cursor.session.token",
)


def find_vscdb() -> Path | None:
    appdata = os.environ.get("APPDATA")
    if not appdata:
        return None
    candidates = [
        Path(appdata) / "Cursor" / "User" / "globalStorage" / "state.vscdb",
        Path(appdata) / "cursor" / "User" / "globalStorage" / "state.vscdb",
    ]
    for p in candidates:
        if p.is_file():
            return p
    return None


def read_token_from_vscdb(db_path: Path) -> str | None:
    try:
        conn = sqlite3.connect(str(db_path))
        cur = conn.cursor()
        for key in TOKEN_KEYS:
            row = cur.execute("SELECT value FROM ItemTable WHERE key = ?", (key,)).fetchone()
            if row and row[0]:
                val = row[0]
                if isinstance(val, bytes):
                    val = val.decode("utf-8", errors="ignore")
                val = str(val).strip().strip('"')
                if len(val) > 20:
                    conn.close()
                    return val
        rows = cur.execute(
            "SELECT key, value FROM ItemTable WHERE key LIKE '%workos%' OR key LIKE '%SessionToken%' OR key LIKE '%session%token%'"
        ).fetchall()
        conn.close()
        for _key, val in rows:
            if not val:
                continue
            if isinstance(val, bytes):
                val = val.decode("utf-8", errors="ignore")
            s = str(val).strip().strip('"')
            if len(s) > 40 and ("." in s or "%3A%3A" in s):
                return s
    except sqlite3.Error:
        return None
    return None


def resolve_vault_path() -> Path | None:
    env = os.environ.get("PERSONAL_VAULT")
    if env:
        p = Path(env)
        if p.is_dir():
            return p
    vault_sibling = os.environ.get("VAULT_SIBLING_NAME")
    ws = os.environ.get("OCTO_CLUSTER")
    if vault_sibling and ws:
        sibling = Path(ws).parent / vault_sibling
        if sibling.is_dir():
            return sibling
    return None


def read_token_from_vault() -> str | None:
    vault = resolve_vault_path()
    if not vault:
        return None
    session_file = vault / "DEV" / "CURSOR" / "SESSION.json"
    if not session_file.is_file():
        return None
    try:
        data = json.loads(session_file.read_text(encoding="utf-8"))
        for field in ("WorkosCursorSessionToken", "workosCursorSessionToken", "session_token"):
            val = data.get(field)
            if val and len(str(val).strip()) > 20:
                return str(val).strip()
    except (json.JSONDecodeError, OSError):
        return None
    return None


def resolve_token() -> dict:
    source = "none"
    token = os.environ.get("CURSOR_SESSION_TOKEN", "").strip()
    if token:
        source = "env"
    if not token:
        vscdb = find_vscdb()
        if vscdb:
            token = read_token_from_vscdb(vscdb) or ""
            if token:
                source = "vscdb"
    if not token:
        token = read_token_from_vault() or ""
        if token:
            source = "vault"
    return {
        "ok": bool(token),
        "source": source,
        "token": token,
        "token_preview": (token[:8] + "…" + token[-4:]) if len(token) > 16 else "[redacted]",
    }


def main() -> int:
    redact = "--redact" in sys.argv
    result = resolve_token()
    if redact or "--json" in sys.argv:
        out = {k: v for k, v in result.items() if k != "token"} if redact else result
        if redact and result.get("ok"):
            out["token_preview"] = result.get("token_preview")
        print(json.dumps(out))
    else:
        if not result["ok"]:
            print("token not found", file=sys.stderr)
            return 1
        print(result["token"])
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
