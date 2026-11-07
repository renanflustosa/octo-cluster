# Production checklist

Minimalist (80/20). `[x]` done, `[ ]` gap, `n/a` does not apply. The plugin shapes how Claude Code works (skills, hooks, scripts); the LLM is Claude Code itself. A change that affects an item updates this file in the same PR.

## 1. Problem & requirements

- [x] Problem, users and success: who it is for and before/after in the [README](README.md); success = beats plain Claude Code in [evals](evals/README.md).
- [x] Cost budget: "Token economics" in the [README](README.md).
- [x] Human approval: `/ship` only commits, pushes or merges when the user asks.

## 2. Context & tools

- [x] (AI) Context: short `AGENTS.md`/`CLAUDE.md`; know-how loaded on demand by skills.
- n/a (AI) Retrieval with permission filtering: no retrieval layer.
- [x] Minimal tools: skills, one `hooks/hooks.json`, two scripts (`ship.ps1`, `boundary-audit.ps1`).

## 3. Evals & guardrails

- [x] Representative evals: `claude plugin eval` ablation cases in [evals/](evals/README.md) (bugfix regression, minimal reuse, natural and slash prompts).
- [ ] `/ship` eval: covered only by a manual A/B because `claude plugin eval` grants Bash only inside the OS sandbox; add a sandboxed case.
- [x] Leak protection: public-repo boundary audit (`scripts/boundary-audit.ps1`, `boundary-patterns.example.yaml`); `/ship` leaves `.env` out.
- [x] Vulnerability reports: [SECURITY.md](SECURITY.md).
- [x] Fallback: `/ship` stops with `SHIP BLOCKED` on ambiguous git state, failing checks or credential-like values.

## 4. Reliability & observability

- [x] Results recorded per run in `evals/results/`.
- n/a Timeouts, retries and rate limits: handled by Claude Code itself.
- [ ] Failures feed back: a reported plugin misbehavior becomes a new eval case with the fix.

## 5. Cost & performance

- [x] Baseline: eval results compare cost with and without the plugin.
- [x] Optimize only with data: token economics measured before changes.
