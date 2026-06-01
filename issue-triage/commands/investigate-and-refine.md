---
description: Lightweight triage — investigate and refine the title/description only. No assignment, no transition, no severity write, no escalation. Useful when you want to clean up a ticket without committing to the full triage cycle.
argument-hint: <issue URL or ID>
allowed-tools: Skill
---

# /issue-triage:investigate-and-refine

A reduced version of the `issue-triage` agent. Runs the investigation and refinement phases only.

## Examples

```
/issue-triage:investigate-and-refine https://dev.azure.com/contoso/payments/_workitems/edit/12345
/issue-triage:investigate-and-refine RLI-1234
```

## What it does

Dispatches to the `issue-triage` agent with `mode=investigate-and-refine`. The agent runs:

1. **Phase 0** — Identify the issue, detect archetype.
2. **Phase 1** — Investigate (Bug/Incident or Story/Feature/Task/Spike).
3. **Phase 2** — Search Datadog (Bug/Incident only).
4. **Phase 3** — Diff-and-confirm gate. The batch contains only the title and description writes from Phase 5. Severity, transitions, comments, links, labels are **not** in this batch.
5. **Phase 5** — Refine title and description on confirmation.

What this command **does not** do:

- No assignment changes.
- No state transitions.
- No assessment comments.
- No severity, due-date, sprint, or story-point updates.
- No linking related work.
- No `triaged` label.
- No escalation channel posts.

## When to use this vs `/issue-triage:run`

| Use this | Use `/issue-triage:run` |
|---|---|
| The reporter wrote a vague title and you want to clean it up | You're picking up the issue and committing to own it through triage |
| You're auditing a backlog for description quality | The issue is fresh and needs the full classification + assignment workflow |
| You want to preview the agent's rewrite without touching state | The team relies on the `triaged` label to filter |

## Configuration

Same as `/issue-triage:run`: reads `.claude/tracker-policy.json`. Lazy-prompts only the keys this reduced workflow uses (which is just `skip_labels` — to honor opt-outs).
