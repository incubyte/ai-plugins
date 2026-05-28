# incident-postmortem

Generates a Google-SRE-style blameless postmortem from a resolved incident issue on any supported tracker. Tracker-agnostic via [`issuekit`](../issuekit/).

## Plug-and-play contract

Plug-and-play in this suite = `issuekit` + `incident-postmortem` + your own MCPs. This plugin ships **no** `.mcp.json` and bundles **no** vendor config. The tracker-adapter resolves which tracker is active by inspecting the tools the user has registered.

## Install

```
/plugin install incident-postmortem@incubyte-plugins
```

`issuekit` is declared as a dependency and Claude Code auto-installs it for you.

You also need at least one tracker MCP:

- **Azure DevOps:** the official `@azure-devops/mcp` from Microsoft.
- **Jira:** the Atlassian remote MCP.

Optional MCPs the agent uses opportunistically:

- A chat MCP for incident threads — Slack or Teams.
- A docs MCP for runbooks — Confluence or Azure Wiki.
- The Datadog MCP for log search.

If a backend isn't installed, the agent skips that gathering step and notes the gap once in the final summary.

## Use

```
@incident-postmortem <incident URL or ID>
```

or the slash-command shorthand:

```
/incident-postmortem:run <incident URL or ID>
```

The agent runs read-only on the tracker. It does not modify the incident, comment on it, or transition it. Output is a markdown document the user reviews and (optionally) saves to a configured directory.

## Workflow

Six phases, with confirmation gates only where the user actually has a decision to make.

| Phase | What happens | User involvement |
|---|---|---|
| **0. Identify** | Resolve the incident from URL/ID; validate it's an incident; compute the time window. | none (unless type doesn't match `incident_identifier` config — then asks Generate Anyway / Cancel) |
| **1. Gather** | Parallel evidence collection: tracker history, related issues, chat threads, deploys, Datadog logs. | none |
| **2. Timeline** | Build chronological timeline via the `incident-timeline-builder` skill. Every event carries a UTC timestamp, source citation, and evidence tag. | none |
| **3. Review** | Show the proposed timeline truncated to the first 10 events; ask the user to confirm scope before generating. | confirmation gate |
| **4. Generate** | Run `postmortem-writer` to assemble the full document using the Google-SRE-style blameless template; clean with `issuekit:prose-style`. | none |
| **5. Save** | Render the postmortem inline; optionally save to `output_directory`. | save prompt |

## Configuration

Read from `.claude/tracker-policy.json`. The keys this plugin cares about:

- `output_directory` — where postmortems are saved. Default: `./docs/postmortems/`.
- `postmortem_template` — `"google-sre"` is the only supported value in v1.0.0.
- `incident_identifier` — `{tag, work_item_types}` used to identify incident-type issues vs. other tracker artifacts.

When `.claude/tracker-policy.json` is absent, defaults are used and the agent lazy-prompts for any key it needs, offering to persist the answer.

When a legacy `.claude/azure-incident-postmortem.config.json` exists, the agent reads it forward for the session and warns once. To stop the warning, translate the values into `.claude/tracker-policy.json` and delete the legacy file.

## Plugin-bundled skills

| Skill | Purpose |
|---|---|
| `incident-timeline-builder` | Reconstructs a chronological event timeline from gathered evidence; output is a markdown table with timestamp, event, source, evidence tag. |
| `postmortem-writer` | Generates the full postmortem markdown using the Google-SRE-style template. |

The agent also invokes `issuekit:tracker-adapter` (for every tracker read) and `issuekit:prose-style` (to clean the generated document).

## Legacy config import

If your project still has `.claude/azure-incident-postmortem.config.json` from a previous version of this marketplace, the agent reads it forward for the session with a one-time warning. To stop the warning, translate the values into `.claude/tracker-policy.json` (shape documented in [`issuekit/skills/tracker-adapter/references/policy-schema.md`](../issuekit/skills/tracker-adapter/references/policy-schema.md)) and delete the legacy file.
