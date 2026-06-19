---
description: Run one round of the loop-kit triage loop in the current repo (triage + propose only; never edits code).
disable-model-invocation: true
---

# loop-kit: run one round

Run a single triage round for the current repository using the `loop-triage`
skill and this repo's `loop.config.yaml`.

1. If `${CLAUDE_PROJECT_DIR}/loop.config.yaml` is missing, tell the user to run
   `/loop-kit:loop-init` first, then stop.
2. Invoke the **loop-triage** skill: load config, discover work, draft proposals,
   run the independent skeptic, persist results to `.loop/state.md`.
3. Triage + propose ONLY — do not edit code, run git, or open PRs.
4. End with the 3-line summary (scanned / new Actionable / new Parked).

Optional focus from the user: "$ARGUMENTS".

Note: for unattended/scheduled runs use the bundled script directly
(`.loop/loop-run.sh`), which applies the token caps and the tool allowlist.
