---
type: regex
target: { source: file, path: package.json }
pattern: 'dayjs|moment|date-fns|luxon|dependencies'
match: not_contains
---
