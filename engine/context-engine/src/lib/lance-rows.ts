import type { ChunkKind, ChunkRow } from "./types.ts";

/** LanceDB/Arrow may return vector as FixedSizeList with isValid — flatten to number[]. */
export function toVectorArray(vector: unknown): number[] {
  if (Array.isArray(vector)) return vector as number[];
  if (vector instanceof Float32Array || vector instanceof Float64Array) {
    return Array.from(vector);
  }
  if (vector && typeof vector === "object") {
    const v = vector as {
      toArray?: () => number[];
      length?: number;
      get?: (i: number) => number;
    };
    if (typeof v.toArray === "function") return v.toArray();
    if (typeof v.get === "function" && typeof v.length === "number") {
      return Array.from({ length: v.length }, (_, i) => v.get!(i));
    }
    if (ArrayBuffer.isView(vector)) {
      return Array.from(vector as ArrayLike<number>);
    }
  }
  throw new Error("Invalid vector field in chunk row");
}

export function normalizeChunkRow(raw: Record<string, unknown>): ChunkRow {
  return {
    id: String(raw.id),
    source: String(raw.source),
    text: String(raw.text),
    module: String(raw.module ?? ""),
    kind: raw.kind as ChunkKind,
    repo: String(raw.repo),
    mtime: Number(raw.mtime),
    hash: String(raw.hash),
    vector: toVectorArray(raw.vector),
  };
}

/** Plain records for LanceDB createTable (avoids Arrow vector.isValid inference errors). */
export function serializeChunkRows(rows: ChunkRow[]): ChunkRow[] {
  return rows.map((row) => normalizeChunkRow(row as unknown as Record<string, unknown>));
}
