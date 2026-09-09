# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| `main` | ✅ |

## Reporting a vulnerability

**Do not** open a public GitHub issue for security-sensitive reports.

Email **renanferreiralustosa@gmail.com** with:

- Description and impact
- Steps to reproduce
- Affected paths (e.g. `scripts/`, `.cursor/`, hooks)

We aim to acknowledge within 7 days.

## Secrets

Octo Cluster must never contain credentials. Use a local gitignored vault or your org secret manager. Keep key names only in tracked files, never values.

## Boundary patterns

Copy `boundary-patterns.example.yaml` to `boundary-patterns.local.yaml` (gitignored) and list regex patterns for names that must not appear in tracked public files. Run `scripts/boundary-audit.ps1` before commit/push.
