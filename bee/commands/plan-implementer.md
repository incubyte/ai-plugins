---
description: Canonical plan executor. Implements an execution plan one merged build agent per slice (tests + code together, at each slice's plan-assigned model tier), then reviews and verifies once at the end. Use when the user runs /bee:plan-implementer, says "implement the plan", "build the plan", "run the plan", or has been handed off from /bee:planner. Reads a plan at docs/plans/<feature>-plan.md.
argument-hint: <plan path, or empty to find the most recent plan under docs/plans/>
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/update-bee-state.sh *)", "Bash(git:*)", "Bash(npm:*)", "Bash(npx:*)", "Bash(yarn:*)", "Bash(pnpm:*)", "Bash(bun:*)", "Bash(make:*)", "Bash(mvn:*)", "Bash(gradle:*)", "Bash(dotnet:*)", "Bash(cargo:*)", "Bash(go:*)", "Bash(pytest:*)", "Bash(python:*)", "Bash(date:*)", "AskUserQuestion", "Skill", "Task", "TaskCreate", "TaskUpdate", "TaskList"]
---

# /bee:plan-implementer

Turn a finished plan into reviewed, verified code in three moves: **implement → review → verify**. The plan and spec already did the thinking; this command executes cheaply.

One `slice-builder` spawn per slice at the slice's plan-assigned tier, then — once, at end-of-spec, over the whole diff — the end-of-spec review pass (the risk-aware `reviewer` plus the plan-selected `review-*` dimensions), all in parallel. No per-slice reviewer fleet. No separate build-then-review split per slice.

## State Tracking

Use `${CLAUDE_PLUGIN_ROOT}/scripts/update-bee-state.sh` for all state writes (load the `bee-state` skill). Never Write/Edit `.claude/bee-state.local.md` directly.

## Step 1: Locate the plan and its artifacts

- Plan: the argument, or Glob `docs/plans/*-plan.md` and take the most recent (confirm via `AskUserQuestion` if several).
- From the plan's `<feature>` name, locate the spec (`docs/specs/<feature>-spec.md`, full tier) and the context file (`.claude/bee-context.local.md`).
- Ensure a context file exists at the current HEAD. If missing or stale (its stamped HEAD no longer matches `git rev-parse HEAD`), spawn the existing **context-gatherer** agent to (re)generate it and save its output with the **Write** tool, stamped with the current HEAD — the same reuse contract `/bee:planner` uses. Do not write orientation logic here.
- Record the current HEAD (`git rev-parse HEAD`) as the **pre-implementation marker** — the end-of-spec review diffs against it in Step 3.
- Load the `model-tiers` skill and be ready to resolve each slice's tier to its concrete subagent model value.

Surface a one-line summary — *"Implementing plan `<feature>` — N slices, each on its plan-assigned tier, review at end."*

## Step 2: Implement (one spawn per slice, at the plan's per-slice tier)

Build slices **in plan order, one spawn per slice**, each at that slice's plan-assigned model tier. A sub-agent's model is fixed for its whole run, so honoring the plan's per-slice tiers requires one `slice-builder` spawn per slice — this is the mechanical binding that keeps model choice driven by the plan, not improvised at spawn time.

For each slice, in plan order:

