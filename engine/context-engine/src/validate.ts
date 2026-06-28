import { stat } from "node:fs/promises";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import {
  contextDir,
  contextEngineRoot,
  memoryRoot,
  vectorPath,
} from "./lib/paths.ts";
import { resolveBunExecutable } from "./lib/resolve-bun.ts";

function resolveProfiles(): string[] {
  if (process.argv.length > 2) {
    return process.argv.slice(2);
  }
  const envProfile = process.env.CONTEXT_ENGINE_PROFILE;
  if (envProfile) {
    return envProfile.split(/[,\s]+/).filter(Boolean);
  }
  return ["octo-cluster"];
}

const profiles = resolveProfiles();
const bun = resolveBunExecutable();

const ce = contextEngineRoot();
let ok = 0;
let fail = 0;

function check(name: string, pass: boolean, detail = "") {
  if (pass) {
    console.log(`OK ${name}${detail ? ` - ${detail}` : ""}`);
    ok++;
  } else {
    console.log(`FAIL ${name}${detail ? ` - ${detail}` : ""}`);
    fail++;
  }
}

check("context-engine installed", await stat(join(ce, "node_modules")).then(() => true).catch(() => false));
check("bun executable", bun !== "bun" || spawnSync(bun, ["--version"], { encoding: "utf8" }).status === 0, bun);

for (const profile of profiles) {
  const root = memoryRoot(profile);
  const arch = join(contextDir(profile), "architecture.md");
  check(`${profile}: memory root`, await stat(root).then(() => true).catch(() => false), root);
  check(`${profile}: architecture.md`, await stat(arch).then(() => true).catch(() => false));

  const index = spawnSync(bun, ["run", join(ce, "src/index-vectors.ts"), profile], {
    encoding: "utf8",
    cwd: ce,
    timeout: 120_000,
    env: { ...process.env, OCTO_CLUSTER: process.env.OCTO_CLUSTER ?? join(ce, "..", "..") },
  });
  check(`${profile}: index`, index.status === 0, index.stderr?.split("\n").at(-2)?.trim());

  const search = spawnSync(
    bun,
    ["run", join(ce, "src/search.ts"), profile, "--query", "architecture"],
    { encoding: "utf8", cwd: ce, timeout: 60_000 },
  );
  check(`${profile}: search`, search.status === 0 && search.stdout.includes("Context retrieval"));

  check(`${profile}: vector db`, await stat(vectorPath(profile)).then(() => true).catch(() => false));
}

const compress = spawnSync(
  bun,
  ["run", join(ce, "src/compress-log.ts"), "-"],
  {
    input: "error TS9999: fail\nsrc/x.ts:1:1\n",
    encoding: "utf8",
    cwd: ce,
  },
);
check("compress-log stdin", compress.status === 0 && compress.stdout.includes("TS9999"));

console.log(`\n${ok} passed, ${fail} failed`);
process.exit(fail > 0 ? 1 : 0);
