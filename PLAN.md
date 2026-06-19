# loop-kit — Plan

An importable **Loop Engineering** kit: a Claude Code plugin that adds an
autonomous triage loop (discover → propose → independent skeptic → persist) to
*any* repo. You supply a short `loop.config.yaml`; the plugin supplies the loop
machinery and the safety guardrails.

> Loop Engineering (Addy Osmani, June 2026): you stop prompting the agent
> move-by-move and instead design the system that prompts it. loop-kit is that
> system, packaged so it imports into any repo based only on what the user supplies.

## Goal & non-goals
- **Goal:** one install + one `loop.config.yaml` gives any repo a working,
  guard-railed triage loop. The same plugin works on Rust, Go, Python, … with
  zero plugin edits — only the per-repo config differs.
- **Non-goal (v0.1):** auto-fixing code / opening PRs. The loop is **triage +
  propose only**. It writes proposals to a state file and stops for a human.

## The core abstraction — universal vs. per-repo
| Plugin ships (universal) | User supplies (`loop.config.yaml`) |
|---|---|
| Five-moves orchestration | `repo:` slug |
| Independent-skeptic evaluator discipline | `discovery:` source |
| §09 guardrails (token caps, human checkpoint, `.loop/` not `.claude/`) | `commands.{lint,test,build}` |
| Runner script + `/loop-*` commands | `actionability:` (what's worth doing here) |
| Config schema + preflight validation | `caps.{max_turns,max_runs_per_day}` |

If a fact is repo-specific, it belongs in the config. If it's loop machinery, it
belongs in the plugin. That line is what makes this reusable rather than a
copy-paste per project.

## The five moves (§03) — what one round does
1. **Discovery** — read open GitHub issues (`gh issue list`), skip already-seen.
2. **Handoff** — pick `candidates_per_round` issues matching `actionability`,
   draft a concrete fix (file + the `commands.test` that would prove it).
3. **Verification** — an **independent skeptic** re-reads each proposal with the
   default "wrong until proven otherwise"; rejects → Parked-with-reason. This is
   the "say no" that separates a real loop from an agent nodding at itself.
4. **Persistence** — append to `.loop/state.md` (memory on disk).
5. **Scheduling** — `/loop` or a cron over `.loop/loop-run.sh` makes it self-waking.

## Project layout
```
loop-kit/
├── .claude-plugin/{plugin.json, marketplace.json}   # installable manifest + marketplace
├── commands/{loop-init, loop-run, loop-status}.md    # /loop-kit:* slash commands
├── skills/loop-triage/SKILL.md                       # the brain — reads config, not hardcoded
├── scripts/{loop-run.sh, preflight.sh}               # generalized runner + §09 checklist
├── templates/{loop.config.yaml, state.md}            # the per-repo "what you supply"
├── README.md
└── PLAN.md
```

## Scaffolded files in the TARGET repo (created by `/loop-kit:loop-init`)
All under the repo root, deliberately **outside `.claude/`** (the harness blocks
unattended writes under `.claude/` — a bug we hit and designed around):
- `loop.config.yaml` — the per-repo config (committed).
- `.loop/state.md` — the loop's memory (committed; §04 "the repo doesn't forget").
- `.loop/loop-run.sh` — a copy of the runner so the repo is schedulable standalone (committed).
- `.loop/.run-count` — ephemeral per-day counter (gitignored).

### Ignore-file policy (target repo)
- **`.gitignore`:** ignore only `.loop/.run-count`. Memory, config, and the
  runner ARE committed so cloud/CI fresh-clone runs can resume from prior state.
- **`.dockerignore`** (only if one already exists): exclude `.loop/` and
  `loop.config.yaml` — loop tooling/memory has no place in a runtime image.

`loop-init` applies both; `preflight.sh` checks `.loop/` is not under `.claude/`.

## The §09 safety checklist — enforced, not just documented
| Element | How loop-kit covers it |
|---|---|
| Discovery source | `discovery:` in config |
| State file (memory) | `.loop/state.md`, outside `.claude/` |
| Independent evaluator (says "no") | skeptic step in the `loop-triage` skill |
| Isolation | N/A in v0.1 (propose-only, writes no code) |
| Token cap | `caps.max_turns` + `caps.max_runs_per_day`, enforced by `loop-run.sh` |
| Human review point | loop stops at `state.md`; `--disallowedTools` blocks git/PRs |

`loop-init` refuses to finish without an evaluator + token cap. `preflight.sh`
fails if loop data sits under `.claude/` or the repo slug is unset.

## Costs to watch (§07)
- **Understanding rot** — the loop reads issues for you; skim a few Actionable
  items' real issues before acting. Outsource the legwork, not the judgment.
- **Token blowups** — the per-day cap + max-turns are the backstop against a
  stuck round burning the night.

## Validation done
- Built against agentgateway (Rust); fixed three real bugs found by running it:
  writes blocked under `.claude/`; path-scoped tool perms unhonored headless;
  repo-root resolution.
- **Proven reusable on a second repo:** imported into `kubernetes-sigs/descheduler`
  (Go) with zero plugin edits — preflight PASS, one round scanned 35 issues,
  2 Actionable, 1 correctly Parked. Caught + fixed two more bugs (sed `/`
  delimiter on the slug; YAML readers eating trailing `# comments`).

## Status & roadmap
- **v0.1 (now):** `github-issues` discovery; triage + propose only.
- **Next:** implement `ci` / `commits` discovery sources (currently stubs).
- **Later (opt-in, higher risk):** auto-fix mode using `git worktree` isolation
  per finding + an evaluator gate (`make test` must pass) — the §04 "worktrees"
  + §05 maker-checker pattern, behind an explicit config flag.
