import { readFile } from "node:fs/promises";
import { parseTarget, symbolsPath } from "./lib/paths.ts";

type SymbolEntry = {
  name: string;
  kind: string;
  line: number;
  source: string;
  repo: string;
  module: string;
};

function queryFromArgv(argv: string[]): string {
  const qIdx = argv.indexOf("--query");
  if (qIdx >= 0 && argv[qIdx + 1]) return argv[qIdx + 1]!;
  const { profile } = parseTarget(argv);
  const pos = argv.indexOf(profile);
  if (pos >= 0 && argv[pos + 1] && !argv[pos + 1]!.startsWith("--")) {
    return argv.slice(pos + 1).filter((a) => !a.startsWith("--")).join(" ");
  }
  return "";
}

const { profile } = parseTarget(process.argv);
const query = queryFromArgv(process.argv).toLowerCase();

if (!query) {
  console.error('Usage: symbol-search <profile> --query "SymbolName"');
  process.exit(1);
}

let index: { symbols: SymbolEntry[] };
try {
  index = JSON.parse(await readFile(symbolsPath(profile), "utf8"));
} catch {
  console.log(`[${profile}] No symbol index. Run: core-context-search.ps1 -Profile ${profile} (after index-symbols)`);
  process.exit(0);
}

const hits = index.symbols
  .filter((s) => s.name.toLowerCase().includes(query))
  .slice(0, 15);

if (hits.length === 0) {
  console.log(`[${profile}] No symbols matching "${query}"`);
  process.exit(0);
}

console.log(`# [${profile}] Symbol search (${hits.length} hits)\n`);
for (const h of hits) {
  console.log(`- ${h.name} (${h.kind}) → ${h.repo}:${h.source}:${h.line} [${h.module}]`);
}
