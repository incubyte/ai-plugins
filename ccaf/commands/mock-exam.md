---
description: Take a CCAF (Claude Certified Architect – Foundations) mock exam — 60 weighted questions, a scaled /1000 score, and a 720 readiness verdict. Resumable.
argument-hint: "(no args) — start or resume; 'fresh' — discard any attempt and start new"
allowed-tools: ["Read", "AskUserQuestion", "Skill", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/ccaf-exam.sh *)"]
---

## Skill Loading

Load the `ccaf-exam` skill using the Skill tool before doing anything else. It contains the
full assemble → administer → score engine, the exam-file schema, the scoring rules, and the
resume/recovery logic.

## What this command does

Administers a faithful **mock** of the Claude Certified Architect – Foundations exam so the
candidate can self-check readiness before booking the real (paid) exam. It mirrors the real
format on everything replicable (60 questions, 4 of 6 scenarios presented as case-study
sections with the case brief kept visible, machine-enforced domain weighting 27/18/20/20/15,
single-select MCQ, no penalty for guessing) and reports a scaled 100–1000 score with the 720
pass line. The scaled number is an honest estimate — not Anthropic's proprietary equating curve.

## Arguments

`$ARGUMENTS`:

- empty — start a new attempt, or offer to resume an in-progress one.
- `fresh` — discard any existing attempt and assemble a new exam.

## Flow (delegated to the ccaf-exam skill)

1. Check for an existing attempt at `~/.claude/ccaf-exam.local.md` (via `ccaf-exam.sh`).
2. Resume / start fresh / recover from a damaged file, as the skill describes.
3. Assemble a 60-question exam (seeds + verified generated questions), or continue an existing one.
4. Administer 4 questions per screen via AskUserQuestion, saving progress after each screen.
5. On completion, score and show the scaled /1000 verdict, per-domain breakdown, and disclaimer.

Honor system: untimed, self-serve, nothing shared or reported. The attempt file lives in the
user's home `~/.claude/` and is never committed.
