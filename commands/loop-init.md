---
description: Set up a loop-kit triage loop in the current repo — scaffold loop.config.yaml + .loop/, enforcing the §09 safety checklist (evaluator + token cap + human checkpoint).
disable-model-invocation: true
---

# loop-kit: initialize a loop in this repo

Set up an autonomous triage loop for the current repository. Work in
`${CLAUDE_PROJECT_DIR}`. Optional focus from the user: "$ARGUMENTS".

Follow these steps:

1. **Inspect the repo** to PROPOSE (not assume) the project facts:
   - Detect the GitHub slug via `git remote get-url origin`.
   - Find real build/lint/test commands from `Makefile`, `package.json`,
     `Cargo.toml`, `go.mod`, etc. Do NOT guess — if unsure, leave a clear
     placeholder and tell the user to fill it.

2. **Confirm the §09 inputs with the user** (ask, don't silently decide):
   - discovery source (default `github-issues`)
   - the real `lint` / `test` / `build` commands
   - token caps (`max_turns`, `max_runs_per_day`)
   Present your detected values as defaults; let the user correct them.

3. **Scaffold** by copying the plugin templates and filling them in:
   - Copy `${CLAUDE_PLUGIN_ROOT}/templates/loop.config.yaml` to
     `${CLAUDE_PROJECT_DIR}/loop.config.yaml` and substitute the confirmed values.
   - Copy `${CLAUDE_PLUGIN_ROOT}/templates/state.md` to
     `${CLAUDE_PROJECT_DIR}/.loop/state.md` (replace `{{REPO}}` with the slug).
     NOTE: the slug contains a `/`, so if you substitute with `sed`, use a
     non-slash delimiter, e.g. `sed "s|{{REPO}}|$slug|"` — `s/.../.../` breaks.
   - Copy `${CLAUDE_PLUGIN_ROOT}/scripts/loop-run.sh` to
     `${CLAUDE_PROJECT_DIR}/.loop/loop-run.sh` and `chmod +x` it, so the repo can
     be scheduled with `/loop 1h .loop/loop-run.sh` without the plugin on PATH.
   - Add `.run-count` to `${CLAUDE_PROJECT_DIR}/.loop/.gitignore`.
   IMPORTANT: never scaffold under `.claude/` — the harness blocks unattended
   writes there. Loop data lives in `.loop/` at the repo root.

3b. **Update the repo's ignore files** (idempotently — only add lines not
   already present):
   - `.gitignore`: ensure `.loop/.run-count` is ignored. Do NOT ignore the whole
     `.loop/` folder — `state.md` (the loop's memory, §04 "the repo doesn't
     forget"), `loop.config.yaml`, and `loop-run.sh` SHOULD be committed so
     cloud/CI fresh-clone runs can resume from prior state.
   - `.dockerignore`: ONLY if one already exists in the repo, append `.loop/` and
     `loop.config.yaml` — loop tooling/memory has no place in a runtime image.
     Do not create a `.dockerignore` if the repo doesn't have one.

4. **Verify** by running `${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh`. Report its
   output. Do not declare success unless preflight PASSes.

5. **Tell the user how to run it**:
   - one round now: `/loop-kit:loop-run`
   - schedule it:   `/loop 1h ${CLAUDE_PROJECT_DIR}/.loop/loop-run.sh` (local) or
     a GitHub Actions `schedule:` cron (runs while the machine is off).

Refuse to finish if there is no evaluator (the loop-triage skill provides it)
and no token cap — those are the §09 guardrails that keep the loop from
quietly making and never-checking mistakes.