1. **Read the slice's tier from the plan** (planner field 9 — `Build-agent tier`). Resolve that tier alias to its concrete subagent model value via the `model-tiers` skill — the single source of truth for the tier→model mapping (never restate the mapping here).
2. **Spawn `slice-builder`** (Task tool, `subagent_type: slice-builder`, **`model` = the value resolved in step 1 — pass it explicitly; never inherit the orchestrator's own session model**). Pass: the slice number, the plan path, the spec path (full tier), the context-file path, and `.claude/bee-architecture.local.md` / `.claude/DESIGN.md` when present. Track the slice with a task (TaskCreate/TaskUpdate) and update state (`... set --current-slice "Slice N — building"`).
3. The agent implements **that one slice**: writes the plan-specified tests, confirms red, writes the code, runs the slice's scoped test set to green, ticks the slice's ACs, commits the slice. It does **not** review — that is Step 3. Wait for it to hand back, then proceed to the next slice.

**The model is data from the plan, not a choice made here.** Do not default to the session's model. Do not run every slice on the same tier unless the plan assigned every slice the same tier. Each slice runs at the tier the plan assigned it, resolved through the `model-tiers` skill — a `fast` slice and a `best` slice run on different models even within the same build.

**Escalation ratchet (one-way tier bump).** If a slice cannot reach green within its retry budget, first bump the slice's tier **exactly one step up** the ladder `fast → excellent → best` and re-spawn the builder at the higher tier. Every bump appends a row to the plan's **Escalation Log** (slice ID, agent, from→to tier, reason, `date` timestamp — Edit the plan file). A tier never moves down within a run. If the slice is already at `best`, follow the risk-scaled retry budget (LOW → 5, MODERATE → 10, HIGH → 15 fix iterations), then surface the diagnostic and `AskUserQuestion` — retry the failing slice / accept partial and proceed to review on what landed / cancel. Do not build a later slice on top of a failed earlier one.

## Step 3: Review at the end (single pass, once)

Run review **once** over the whole diff — never per slice.

**Spawn all reviewers in one message so they run in parallel**, each at its plan-assigned tier (resolved via `model-tiers`, passed explicitly):

- **Spawn `reviewer`** (always). Pass: the final diff (`git diff` against the pre-implementation marker), paths to spec / plan / architecture file / context file, the plan's per-slice **Quality checks**, the risk level, and the **plan's hard-floor markings** (which slices/surfaces are floored) so the reviewer enforces the security dimension unconditionally on floored surfaces at a tier ≥ `excellent`. It covers the holistic dimensions in one pass with a risk-aware ship recommendation.
- **Spawn `review-coupling`** when any slice is floored — architecture/boundary enforcement (import dependencies, change amplifiers, boundary leaks) over the floored surfaces at ≥ `excellent`.
- **Spawn each additional `review-*` agent the plan's End-of-spec review section selected**, with the diff and artifact paths.

Surface a one-line status — *"Reviewing: reviewer + <selected dimensions>."* — then wait for all reviewers to hand back findings. Aggregate, dedupe (the same underlying issue on the same `file:symbol` flagged by multiple reviewers is one finding — cite them together), sort HIGH first. Hard-floored reviewers always run, even if a plan row looks inconsistent.

## Step 4: Verify and resolve

- Run the full test suite once as a Bash one-shot — the end-of-spec gate. It catches cross-slice damage the per-slice scoped runs cannot.
- **Browser verification (only when the spec has UI slices).** After the suite gate, spawn **browser-verifier** (Task tool, at `fast`, dev mode). Pass: the spec path, the UI slices' acceptance criteria, `.claude/DESIGN.md` when present, and the base URL of the already-running app. It drives the running app in a browser and returns findings in the reviewer's severity shape. Skip this entirely for backend-only specs. If no browser MCP is connected or the app is not running, it degrades to a manual checklist and reports `SKIPPED` — surface that in the summary; do not block hand-off.
- **Act on findings — reviewer and browser-verifier findings share ONE resolution loop:** HIGH → re-spawn `slice-builder` (escalation ratchet applies) to fix, then **re-run the source that raised it** — the affected reviewer for a review finding, the browser-verifier (naming just the fixed finding) for a browser finding; MED → fix if trivial, else note on the spec/plan as a follow-up; LOW → note only.
- **A browser finding is closed only when re-verification passes** — never on "code looks right" or a green unit suite alone; that is the point of verifying in a browser. If re-verification cannot execute (app down, browser MCP disconnected, rebuild didn't settle), keep the finding OPEN and list it explicitly in the summary as `unverified (fix applied, not confirmed)` — never auto-pass it.
- Surface the run summary: slices completed, ACs ticked, test result, browser-verification result (or `SKIPPED`/`UNVERIFIED` items), findings by severity, escalations logged, what (if anything) remains.

**→ Update state:** `... set --current-phase "done — shipped"` when clear.

## Hand off

Tell the user: build complete (or stopped at slice X), suite status, findings summary, branch ready for manual review / PR. Do not pronounce it ready to merge — the user owns that call.

A recap is available on demand via the `recap` agent when the user asks for a walkthrough; do not spawn it unprompted.

## Notes

- One `slice-builder` per slice at its plan-assigned tier; the end-of-spec review (reviewer + plan-selected `review-*` dimensions) runs once over the whole diff, all in parallel — no per-slice reviewer fleet, no separate build-then-review split per slice.
- Browser verification (`browser-verifier`) also runs once at end-of-spec, only for UI specs, over the running app — the browser analogue of the single end-of-spec review. Its findings share the review's resolution loop; a browser finding closes only when re-verification confirms it in the browser (never on unit-green alone). It assumes the dev server is already running and degrades to a manual checklist (never a silent pass) when no browser MCP is connected.
- Each slice's build runs at **its plan-assigned tier** (a sub-agent's model is fixed per run, so the per-slice tier is honored by spawning once per slice). The tier is read from the plan and resolved through the `model-tiers` skill, never the orchestrator's own session model — that is what keeps a `fast` slice on its own tier even when the orchestrating session runs at the `best` tier.
- To revise the plan itself, re-run `/bee:planner` against the same spec — plan-implementer never re-plans.

Follow CLAUDE.md conventions for navigation style, teaching level, and personality.
