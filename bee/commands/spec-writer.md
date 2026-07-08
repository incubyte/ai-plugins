---
description: Spec authoring link of Bee's plan-driven chain. Produces a testable, slice-decomposed spec from a discovery doc, a focused conversation, or a task description — via bee's spec-builder agent, which interviews the developer and writes docs/specs/[feature]-spec.md. Use when the user runs /bee:spec-writer, says "write a spec", "draft the requirements", "turn discovery into a spec", "spec out this feature", or has been routed here by /bee:start. Hands off to /bee:planner (which authors the execution plan, then hands to /bee:plan-implementer).
argument-hint: "[optional discovery doc path, existing spec path, or task description; optional ROUTED FROM context note]"
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/update-bee-state.sh *)", "AskUserQuestion", "Skill", "Task"]
---

# /bee:spec-writer

The spec link of the chain — `/bee:start → /bee:spec-writer → /bee:planner → /bee:plan-implementer`. Produces a human-readable spec that carries **intent only**: what the behavior is, sliced into vertical, testable increments. No model names, no per-slice tiers, no execution routing — those live in the plan (`/bee:planner`'s job).

## How to work

1. **Read the `ROUTED FROM` note when present** (from `/bee:start`): process tier, risk, high-risk surface touched, codebase observations, design direction, provisional elicitation questions. Use the provisional questions as the starting elicitation set — do not re-ask what start already answered. When invoked manually without a note, work from the argument (a discovery doc path, an existing spec to revise, or a task description).

2. **Delegate to the spec-builder agent** via Task (at `best`, resolved via the `model-tiers` skill and passed explicitly as the Task `model` parameter). Pass: the task description or discovery doc path, the triage signals, and the design direction. The agent interviews the developer (risk-scaled depth), slices vertically, writes the spec to `docs/specs/[feature]-spec.md`, and gets confirmation. **Bug-fix mode** (routed from a high-risk-surface trivial fix): the spec is lean — the defect, the expected behavior, the reproducing test's shape, and one slice.

3. **Run the Collaboration Loop** on the spec (load the `collaboration-loop` skill) — the `[ ] Reviewed` gate and `@bee` annotation handling.

4. **→ Update state:** `"${CLAUDE_PLUGIN_ROOT}/scripts/update-bee-state.sh" set --phase-spec "[spec-path] — confirmed"`

## Hand off

Tell the user: the spec location, what's next in the chain (`/bee:planner` to author the execution plan, which hands to `/bee:plan-implementer`), and that anyone can run `/bee:spec-writer` against this spec later to revise or extend. Do not pronounce the spec ready — the user owns that call.

**Hand off to `/bee:planner`.** When the spec is written and the user is ready to proceed (not parking it for review), invoke the `bee:planner` skill via the Skill tool with a context note carrying the spec path plus any inherited triage signals (`Process tier`, `Risk`, `High-risk surface touched`, `Design direction`). Planner authors the execution plan on the `best` tier — the prescriptive *how* (per-slice structure, control flow, test strategy, standards, build tier) — then hands to `/bee:plan-implementer`.

**A Skill handoff ends your turn — place nothing after it.**

## What NOT to do

- Do not put model names, tiers, or execution routing in the spec — the spec carries intent only.
- Do not author the plan — that is `/bee:planner`.
- Do not skip the collaboration loop — full-tier work exists precisely because human intent sign-off is needed.
- Do not answer the spec-builder's AskUserQuestion prompts on the developer's behalf.

Follow CLAUDE.md conventions for navigation style, teaching level, and personality.
