import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { mkdtemp, rm, stat } from "node:fs/promises";
import { join } from "node:path";
import { tmpdir } from "node:os";
import { ensureProfileSeed, fixtureProfileRoot } from "./ensure-profile-seed.ts";
import { contextDir, memoryRoot } from "./paths.ts";

describe("ensureProfileSeed", () => {
  let previousOctoCluster: string | undefined;
  let tempRoot: string;

  beforeEach(async () => {
    previousOctoCluster = process.env.OCTO_CLUSTER;
    tempRoot = await mkdtemp(join(tmpdir(), "octo-cluster-seed-"));
    process.env.OCTO_CLUSTER = tempRoot;
  });

  afterEach(async () => {
    if (previousOctoCluster === undefined) delete process.env.OCTO_CLUSTER;
    else process.env.OCTO_CLUSTER = previousOctoCluster;
    await rm(tempRoot, { recursive: true, force: true });
  });

  test("creates memory root and architecture.md from fixture", async () => {
    const profile = "octo-cluster";
    const fixtureArch = join(fixtureProfileRoot(profile), "context", "architecture.md");
    expect(await stat(fixtureArch).then(() => true).catch(() => false)).toBe(true);

    const { created } = await ensureProfileSeed(profile);
    expect(created.length).toBeGreaterThan(0);

    const root = memoryRoot(profile);
    const arch = join(contextDir(profile), "architecture.md");
    expect(await stat(root).then(() => true).catch(() => false)).toBe(true);
    expect(await stat(arch).then(() => true).catch(() => false)).toBe(true);
  });

  test("does not overwrite existing profile files", async () => {
    const profile = "octo-cluster";
    const first = await ensureProfileSeed(profile);
    expect(first.created.length).toBeGreaterThan(0);

    const arch = join(contextDir(profile), "architecture.md");
    const { writeFile } = await import("node:fs/promises");
    await writeFile(arch, "# user edited\n", "utf8");

    const second = await ensureProfileSeed(profile);
    expect(second.created.length).toBe(0);

    const content = await import("node:fs/promises").then((fs) => fs.readFile(arch, "utf8"));
    expect(content).toBe("# user edited\n");
  });
});
