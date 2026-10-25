---
type: llm
focus: { source: file, path: src/cart.js }
---

Original code: `it.price * (it.qty || 1)`. Required behavior: qty 0 contributes 0; a missing (undefined) qty still counts as 1.

PASS if the code gives qty 0 → 0 and missing qty → 1 (for example `it.qty ?? 1`), with no unrelated changes.
FAIL if qty 0 still counts as 1, if a missing qty now counts as 0 or NaN, or if unrelated logic was rewritten.
