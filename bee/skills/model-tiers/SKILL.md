---
name: model-tiers
description: "This skill should be used when an orchestrator needs to choose or resolve a model for a delegated agent — i.e. by /bee:planner when authoring a plan (assigning a capability tier per agent per slice) and by /bee:plan-implementer when executing one (resolving a tier to a concrete subagent model value). Contains the single source of truth mapping capability tiers (best / excellent / fast) to Claude Code subagent model values, with per-tier guidance for picking the right one. Load this skill instead of hardcoding any model name."
---

# Model tiers — the single source of truth

Bee references models only by **capability tier**, never by concrete model name. This file is the one place that maps a tier to a model. Changing the model lineup means editing only this file — no command, skill, plan, or routing decision names a model. (A few agents carry a `model:` frontmatter default for `/bee:sdd`'s fixed loop; under the /bee:start → /bee:planner → /bee:plan-implementer chain the plan-resolved value passed at dispatch time always overrides it.)

`/bee:planner` writes tiers into the plan (`docs/plans/<feature>-plan.md`); `/bee:plan-implementer` then resolves a tier to the value below and passes it as the model when spawning an agent via the Task tool. No spec, agent prompt, command, or routing decision ever names a concrete model.

## The tiers

| Tier | Subagent model value | Model | Use it for |
|---|---|---|---|
| `best` | `opus` | Claude Opus (latest) | Most complex reasoning and agentic coding |
| `excellent` | `sonnet` | Claude Sonnet (latest) | The default coding tier — speed and intelligence |
| `fast` | `haiku` | Claude Haiku (latest) | High-volume, low-complexity work where speed matters |

The model value (`opus` / `sonnet` / `haiku`) is the Claude Code subagent alias; it resolves to the current generation of that model line, so the table tracks the lineup without pinning a dated ID.

## Tier definitions

### `best`

> The most capable tier for complex reasoning and agentic coding.

The brain of the chain runs at `best`: `/bee:start` triages the work and `/bee:planner` authors the plan once per feature, so the single most consequential reasoning step gets the strongest model. Assign `best` to a slice's agents when the logic is genuinely hard — non-trivial algorithms, state machines, intricate coordination, new abstractions the slice must design, or security/auth/payment/migration surfaces where a subtle mistake is expensive.

### `excellent`

> The best combination of speed and intelligence.

The default coding tier. Assign `excellent` to slice agents doing standard implementation work — the bulk of features and well-understood changes. Strong enough to produce good code when well-fed by the plan and context, cheaper and faster than `best`. When in doubt for a coding/testing/review agent, use `excellent`.

### `fast`

> The fastest tier with near-frontier intelligence.

Assign `fast` to high-volume, low-complexity work where latency and cost dominate and the task shape is obvious — CRUD passthrough, rendering an existing field, wiring an existing utility, localized edits, mechanical refactors, or a verifier checking a trivial slice.

## How resolution works

1. A tier (`best` / `excellent` / `fast`) appears in a plan or an orchestrator instruction.
2. `/bee:plan-implementer` looks the tier up in the table above and reads its subagent model value.
3. That value is passed **explicitly** as the `model` parameter on the Task tool when the agent is spawned (Claude Code subagent `model` field — accepts `opus` / `sonnet` / `haiku`, a full model ID, or `inherit`). Never let an agent inherit the orchestrator's own session model — the orchestrator runs at `best`, so an inherited model silently runs every slice at `best` and defeats the cost model. The agent's own `model:` frontmatter is the fallback when no override is passed; the plan-assigned tier takes precedence at execution time.

## The escalation ladder

Tiers are ordered: `fast` < `excellent` < `best`. Escalation is one-way and moves exactly one step up the ladder (`fast` → `excellent` → `best`). A tier at `best` cannot escalate further. A tier never moves down within a run. See `/bee:plan-implementer`'s escalation ratchet.

## Changing the lineup

When the model lineup moves (a new Opus generation ships, a tier should point at a different line), edit **only the table and definitions above**. Because no other skill, agent, command, or plan hard-codes a model, this file is the sole edit point — the rest of the plugin keeps working unchanged.
