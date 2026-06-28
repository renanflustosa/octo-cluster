const CODE_BLOCK = 400;
const CODE_OVERLAP = 60;

export type CodeChunk = {
  id: string;
  source: string;
  text: string;
  module: string;
  startLine: number;
};

const SYMBOL_RE =
  /^(export\s+)?(async\s+)?function\s+\w+|^(export\s+)?(abstract\s+)?class\s+\w+|^export\s+(type|interface)\s+\w+|^export\s+(const|let|var)\s+\w+/;

export function chunkSourceCode(
  source: string,
  content: string,
  moduleHint: string,
): CodeChunk[] {
  const lines = content.replace(/\r\n/g, "\n").split("\n");
  const chunks: CodeChunk[] = [];
  let buf: string[] = [];
  let bufStart = 1;
  let index = 0;

  function flush(endLine: number) {
    const text = buf.join("\n").trim();
    if (text.length < 40) {
      buf = [];
      return;
    }
    chunks.push({
      id: `${source}#${index}`,
      source,
      text,
      module: moduleHint,
      startLine: bufStart,
    });
    index += 1;
    buf = [];
  }

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]!;
    const trimmed = line.trim();
    const isBoundary = SYMBOL_RE.test(trimmed);

    if (isBoundary && buf.length > 0 && buf.join("\n").length >= CODE_BLOCK) {
      flush(i);
      bufStart = i + 1;
    }

    if (buf.length === 0) bufStart = i + 1;
    buf.push(line);

    if (buf.join("\n").length >= CODE_BLOCK + CODE_OVERLAP) {
      flush(i + 1);
      bufStart = i + 2;
    }
  }

  if (buf.length) flush(lines.length);

  if (chunks.length === 0 && content.trim()) {
    const normalized = content.trim();
    let start = 0;
    while (start < normalized.length) {
      const end = Math.min(start + CODE_BLOCK, normalized.length);
      const slice = normalized.slice(start, end).trim();
      if (slice) {
        chunks.push({
          id: `${source}#${index}`,
          source,
          text: slice,
          module: moduleHint,
          startLine: 1,
        });
        index += 1;
      }
      if (end >= normalized.length) break;
      start = Math.max(end - CODE_OVERLAP, start + 1);
    }
  }

  return chunks;
}

export function extractSymbols(content: string): Array<{ name: string; line: number; kind: string }> {
  const lines = content.replace(/\r\n/g, "\n").split("\n");
  const out: Array<{ name: string; line: number; kind: string }> = [];

  for (let i = 0; i < lines.length; i++) {
    const trimmed = lines[i]!.trim();
    let m: RegExpMatchArray | null;

    m = trimmed.match(/^(export\s+)?(async\s+)?function\s+(\w+)/);
    if (m) {
      out.push({ name: m[3]!, line: i + 1, kind: "function" });
      continue;
    }
    m = trimmed.match(/^(export\s+)?(abstract\s+)?class\s+(\w+)/);
    if (m) {
      out.push({ name: m[3]!, line: i + 1, kind: "class" });
      continue;
    }
    m = trimmed.match(/^export\s+(type|interface)\s+(\w+)/);
    if (m) {
      out.push({ name: m[2]!, line: i + 1, kind: m[1]! });
      continue;
    }
    m = trimmed.match(/^export\s+(const|let|var)\s+(\w+)/);
    if (m) {
      out.push({ name: m[2]!, line: i + 1, kind: m[1]! });
    }
  }

  return out;
}
