import { readFile, writeFile } from "node:fs/promises";
import { Database } from "bun:sqlite";
import { mkdir } from "node:fs/promises";
import { join, dirname } from "node:path";
import type { ChunkRow } from "./types.ts";

export function openFts(dbPath: string): Database {
  mkdir(dirname(dbPath), { recursive: true }).catch(() => {});
  const db = new Database(dbPath);
  db.run(`
    CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
      chunk_id UNINDEXED,
      source,
      text,
      kind,
      repo,
      module,
      tokenize='unicode61'
    )
  `);
  return db;
}

export function rebuildFts(dbPath: string, rows: ChunkRow[]): void {
  const db = openFts(dbPath);
  db.run("DELETE FROM chunks_fts");
  const insert = db.prepare(
    "INSERT INTO chunks_fts(chunk_id, source, text, kind, repo, module) VALUES (?, ?, ?, ?, ?, ?)",
  );
  const tx = db.transaction(() => {
    for (const row of rows) {
      insert.run(row.id, row.source, row.text, row.kind, row.repo, row.module);
    }
  });
  tx();
  db.close();
}

export function bm25Search(
  dbPath: string,
  query: string,
  limit: number,
  filters?: { kind?: string; repo?: string; module?: string },
): Array<{ chunk_id: string; bm25: number }> {
  if (!query.trim()) return [];
  try {
    const db = openFts(dbPath);
    const terms = query
      .toLowerCase()
      .split(/\W+/)
      .filter((t) => t.length > 2)
      .map((t) => `"${t.replace(/"/g, "")}"`)
      .join(" OR ");
    if (!terms) {
      db.close();
      return [];
    }

    let sql = `SELECT chunk_id, bm25(chunks_fts) AS bm25 FROM chunks_fts WHERE chunks_fts MATCH ?`;
    const params: string[] = [terms];
    if (filters?.kind) {
      sql += " AND kind = ?";
      params.push(filters.kind);
    }
    if (filters?.repo) {
      sql += " AND repo = ?";
      params.push(filters.repo);
    }
    if (filters?.module) {
      sql += " AND module LIKE ?";
      params.push(`%${filters.module}%`);
    }
    sql += " ORDER BY bm25 LIMIT ?";
    params.push(String(limit));

    const rows = db.query(sql).all(...params) as Array<{ chunk_id: string; bm25: number }>;
    db.close();
    return rows;
  } catch {
    return [];
  }
}

export async function ftsExists(dbPath: string): Promise<boolean> {
  try {
    await readFile(dbPath);
    return true;
  } catch {
    return false;
  }
}

export function normalizeBm25(scores: number[]): Map<number, number> {
  const out = new Map<number, number>();
  if (scores.length === 0) return out;
  const min = Math.min(...scores);
  const max = Math.max(...scores);
  const span = max - min || 1;
  scores.forEach((s, i) => out.set(i, (s - min) / span));
  return out;
}
