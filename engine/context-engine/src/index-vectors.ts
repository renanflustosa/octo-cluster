import { parseTarget } from "./lib/paths.ts";
import { runIndex } from "./lib/run-index.ts";

const { profile } = parseTarget(process.argv);
try {
  await runIndex([process.argv[0]!, process.argv[1]!, profile, "--kind", "memory", "--full"]);
} catch (err) {
  console.error(String(err));
  process.exit(1);
}
