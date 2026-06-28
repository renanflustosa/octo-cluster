const CHUNK_SIZE = 600;
const OVERLAP = 80;

export type Chunk = {
  id: string;
  source: string;
  text: string;
  module?: string;
};

export function chunkMarkdown(
  source: string,
  text: string,
  moduleHint?: string,
): Chunk[] {
  const normalized = text.replace(/\r\n/g, "\n").trim();
  if (!normalized) return [];

  const chunks: Chunk[] = [];
  let start = 0;
  let index = 0;

  while (start < normalized.length) {
    const end = Math.min(start + CHUNK_SIZE, normalized.length);
    const slice = normalized.slice(start, end).trim();
    if (slice) {
      chunks.push({
        id: `${source}#${index}`,
        source,
        text: slice,
        module: moduleHint,
      });
      index += 1;
    }
    if (end >= normalized.length) break;
    start = Math.max(end - OVERLAP, start + 1);
  }

  return chunks;
}
