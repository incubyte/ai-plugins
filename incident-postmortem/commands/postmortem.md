---
description: Generate a Google-SRE-style blameless postmortem for an incident issue. Pass the URL or ID; the agent gathers evidence, builds a timeline, asks once before generating, and produces the document.
argument-hint: <incident URL or ID>
allowed-tools: Skill
---

# /incident-postmortem:run

Entry point for the `incident-postmortem` agent. Pass the incident's tracker URL or ID as the argument.

## Examples

```
/incident-postmortem:run https://dev.azure.com/contoso/payments/_workitems/edit/12345
/incident-postmortem:run https://contoso.atlassian.net/browse/INC-456
/incident-postmortem:run INC-456
/incident-postmortem:run 12345
```

## Behavior

This command is a thin shell. It dispatches to the `incident-postmortem` agent with the URL/ID as the input. The agent runs the full six-phase workflow:

1. Identify the incident from the URL/ID; resolve which tracker via `issuekit:tracker-adapter`.
2. Gather evidence in parallel (tracker history, related issues, chat threads, deploys, Datadog logs).
3. Build the timeline via `incident-timeline-builder`.
4. Pause for the user to confirm scope.
5. Generate the postmortem via `postmortem-writer`; clean via `issuekit:prose-style`.
6. Render inline; optionally save to the configured `output_directory`.

The agent is read-only on the tracker. It never modifies the incident, comments on it, or transitions it. See the agent prompt (`agents/incident-postmortem.md`) for the detailed contract.

## Configuration

Reads `.claude/tracker-policy.json` if present. Falls back to defaults when missing:

- `output_directory: "./docs/postmortems/"`
- `postmortem_template: "google-sre"`
- `incident_identifier: { tag: "incident", work_item_types: ["Issue", "Bug", "Incident"] }`

Any missing key is lazy-prompted at the moment it's needed and (with your confirmation) persisted to `.claude/tracker-policy.json`.
