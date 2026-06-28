import { runIndex } from "./lib/run-index.ts";

try {
  await runIndex(process.argv);
} catch (err) {
  console.error(String(err));
  process.exit(1);
}
