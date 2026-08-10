---
description: Focused CCAF domain practice — pick one or more specific domains, choose 10, 20, or 30 questions, and get a per-domain performance chart. For a full 60-item mock exam use /ccaf:mock-exam.
argument-hint: "(no args) — start or resume; 'fresh' — discard any attempt and start new"
allowed-tools: ["Read", "AskUserQuestion", "Skill", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/ccaf-exam.sh *)"]
---

## Skill Loading

Load the `ccaf-practice` skill using the Skill tool before doing anything else.

## What this command does

Focused practice mode for the CCAF exam. Choose which specific domains to drill and how many
questions you want (10, 20, or 30). Items are generated only from the selected domains,
proportionally weighted to the real exam distribution, and a quarter of them are multiple-response
so you drill that format too.

Use `/ccaf:mock-exam` for the full unmodified 60-item mock exam across all domains.

Practice attempt state is stored separately from `/ccaf:mock-exam` so the two modes never
interfere with each other.

## Arguments

`$ARGUMENTS`:

- empty — start a new attempt, or offer to resume an in-progress one.
- `fresh` — discard any existing practice attempt and start new.

## Flow (delegated to the ccaf-practice skill)

1. Check for an existing practice attempt.
2. Resume / start fresh / recover from a damaged file.
3. Ask which domains to include and how many questions.
4. Assemble the session, administer 4 items per screen, save progress after each screen.
5. Score and display a per-domain performance chart with a targeted recommendation (no scaled
   /1000 score or PASS/FAIL — a partial session isn't weighted like a real form).

Honor system: untimed, self-serve, nothing shared or reported. The practice attempt lives in
`~/.claude/` and is never committed.
