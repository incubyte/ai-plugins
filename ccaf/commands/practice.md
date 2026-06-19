---
description: Focused CCAF domain practice — pick one or more specific domains, choose 10, 20, or 30 questions, and get a scaled score with a per-domain breakdown. For a full 60-question mock exam use /ccaf:mock-exam.
argument-hint: "(no args) — start or resume; 'fresh' — discard any attempt and start new"
allowed-tools: ["Read", "AskUserQuestion", "Skill", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/ccaf-exam.sh *)"]
---

## Skill Loading

Load the `ccaf-practice` skill using the Skill tool before doing anything else.

## What this command does

Focused practice mode for the CCAF exam. Choose which specific domains to drill and how many
questions you want (10, 20, or 30). Questions are generated only from the selected domains,
proportionally weighted to the real exam distribution.

Use `/ccaf:mock-exam` for the full unmodified 60-question mock exam across all domains.

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
4. Assemble the exam, administer 4 questions per screen, save progress after each screen.
5. Score and display a scaled /1000 result with per-domain breakdown.

Honor system: untimed, self-serve, nothing shared or reported. The practice attempt lives in
`~/.claude/` and is never committed.
