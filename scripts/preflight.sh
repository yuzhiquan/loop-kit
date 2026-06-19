#!/usr/bin/env bash
# loop-kit preflight — checks a repo is ready to run the loop, and that the §09
# guardrails are present. Run by /loop-kit:loop-init after scaffolding, and
# safe to run anytime. Exits non-zero if a hard requirement is missing.
set -euo pipefail

REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$REPO_ROOT"
ok()   { printf '\033[0;32m  ok  \033[0m %s\n' "$*"; }
bad()  { printf '\033[0;31m FAIL \033[0m %s\n' "$*"; FAILED=1; }
warn() { printf '\033[0;33m warn \033[0m %s\n' "$*"; }
FAILED=0

echo "loop-kit preflight — $REPO_ROOT"

[[ -f loop.config.yaml ]] && ok "loop.config.yaml present" || bad "loop.config.yaml missing (run /loop-kit:loop-init)"
[[ -f .loop/state.md   ]] && ok ".loop/state.md present (memory on disk)" || bad ".loop/state.md missing"

# The bug we learned the hard way: loop data must NOT live under .claude/
# (the harness blocks unattended writes there).
[[ -d .claude/loop ]] && bad "loop data found under .claude/loop — harness blocks writes there; use .loop/" || ok "loop data is outside .claude/ (writable unattended)"

# §09 guardrails in config.
if [[ -f loop.config.yaml ]]; then
  grep -q "max_turns"        loop.config.yaml && ok "token cap: max_turns set"        || warn "no max_turns cap — a runaway round could burn tokens"
  grep -q "max_runs_per_day" loop.config.yaml && ok "token cap: max_runs_per_day set" || warn "no max_runs_per_day cap"
  slug="$(sed -n 's/^repo:[[:space:]]*//p' loop.config.yaml | head -1)"
  [[ -n "$slug" && "$slug" != "OWNER/NAME" ]] && ok "repo slug: $slug" || bad "repo slug not set in loop.config.yaml"
fi

# Ignore-file hygiene: .run-count gitignored; .loop/ kept out of docker images.
if git check-ignore -q .loop/.run-count 2>/dev/null; then ok ".loop/.run-count is gitignored"; else warn ".loop/.run-count not gitignored — ephemeral counter may get committed"; fi
if git check-ignore -q .loop 2>/dev/null; then warn ".loop/ is fully gitignored — memory won't persist for cloud/CI fresh-clone runs (commit state.md/config to keep continuity)"; fi
if [[ -f .dockerignore ]]; then
  grep -q "^\.loop/\?$" .dockerignore && ok ".dockerignore excludes .loop/" || warn ".dockerignore present but doesn't exclude .loop/ (run loop-init to fix)"
fi

# The evaluator (the "say no") lives in the skill, not config — note it.
ok "independent skeptic evaluator: built into the loop-triage skill"
echo "  note: human review point = the .loop/state.md Actionable list; the loop never edits code."

command -v gh >/dev/null && gh auth status >/dev/null 2>&1 && ok "gh authenticated" || warn "gh not authenticated — github-issues discovery will fail (gh auth login)"

echo
[[ "$FAILED" -eq 0 ]] && { echo "preflight: PASS"; exit 0; } || { echo "preflight: FAIL — fix the items above"; exit 1; }
