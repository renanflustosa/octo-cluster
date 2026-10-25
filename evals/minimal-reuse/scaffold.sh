#!/usr/bin/env bash
# Repo that already has a YYYY-MM-DD helper under a non-obvious name.
set -euo pipefail
git init -q -b main .
mkdir -p src/lib
cat > package.json <<'J'
{ "name": "billing", "private": true, "scripts": { "test": "node --test" } }
J
cat > src/lib/time.js <<'J'
// Calendar date in UTC, e.g. 2026-03-09.
function toYmd(d) {
  return d.toISOString().slice(0, 10);
}
function addDays(d, n) {
  return new Date(d.getTime() + n * 86400000);
}
module.exports = { toYmd, addDays };
J
cat > src/invoice.js <<'J'
const { toYmd, addDays } = require('./lib/time');
function invoice(order) {
  return { id: order.id, issued: toYmd(order.date), due: toYmd(addDays(order.date, 30)) };
}
module.exports = { invoice };
J
cat > src/report.js <<'J'
function report(rows) {
  return rows.map((r) => ({ id: r.id, total: r.total, createdAt: r.createdAt }));
}
module.exports = { report };
J
git -c user.name=dev -c user.email=dev@example.com add -A
git -c user.name=dev -c user.email=dev@example.com commit -qm 'feat: invoices and report'
