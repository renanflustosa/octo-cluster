import { ensureProfileSeed } from "./lib/ensure-profile-seed.ts";

const profile = process.argv[2] ?? "octo-cluster";

try {
  const { created } = await ensureProfileSeed(profile);
  if (created.length === 0) {
    console.log(`[seed-profile] ${profile} already seeded`);
  } else {
    console.log(`[seed-profile] ${profile} created ${created.length} file(s)`);
    for (const path of created) console.log(`  + ${path}`);
  }
} catch (err) {
  console.error(String(err));
  process.exit(1);
}
