# Evals

Does the plugin beat plain Claude Code? Each case runs twice: with the plugin and with no plugin at all (`claude plugin eval` ablation). `Δ` is what the plugin adds.

```bash
claude plugin eval . --scaffold --allow-tools Write Edit --model sonnet --runs 2 --no-publish
```

`--scaffold` runs each case's `scaffold.sh` (a small git repo fixture) as you; the scripts are in this folder. `prompt-slash` types the slash command, which does not exist without the plugin, so read its `WITH` score against `prompt-natural` `W/OUT` (the best a user can do without the plugin), or run it alone with `--ablation none`.

## Cases

| Case | Request | Graded on |
| --- | --- | --- |
| `prompt-natural` | "Turn this rough request into a prompt…" | Prompt names the file, the cause and a runnable "done"; no edits |
| `prompt-slash` | `/octo-cluster:prompt <rough request>` | Same graders |
| `minimal-reuse` | Format a date, "we might want other formats later" | Reuses the existing helper; no new file, dependency or format API |
| `bugfix-regression` | "Quantity 0 still charges one" | Root cause fixed, missing qty still 1, regression test added |

## Results (2026-10-25, Claude Code 2.1.308, agent `sonnet`, judge default)

| Case | With | Without | Δ |
| --- | --- | --- | --- |
| `prompt-natural` | 1.00 | 0.50 | **+0.50** |
| `prompt-slash` (vs `prompt-natural` W/OUT) | 1.00 | 0.50 | **+0.50** |
| `minimal-reuse` | 1.00 | 1.00 | 0.00 |
| `bugfix-regression` | 1.00 | 1.00 | 0.00 |

- `/prompt`: without the plugin, Claude writes the prompt from the commit messages in one turn without opening the code, so the prompt never names `src/auth/login.js`. With the plugin it reads the repo first. `prompt-natural` only fires the skill since `/prompt` became model-invocable; with `disable-model-invocation: true` it scored 0.50 in both arms.
- `ponytail-lite`, `systematic-debugging`: no measurable gain on these tasks; the model already reuses the helper and adds the regression test. The skills were never invoked.
- `/ship` needs Bash, and `claude plugin eval` only grants Bash inside the OS sandbox (Linux, macOS or WSL2; not native Windows). A manual A/B on the same dirty repo (feature + unrelated README change + untracked `.env`, local bare remote, one run per arm): with `/octo-cluster:ship`, two Conventional Commits (`feat`, `docs`), tests run, `.env` left out, about 3× the cost; with "commit and push my changes", one mixed commit, no tests, `.env` left out.

Small samples (2–3 runs per arm): treat a Δ of 0.50 as a signal, not a precise number.
