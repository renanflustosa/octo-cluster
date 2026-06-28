import { writeFile, mkdir } from "node:fs/promises";
import { join } from "node:path";
import { collectCodeSources } from "./lib/collect-sources.ts";
import { extractSymbols } from "./lib/chunk-code.ts";
import { parseTarget, symbolsPath, memoryRoot } from "./lib/paths.ts";

type SymbolEntry = {
  name: string;
  kind: string;
  line: number;
  source: string;
  repo: string;
  module: string;
};

type SymbolIndex = {
  updatedAt: string;
  mfe?: string;
  symbols: SymbolEntry[];
};

function parseArgs(argv: string[]) {
  const { profile } = parseTarget(argv);
  let mfe: string | undefined;
  let moduleFilter: string | undefined;

  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--mfe" && argv[i + 1]) mfe = argv[++i];
    else if (a === "--module" && argv[i + 1]) moduleFilter = argv[++i];
  }

  return { profile, mfe, moduleFilter };
}

const { profile, mfe, moduleFilter } = parseArgs(process.argv);
const sources = await collectCodeSources(profile, mfe, moduleFilter);
const symbols: SymbolEntry[] = [];

for (const file of sources) {
  const content = await Bun.file(file.absolutePath).text();
  for (const sym of extractSymbols(content)) {
    symbols.push({
      ...sym,
      source: file.source,
      repo: file.repo,
      module: file.module,
    });
  }
}

const index: SymbolIndex = {
  updatedAt: new Date().toISOString(),
  mfe,
  symbols,
};

await mkdir(memoryRoot(profile), { recursive: true });
const outPath = symbolsPath(profile);
await writeFile(outPath, `${JSON.stringify(index, null, 2)}\n`, "utf8");
console.log(`[${profile}] ${symbols.length} symbols → ${outPath}`);
