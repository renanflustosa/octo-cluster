# Octo Cluster Engineering Operating System (EOS)

Canonical engineering operating system for Octo Cluster v1.0.0.

Defines governance, delivery, architecture, releases, quality, security, OSS operations, and AI-agent operations.

## Official project conventions

### Language

**English-only** for source code, documentation, comments, commits, PRs, branches, Linear issues, ADRs, release notes, discussions, and CI logs (when configurable).

### Software development standards

| Standard | Application |
|----------|-------------|
| [Agile Manifesto](https://agilemanifesto.org/) | Delivery culture |
| [Twelve-Factor App](https://12factor.net/) | Where applicable |
| [SemVer 2.0.0](https://semver.org/) | All releases |
| [Conventional Commits 1.0.0](https://www.conventionalcommits.org/) | All commits |
| Conventional Branch Naming | All branches |
| [Keep a Changelog](https://keepachangelog.com/) | CHANGELOG.md |
| GitHub Flow | `feature` → `develop` → `main` |
| [OpenSSF OSS best practices](https://openssf.org/) | Security, supply chain |
| [Contributor Covenant](https://www.contributor-covenant.org/) | CODE_OF_CONDUCT.md |
| Documentation as Code | Docs in repo, PR-reviewed |
| Infrastructure as Code | CI, repo-policies, capabilities |
| Security by Default | SECURITY.md, scanning, no secrets in tree |
| Automation First | CI on every PR, release-please, `/ship` gates |
| AI-Agent-Friendly Development | Structured issues, DoR/DoD, validation commands |

## Linear operations

Primary work tracker: [Linear workspace `octo-cluster`](https://linear.app/octo-cluster).

GitHub Issues are for **external community reports only** — triage into Linear.

Setup checklist: [linear-workspace-setup.md](./linear-workspace-setup.md)

### Issue naming

```text
[domain] imperative verb + object
```

Examples: `[governance] add code of conduct`, `[memory] implement profile compaction`

Forbidden: vague titles (`Fix stuff`, `Improve code`), gerunds without imperative verb.

### Workflow

```text
Backlog → Todo → In Progress → In Review → Done
```

Rules per issue:

- Exactly 1 assignee
- Exactly 1 domain label
- Exactly 1 cycle (when active)
- Max 3 days duration
- Max 1 objective — split if larger

### Initiatives (15)

| Initiative | Scope |
|------------|-------|
| Engineering Standards & Governance | Branch, commit, SemVer, releases, ADRs, standards hub |
| Kernel Architecture | `domains/core/`, `capabilities/` |
| Memory | `engine/context-engine/`, `state/memory/` |
| Context Engineering | `contexts/`, execution context |
| RAG | context-engine indexing, `engine/indexing/` |
| Token Optimization | caveman/ponytail, `eval/metrics/` |
| MCP Integration | MCP docs, adapters |
| Agent Orchestration | phase commands, core-adaptive-loop |
| Evaluation & Benchmarking | `eval/` |
| Observability | `engine/metrics/` |
| Developer Experience | install, onboarding, adapters |
| Documentation | `docs/` |
| Open Source Governance | root OSS files |
| CI/CD | `.github/workflows/` |
| Security | SECURITY.md, scanning |

Project container: **Octo Cluster EOS v1.0.0**

## Branch naming standard

```text
<type>/8CL-<id>-<short-description>
```

Types: `feat`, `fix`, `docs`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `security`

Examples:

```text
feat/8CL-123-add-memory-compaction
fix/8CL-201-fix-rag-cache
docs/8CL-45-update-onboarding
```

Forbidden: branches without `8CL-<id>`, personal prefixes (`renan-fix`).

## Commit standard

```text
type(scope): description
```

Breaking changes:

```text
feat(core)!: redesign execution pipeline

BREAKING CHANGE: execution context format changed
```

## Release management

| Tool | release-please |
| Versioning | SemVer 2.0.0 |

| Bump | Triggers | Example |
|------|----------|---------|
| PATCH | `fix:`, `perf:`, `security:` | `0.1.2` → `0.1.3` |
| MINOR | `feat:` | `0.1.0` → `0.2.0` |
| MAJOR | `BREAKING CHANGE`, `feat!:`, `fix!:` | `0.x` → `1.0.0` |

## ADRs

Location: [`docs/adr/`](../adr/)

Naming: `ADR-NNN-short-title.md`

Template: [`docs/adr/template.md`](../adr/template.md)

Relevant architectural decisions **must** become ADRs before merge.

## Documentation convention

```text
docs/
  architecture/
  governance/       # this file, linear setup
  guides/
  adr/
  api/
```

Every feature documents: **Implementation**, **Usage**, **Validation**, **Limitations**.

## Definition of Ready (DoR)

Issue enters a cycle only when it has:

- [ ] Context
- [ ] Objective (single, measurable)
- [ ] Scope (In / Out)
- [ ] Acceptance Criteria
- [ ] Validation Steps (exact commands)
- [ ] Domain Label (exactly 1)
- [ ] Priority
- [ ] Initiative assigned

Label `ai-ready` when complete.

## Definition of Done (DoD)

- [ ] Code implemented
- [ ] Tests passing
- [ ] Documentation updated
- [ ] Acceptance criteria validated
- [ ] CI passing
- [ ] No critical security findings
- [ ] Conventional Commit used
- [ ] Linked Linear issue (`8CL-xxx` in PR)
- [ ] PR approved
- [ ] Release notes generated (if applicable)

## Pull request convention

See [`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md).

PR title: Conventional Commits in English.

## Code standards

**Mandatory:** SOLID, DRY, KISS, YAGNI, Clean Architecture, Dependency Inversion, Composition over Inheritance, Explicit Interfaces, Type Safety First

**Forbidden:** dead code, commented-out code, magic numbers, hidden side effects, untested critical paths

## AI-friendly development

Every issue must include: Context, Objective, Inputs, Outputs, Acceptance Criteria, Validation Commands, Definition of Done.

Executable by human developers, Cursor Agent, and future autonomous agents.

### Issue body template

```markdown
## Context
...

## Objective
...

## Scope
### In
- ...
### Out
- ...

## Inputs
- ...

## Outputs
- [ ] path/to/file

## Dependencies
- blockedBy: 8CL-xxx | none

## Acceptance Criteria
- [ ] ...

## Validation
```powershell
bun run validate octo-cluster
```

## Definition of Done
(full checklist)

## Estimate
1-3 days (split if >3)
```

## Harness integration

One Cursor chat = one Linear issue. Pass ticket ID to phase commands:

```text
/scan 8CL-123 description
```

No Linear-specific code in `domains/core/` — use MCP or manual updates.

## Semver path to 1.0.0

| Version | Gate |
|---------|------|
| 0.1.0 | Public harness, basic CI, Cursor validated |
| 0.2.x | EOS published, metrics baseline, expanded CI |
| 0.x | ADR process, feature docs, 2nd adapter |
| 1.0.0 | Stable kernel API, eval in CI, full OSS governance |

Linear project EOS v1.0.0 = strategic container; tags via release-please on `main`.
