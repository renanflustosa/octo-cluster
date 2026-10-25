---
type: regex
target: { source: file, path: src/cart.js }
pattern: 'qty\s*\|\|'
match: not_contains
weight: 2
---
