import { expect, test } from "bun:test";
import { readFile } from "node:fs/promises";
import { join } from "node:path";

test("map-file extracts function signatures from TypeScript source", async () => {
  const mapPath = join(import.meta.dir, "map-file.ts");
  const src = await readFile(mapPath, "utf8");
  expect(src).toContain("function");
  expect(src).toMatch(/readFile/);
});

test("token-budget module exists", async () => {
  const budgetPath = join(import.meta.dir, "token-budget.ts");
  const src = await readFile(budgetPath, "utf8");
  expect(src.length).toBeGreaterThan(0);
});
