---
description: Summarize the current repo's loop state — Actionable / Parked / Done counts and the latest round.
disable-model-invocation: true
---

# loop-kit: status

Summarize the triage loop's memory for the current repository.

1. Read `${CLAUDE_PROJECT_DIR}/.loop/state.md`. If missing, say the loop isn't
   set up and point to `/loop-kit:loop-init`.
2. Report:
   - count of **Actionable** items, with their issue numbers + one-line titles
   - count of **Parked** items (just the count + numbers)
   - the most recent **Round log** entry
3. If there are Actionable items, remind the user these are proposals awaiting
   THEIR judgment (the loop proposes; the human decides). Do not act on them.
