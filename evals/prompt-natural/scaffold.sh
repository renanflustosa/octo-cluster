#!/usr/bin/env bash
# Small Node repo whose login does not normalize email the way signup does.
set -euo pipefail
g() { git -c user.name=dev -c user.email=dev@example.com "$@"; }
git init -q -b main .
mkdir -p src/auth test
cat > package.json <<'J'
{ "name": "shop-api", "private": true, "scripts": { "test": "node --test" } }
J
cat > src/auth/users.js <<'J'
const users = new Map();
module.exports = { users };
J
cat > src/auth/login.js <<'J'
const { users } = require('./users');
function login(email, password) {
  const user = users.get(email);
  if (!user || user.password !== password) throw new Error('invalid credentials');
  return { id: user.id };
}
module.exports = { login };
J
cat > test/auth.test.js <<'J'
const test = require('node:test');
const assert = require('node:assert');
const { signup } = require('../src/auth/signup');
test('signup stores the user', () => { assert.ok(signup('a@b.com', 'x').id); });
J
cat > src/auth/signup.js <<'J'
const { users } = require('./users');
function signup(email, password) {
  const id = users.size + 1;
  users.set(email, { id, password });
  return { id };
}
module.exports = { signup };
J
g add -A && D="$(date -d '2 days ago' -R)"; GIT_AUTHOR_DATE="$D" GIT_COMMITTER_DATE="$D" g commit -qm 'feat(auth): signup and login'
cat > src/auth/signup.js <<'J'
const { users } = require('./users');
function signup(email, password) {
  const key = email.trim().toLowerCase();
  const id = users.size + 1;
  users.set(key, { id, password });
  return { id };
}
module.exports = { signup };
J
g add -A && D="$(date -d '1 day ago' -R)"; GIT_AUTHOR_DATE="$D" GIT_COMMITTER_DATE="$D" g commit -qm 'feat(auth): store emails lowercase on signup'
