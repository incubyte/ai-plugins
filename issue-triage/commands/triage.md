---
description: Full end-to-end issue triage. Investigates, refines title/description, sets severity/sprint, links related work, applies the triaged label, and posts a summary. All writes pass through a single diff-and-confirm gate.
argument-hint: <issue URL or ID>
allowed-tools: Skill
---

# /issue-triage:run

Entry point for the `issue-triage` agent. Pass the issue's tracker URL or ID as the argument.

## Examples

```
/issue-triage:run https://dev.azure.com/contoso/payments/_workitems/edit/12345
/issue-triage:run https://contoso.atlassian.net/browse/RLI-1234
/issue-triage:run RLI-1234
/issue-triage:run 12345
```

## Behavior

This command is a thin shell. It dispatches to the `issue-triage` agent with the URL/ID as the input. The agent runs the full ten-phase workflow:

1. Identify the issue and detect archetype via `issuekit:tracker-adapter`.
2. Investigate (Bug/Incident → `issuekit:issue-investigator`; Story/Feature/Task/Spike → `requirements-investigator`).
3. Search Datadog (Bug/Incident only, when `log != none`).
4. Build the diff-and-confirm batch covering everything the agent intends to write.
5. **Pause at the diff-and-confirm gate.** User confirms or declines.
6. On confirm: post the assessment comment, refine title/description, set severity + due date or sprint + story points, link related work, apply the triaged label, run the final transition, notify the escalation channel if configured.

The diff IS the dry-run. Declining at the gate exits cleanly with no writes.

## Configuration

Reads `.claude/tracker-policy.json` if present. Lazy-prompts for any missing policy key at the moment it's needed (typically `states.investigating`, `severity_scheme`, `escalation.channel`) and offers to persist the answer.

## See also

- `/issue-triage:investigate-and-refine` — lightweight subset that only investigates and refines title/description; no field updates, no transitions, no escalation.
