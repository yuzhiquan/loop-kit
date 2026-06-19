#!/usr/bin/env bash
# loop-kit generalized runner — runs ONE triage round against the current repo.
#
# Project-agnostic: all repo facts come from <repo>/loop.config.yaml. The plugin
# supplies the machinery + §09 guardrails (token caps, human checkpoint, writes
# to .loop/ NOT .claude/ — the harness blocks unattended writes under .claude/).
#
# Schedule it for a real (self-waking) loop:
#   /loop 1h <repo>/.loop/loop-run.sh        # local, machine on
#   GitHub Actions schedule: cron            # while you sleep / machine off
set -euo pipefail

# Repo root: prefer the harness-provided project dir, else git, else cwd.
REPO_ROOT="${CLAUDE_PROJECT_DIR:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$REPO_ROOT"

log_info()    { printf '\033[0;32m[INFO]\033[0m  %s\n' "$*"; }
log_warning() { printf '\033[0;33m[WARN]\033[0m  %s\n' "$*"; }
log_error()   { printf '\033[0;31m[ERROR]\033[0m %s\n' "$*" >&2; }

usage() {
  cat <<'EOF'
Usage: loop-run.sh [--dry-run]
Runs one loop-kit triage round (triage + propose only; never edits code).
Reads ./loop.config.yaml. Env: CLAUDE_BIN=claude
EOF
}
[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && { usage; exit 0; }
DRY_RUN=false; [[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true
CLAUDE_BIN="${CLAUDE_BIN:-claude}"

CONFIG="$REPO_ROOT/loop.config.yaml"
STATE="$REPO_ROOT/.loop/state.md"

# ---- preflight: fail fast before burning tokens -----------------------------
[[ -f "$CONFIG" ]] || { log_error "loop.config.yaml missing — run /loop-kit:loop-init"; exit 1; }
[[ -f "$STATE"  ]] || { log_error ".loop/state.md missing — run /loop-kit:loop-init"; exit 1; }

# Tiny YAML readers (flat keys / one nested level — enough for our schema).
# clean(): strip a trailing " # comment", surrounding quotes, and edge whitespace.
clean() { sed -E 's/[[:space:]]+#.*$//; s/^[[:space:]]*//; s/[[:space:]]*$//; s/^"//; s/"$//'; }
yget()  { sed -n "s/^$1:[[:space:]]*//p" "$CONFIG" | head -1 | clean; }
ynest() { awk -v p="$1" -v k="$2" '
  $0 ~ "^"p":" {inb=1; next}
  inb && /^[^[:space:]]/ {inb=0}
  inb && $0 ~ "^[[:space:]]+"k":" {sub("^[[:space:]]+"k":[[:space:]]*","");print;exit}
' "$CONFIG" | clean; }

REPO="$(yget repo)"
DISCOVERY="$(yget discovery)"
MAX_TURNS="$(ynest caps max_turns)";        MAX_TURNS="${MAX_TURNS:-30}"
MAX_RUNS="$(ynest caps max_runs_per_day)";  MAX_RUNS="${MAX_RUNS:-24}"

[[ -n "$REPO" && "$REPO" != "OWNER/NAME" ]] || { log_error "config 'repo' not set"; exit 1; }
command -v gh >/dev/null || { log_error "gh CLI not found"; exit 1; }
gh auth status >/dev/null 2>&1 || { log_error "gh not authenticated (gh auth login)"; exit 1; }

# ---- per-day run cap (token-runaway backstop) -------------------------------
COUNT_FILE="$REPO_ROOT/.loop/.run-count"
TODAY="$(date +%Y-%m-%d)"; LAST=""; COUNT=0
[[ -f "$COUNT_FILE" ]] && IFS=' ' read -r LAST COUNT < "$COUNT_FILE" || true
[[ "$LAST" != "$TODAY" ]] && COUNT=0
if (( COUNT >= MAX_RUNS )); then
  log_error "Daily run cap reached ($COUNT/$MAX_RUNS for $TODAY). Refusing."; exit 1
fi

PROMPT="Run the loop-triage skill for this repo (repo=$REPO, discovery=$DISCOVERY).
Load loop.config.yaml, discover work, draft fix proposals, run the independent
skeptic evaluator, and record results in .loop/state.md. Propose only — do not
edit code, run git, or open PRs. Print the 3-line summary and stop."

if $DRY_RUN; then
  log_info "[dry-run] repo=$REPO discovery=$DISCOVERY max-turns=$MAX_TURNS cap=$MAX_RUNS"
  log_info "[dry-run] prompt:"; printf '%s\n' "$PROMPT"; exit 0
fi
command -v "$CLAUDE_BIN" >/dev/null || { log_error "$CLAUDE_BIN not on PATH"; exit 1; }

log_info "Triage round starting for $REPO (run $((COUNT+1))/$MAX_RUNS today, max-turns=$MAX_TURNS)"
# acceptEdits auto-accepts file writes (no prompt); allowlist permits only triage
# tools + writes; git/PR/issue-mutation tools are explicitly denied.
"$CLAUDE_BIN" -p "$PROMPT" \
  --max-turns "$MAX_TURNS" \
  --permission-mode acceptEdits \
  --allowedTools "Bash(gh issue list:*),Bash(gh issue view:*),Bash(gh run list:*),Grep,Glob,Read,Edit,Write" \
  --disallowedTools "Bash(git:*),Bash(gh pr:*),Bash(gh issue edit:*),Bash(gh issue comment:*),WebFetch"

printf '%s %d\n' "$TODAY" "$((COUNT+1))" > "$COUNT_FILE"
log_info "Round done. Review proposals in .loop/state.md (Actionable section)."
