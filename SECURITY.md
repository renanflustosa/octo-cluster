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
- Affected paths (e.g. `scripts/`, `engine/`, hooks)

We aim to acknowledge within 7 days.

## Secrets

Octo Cluster must never contain credentials. Use a local gitignored vault or your org secret manager. See onboarding docs for env wiring patterns — key names only in tracked files.
