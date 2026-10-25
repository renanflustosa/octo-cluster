#!/usr/bin/env bash
# Cart total treats qty 0 as 1 because of `|| 1`.
set -euo pipefail
git init -q -b main .
mkdir -p src test
cat > package.json <<'J'
{ "name": "cart", "private": true, "scripts": { "test": "node --test" } }
J
cat > src/cart.js <<'J'
function total(items) {
  return items.reduce((sum, it) => sum + it.price * (it.qty || 1), 0);
}
module.exports = { total };
J
cat > test/cart.test.js <<'J'
const test = require('node:test');
const assert = require('node:assert');
const { total } = require('../src/cart');
test('sums price times qty', () => {
  assert.strictEqual(total([{ price: 10, qty: 2 }, { price: 5, qty: 1 }]), 25);
});
test('missing qty counts as one', () => {
  assert.strictEqual(total([{ price: 7 }]), 7);
});
J
git -c user.name=dev -c user.email=dev@example.com add -A
git -c user.name=dev -c user.email=dev@example.com commit -qm 'feat: cart total'
