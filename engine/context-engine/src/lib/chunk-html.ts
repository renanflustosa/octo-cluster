const CHUNK_SIZE = 600;
const OVERLAP = 80;
const MIN_CHARS = 100;

export function stripHtml(html: string): string {
  let text = html
    .replace(/<script[\s\S]*?<\/script>/gi, " ")
    .replace(/<style[\s\S]*?<\/style>/gi, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/\s+/g, " ")
    .trim();
  return text;
}

export function chunkPlainText(
  source: string,
  text: string,
  moduleHint: string,
): Array<{ id: string; source: string; text: string; module: string }> {
  const normalized = text.replace(/\r\n/g, "\n").trim();
  if (!normalized || normalized.length < MIN_CHARS) return [];

  const chunks: Array<{ id: string; source: string; text: string; module: string }> = [];
  let start = 0;
  let index = 0;

  while (start < normalized.length) {
    const end = Math.min(start + CHUNK_SIZE, normalized.length);
    const slice = normalized.slice(start, end).trim();
    if (slice.length >= MIN_CHARS) {
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

export function chunkHtml(
  source: string,
  html: string,
  moduleHint: string,
): Array<{ id: string; source: string; text: string; module: string }> {
  return chunkPlainText(source, stripHtml(html), moduleHint);
}
