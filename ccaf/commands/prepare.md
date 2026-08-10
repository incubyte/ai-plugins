---
description: Learn the CCAF (Claude Certified Architect – Foundations) syllabus conversationally — a patient coach teaches one concept per turn and checks your understanding every turn. Untimed, adaptive, resumable.
argument-hint: "(no args) — pick topics from a menu; or a domain/topic, e.g. 'D4' or 'tool descriptions'"
allowed-tools: ["Read", "Glob", "Grep", "AskUserQuestion", "Skill", "Task"]
---

## Skill Loading

Load the `ccaf-tutor` skill using the Skill tool before doing anything else. It contains the
full teaching engine: the topic menu, the per-turn loop (hook → one concept →
visualize-if-useful → check → adapt), the hybrid check strategy, the curriculum mapping, and the
two-way handoff with `/ccaf:mock-exam`.

## What this command does

Runs a conversational, turn-by-turn tutor for the Claude Certified Architect – Foundations exam.
It teaches **one small idea at a time** and **verifies understanding every turn** through
retrieval (apply / predict / critique), adapting pace and difficulty to the learner. It is the
*formative* companion to `/ccaf:mock-exam`: `prepare` builds readiness; the mock exam gates it.

The curriculum is the blueprint (5 domains, 30 task statements D1.1–D5.6, 6 scenarios), and the
prep guide supplies study routes plus four hands-on exercises the tutor can assign at domain
boundaries. Teaching stays strictly inside the blueprint's in-scope list.

## Arguments

`$ARGUMENTS`:

- empty — show a multi-select topic menu (the syllabus as topic clusters with short
  descriptions); the learner picks what to learn, and the journey starts on those topics.
- a domain (`D1`–`D5`) or a topic phrase (e.g. `tool descriptions`, `plan mode`, `escalation`) —
  start there directly. This is also the entry point a `/ccaf:mock-exam` FAIL recommends for a
  weak domain.

## Flow (delegated to the ccaf-tutor skill)

1. Read the blueprint as the curriculum, and the prep guide for routes and exercises.
2. Show the topic menu and let the learner pick (or jump straight to the requested domain/topic
   from `$ARGUMENTS`).
3. Teach one task statement per turn: hook → concept (+ anti-pattern) → visualize only if it
   helps → check → adapt.
4. Use inline checks for light recall; spawn the `ccaf-check-author` agent (via Task) for
   apply-to-scenario checks — single-answer or "Select TWO" — so the main thread stays lean. Read
   confidence with "why that one?".
5. Track what's solid vs. shaky; show the map on request; offer a hands-on exercise at domain
   boundaries; recommend `/ccaf:practice` then `/ccaf:mock-exam` when a domain looks solid.

Untimed and conversational. Stateless — Claude Code's native session resume carries continuity;
nothing is written to disk.
