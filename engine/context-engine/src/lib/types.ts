export type ChunkKind = "memory" | "docs" | "code";

export type SourceFile = {
  absolutePath: string;
  source: string;
  repo: string;
  kind: ChunkKind;
  module: string;
  mtime: number;
};

export type ChunkRow = {
  id: string;
  source: string;
  text: string;
  module: string;
  kind: ChunkKind;
  repo: string;
  mtime: number;
  hash: string;
  vector: number[];
};

export type ManifestEntry = {
  hash: string;
  mtime: number;
  chunkIds: string[];
};

export type IndexManifest = {
  version: 2;
  updatedAt: string;
  files: Record<string, ManifestEntry>;
  stats: { memory: number; docs: number; code: number };
};

export function emptyManifest(): IndexManifest {
  return {
    version: 2,
    updatedAt: new Date().toISOString(),
    files: {},
    stats: { memory: 0, docs: 0, code: 0 },
  };
}
