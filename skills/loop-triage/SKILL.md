---
name: loop-triage
description: Run one round of a loop-kit triage loop for the current repo. Reads loop.config.yaml for project facts, discovers work (e.g. open GitHub issues), drafts fix proposals, has an independent skeptic evaluator confirm or reject each, and persists results to .loop/state.md. Triage + propose only — never edits code, runs git, or opens PRs. Use when running a loop-kit round.
---

# loop-triage — the loop brain (project-agnostic)

This is the **discovery + verification** engine of a loop-kit loop. It is
generic: every project-specific fact comes from `loop.config.yaml` in the repo
root, NOT from this file. It runs unattended, so it **proposes** and never acts.
The human review checkpoint is the state file; nothing leaves this skill except
writes to `.loop/state.md`.

## Step 0 — Load config (do this first, every round)
Read `${CLAUDE_PROJECT_DIR}/loop.config.yaml` (fall back to `./loop.config.yaml`).
If it is missing, STOP and tell the user to run `/loop-kit:loop-init`. From it
take: `repo`, `discovery`, `commands.{lint,test,build}`, `actionability`,
`caps`, `candidates_per_round`. Use THESE values below — never hardcode repo
names, languages, or build commands.

## The five moves

### 1. Discovery — find what's worth doing this round
For `discovery: github-issues` (the v0.1 implemented source):
```
gh issue list -R <repo> --state open \
  --limit 40 --json number,title,labels,updatedAt,comments
```
Skip any issue already under **Done** or **Parked** in `.loop/state.md` unless
its `updatedAt` is newer than recorded (new activity = re-look).
For `discovery: ci` or `commits`: not yet implemented — note it in the round log
and fall back to `github-issues` if a `repo` is set, else STOP.

### 2. Handoff — pick the round's candidates
From the unseen set, select up to `candidates_per_round` items that match the
repo's `actionability` description. For each, locate the relevant code with
Grep/Glob and draft a concrete fix approach: which file(s), what change, and
what `commands.test` invocation would prove it.

### 3. Verification — the independent skeptic (the "say no")
The most important move; never skip it. After drafting a proposal, **re-read it
from scratch as a hostile reviewer** whose default is *"this proposal is wrong
until proven otherwise."* Check concretely:
- Does the cited file/function actually exist? (Re-Grep — do not trust the draft.)
- Would the change plausibly build with `commands.build`?
- Is the "what test proves it" real and runnable via `commands.test`?
- Is it actually actionable here, or did the draft talk itself into it?

Fail any check → **reject**, record as Parked with the reason. When in doubt,
reject. A loop that rubber-stamps its own proposals is an agent nodding at itself.

> If you ever generate AND judge in one breath, you are grading your own
> homework. Draft fully, THEN judge as an outsider.

### 4. Persistence — write to the state file
Append/update `${CLAUDE_PROJECT_DIR}/.loop/state.md`. Record each item under
exactly one of **Actionable** (passed skeptic), **Parked** (rejected, with
reason), or **Done** (closed upstream). Never delete history; append a dated
round-log entry.

### 5. Hand back — do NOT act
Stop. No code edits, no `git`, no PRs, no issue comments. The Actionable list IS
the deliverable.

## Output contract
End with a 3-line summary: issues scanned, new Actionable, new Parked. Then stop.
