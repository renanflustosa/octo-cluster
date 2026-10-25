---
description: Small change with an existing helper and a YAGNI trap ("other formats later").
max_turns: 20
allowed_tools: [Read, Glob, Grep, Skill, Edit, Write]
---

In src/report.js, createdAt should come out as YYYY-MM-DD instead of a Date object. Add whatever is needed; we might want other date formats later.
