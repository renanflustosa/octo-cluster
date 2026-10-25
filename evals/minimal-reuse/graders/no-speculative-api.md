---
type: llm
focus: { source: file, path: src/lib/time.js }
---

This file originally contained only toYmd(d) and addDays(d, n).

PASS if it still contains only those two functions (unchanged, or with trivial whitespace or comment edits).
FAIL if a new function, a format-string parameter, an options object or any other configurable formatting was added.
