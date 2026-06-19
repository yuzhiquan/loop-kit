# loop-kit

Add an autonomous **Loop Engineering** triage loop to *any* repo. You supply a
short `loop.config.yaml`; loop-kit supplies the loop machinery — the five moves,
an independent skeptic evaluator, and the §09 safety guardrails.

> Loop Engineering = you stop prompting the agent move-by-move and instead design
> the system that prompts it. loop-kit is that system, packaged and reusable.

## What a loop-kit loop does each round
discover work (open GitHub issues) → draft fix proposals → an **independent
skeptic** confirms or rejects each → persist to `.loop/state.md` → stop for a
human. **Triage + propose only: it never edits code or opens PRs.**

| Five moves (§03) | Here |
|---|---|
| Discovery | `gh issue list` open issues (config `discovery:`) |
| Handoff | pick N candidates matching `actionability:`, draft fix + test |
| Verification | skeptic re-reads each ("wrong until proven"); rejects → Parked |
| Persistence | append to `.loop/state.md` (memory on disk) |
| Scheduling | `/loop` or a cron over `.loop/loop-run.sh` |

## Install
```
/plugin marketplace add yuzhiquan/loop-kit
/plugin install loop-kit@loop-kit
```
Local dev (run without installing): `claude --plugin-dir /path/to/loop-kit`

## Use (in the target repo)
```
/loop-kit:loop-init      # interactive setup → loop.config.yaml + .loop/
/loop-kit:loop-run       # run one round now
/loop-kit:loop-status    # show Actionable / Parked counts
```
Make it a real (self-waking) loop:
```
/loop 1h <repo>/.loop/loop-run.sh           # local, machine on
# or a GitHub Actions schedule: cron         # while you sleep / machine off
```

### Example: a 60-second setup
```
cd ~/my-rust-service
/plugin marketplace add yuzhiquan/loop-kit
/plugin install loop-kit@loop-kit
/loop-kit:loop-init      # confirms repo slug + lint/test/build + token caps
/loop-kit:loop-run       # first round → proposals land in .loop/state.md
/loop-kit:loop-status    # see what's Actionable
```
The same plugin works unchanged on Rust, Go, Python, … — only `loop.config.yaml`
differs per repo. (Validated on both a Rust and a Go repo with zero plugin edits.)

## The universal / per-repo split
- **Plugin (universal):** orchestration, skeptic discipline, guardrails, runner, commands.
- **You supply (`loop.config.yaml`):** repo slug, discovery source, real lint/test/build commands, what "actionable here" means, token caps.

## The §09 safety checklist (enforced by `loop-init` + `preflight.sh`)
| Element | How loop-kit covers it |
|---|---|
| Discovery source | `discovery:` in config |
| State file (memory) | `.loop/state.md` — **outside `.claude/`** (harness blocks writes there) |
| Independent evaluator (says "no") | the skeptic step in the `loop-triage` skill |
| Isolation | N/A in v0.1 — propose-only, writes no code |
| Token cap | `caps.max_turns` + `caps.max_runs_per_day`, enforced by `loop-run.sh` |
| Human review point | loop stops at `state.md`; `--disallowedTools` blocks git/PRs |

## Ignore-file policy (in the target repo)
`loop-init` scaffolds into `.loop/` at the repo root (never under `.claude/` —
the harness blocks unattended writes there) and adjusts ignore files:
- **`.gitignore`:** ignores only `.loop/.run-count`. `state.md`, `loop.config.yaml`,
  and `loop-run.sh` are committed so the loop's memory persists (§04) and a
  cloud/CI fresh clone can resume.
- **`.dockerignore`** (only if one exists): excludes `.loop/` and `loop.config.yaml`
  so loop tooling/memory never lands in a runtime image.

## Costs to watch (§07)
Mainly **understanding rot** — it reads issues for you. Skim a few Actionable
items' real issues before acting; outsource the legwork, not the judgment.

## Status
v0.1 — `github-issues` discovery implemented; `ci` / `commits` are stubs.
`loop-init`'s detected commands are *suggestions* — confirm them; don't let the
loop guess your build.
