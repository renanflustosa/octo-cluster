-- Octo Cluster metrics kernel — portable schema (SQLite)
-- Consumed by octo-cluster; embed the same schema in consumer repos when needed.
-- schema_version 2: combination_id, harness_score, measured/estimated token buckets (ADR-006)

PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS schema_version (
  version INTEGER NOT NULL
);
INSERT OR IGNORE INTO schema_version (version) VALUES (2);

CREATE TABLE IF NOT EXISTS cards (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  recorded_at TEXT NOT NULL,
  ticket TEXT NOT NULL,
  arm TEXT DEFAULT 'default',
  combination_id TEXT DEFAULT 'baseline',
  repo TEXT,
  tokens_input INTEGER,
  tokens_output INTEGER,
  tokens_cache_read INTEGER,
  tokens_total INTEGER,
  tokens_input_measured INTEGER,
  tokens_output_measured INTEGER,
  tokens_input_estimated INTEGER,
  tokens_output_estimated INTEGER,
  cost_usd REAL,
  usage_events INTEGER,
  usage_source TEXT,
  diff_added INTEGER,
  diff_deleted INTEGER,
  diff_net INTEGER,
  files_changed INTEGER,
  gates_pass INTEGER,
  context_budget_alerts INTEGER,
  commands_lines INTEGER,
  skills_lines INTEGER,
  harness_score INTEGER,
  ship_verdict TEXT,
  notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_cards_ticket ON cards(ticket);
CREATE INDEX IF NOT EXISTS idx_cards_recorded_at ON cards(recorded_at);
CREATE INDEX IF NOT EXISTS idx_cards_arm ON cards(arm);
-- idx_cards_combination created in ensure_v2 after ALTER for legacy DBs

CREATE TABLE IF NOT EXISTS harness_snapshots (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  recorded_at TEXT NOT NULL,
  harness_score INTEGER,
  checks_ok INTEGER,
  checks_total INTEGER,
  commands_lines INTEGER,
  skills_lines INTEGER,
  audit_ok INTEGER,
  audit_warn INTEGER,
  details_json TEXT
);

CREATE INDEX IF NOT EXISTS idx_harness_recorded_at ON harness_snapshots(recorded_at);
