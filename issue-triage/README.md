# issue-triage

End-to-end issue triage on any supported tracker. Replaces both `azure-issue-triage` and `jira-issue-triage` with a single tracker-agnostic plugin powered by [`issuekit`](../issuekit/).

## Plug-and-play contract

Plug-and-play in this suite = `issuekit` + `issue-triage` + your own MCPs. This plugin ships **no** `.mcp.json` and bundles **no** vendor config.

## Install

```
/plugin install issue-triage@incubyte-plugins
```

`issuekit` is declared as a dependency and Claude Code auto-installs it for you.

You also need at least one tracker MCP:

- **Azure DevOps:** the official `@azure-devops/mcp` from Microsoft.
- **Jira:** the Atlassian remote MCP.

Optional MCPs the agent uses opportunistically:

- A chat MCP for thread search and escalation pings — Slack or Teams.
- A docs MCP for runbooks — Confluence or Azure Wiki.
- The Datadog MCP for log search (Bug and Incident only).

If a backend isn't installed, the agent skips the corresponding step and notes the gap once in the final summary.

## Use

```
@issue-triage <issue URL or ID>
```

or the slash-command shorthands:

```
/issue-triage:run <URL or ID>
/issue-triage:investigate-and-refine <URL or ID>
```

The `:run` form runs the full workflow (investigation → refinement → field updates → assignment → notification). The `:investigate-and-refine` form is a lightweight subset that only investigates and refines the title/description; it does not assign, transition, set severity, or escalate.

## Diff-and-confirm gate (the dry-run)

Phase 3 of the workflow is a single confirmation gate. Before any write happens, the agent shows you a markdown table of every change about to land:

| # | Verb | Field / target | Before | After |
|---|---|---|---|---|
| 1 | updateFields | title | "Bug" | "VMS: Visitor notifications not sending for scheduled visits" |
| 2 | updateFields | body | (current description, abridged) | (new markdown body, abridged) |
| 3 | transition | state | "New" | "investigating" → "Active" (reason: Investigating) |
| 4 | assign | assignee | unassigned | <running user> |
| 5 | addComment | new comment | — | "Investigation underway. Findings: ..." |
| 6 | addLabel | tags | — | + triaged |

You confirm once. The diff IS the dry-run — decline to abort cleanly.

## Workflow

The agent runs ten phases. Phase 3 is the only confirmation gate (Phase 0 has a halt for issue-type mismatches, but that's an early-exit, not a write gate).

| Phase | What happens |
|---|---|
| **0. Identify** | Fetch the issue. Detect archetype (Bug / Incident / Story / Feature / Task / Spike). Skip if it carries any `skip_labels`. |
| **1. Investigate** | Bug or Incident: run `issuekit:issue-investigator` (chat → tracker+docs → Datadog → code). Story/Feature/Task/Spike: run `requirements-investigator` (bundled). |
| **2. Datadog (Bug/Incident only)** | Build queries from investigation signals; gather error patterns. Skip if `log == none`. |
| **2.5. Gap analysis** | When the investigation has `[UNKNOWN]` items that need reporter input, prepare the follow-up question for Phase 4c. |
| **3. Confirmation gate** | Show the full diff. User confirms or declines. **No writes have happened yet.** |
| **4a / 4b / 4c. Post comment** | Bug/Incident: assessment comment with hypotheses + Where To Look. Story/Feature/etc: scope summary. Vague issues: follow-up question pinging the reporter. |
| **5. Refine** | Update title and description using the archetype template. Body markdown goes through the adapter's body-format converter. |
| **6. Severity + dates** | Bug/Incident: severity + due date. Story/Feature/Task/Spike: sprint + story points. |
| **7. Link** | Surface duplicate/related candidates from the investigation. Link PRs that mention the issue ID (AzDO only — Jira auto-links). |
| **8. Label** | Append the `triaged_label`. |
| **9. Final transition** | Bug → unassign + transition to backlog (or `waiting_reply` if a follow-up was posted). Others → keep assigned to self. |
| **10. Notify** | Post a one-line summary to the chat channel if `escalation.channel` is configured. Print inline summary either way. |

Phases 4–9 run only on Phase 3 confirmation. They execute as a batch through the diff-and-confirm gate; on the first failure, the batch stops and surfaces the partial state.

## Archetype taxonomy

| Archetype | AzDO types it matches | Jira types it matches |
|---|---|---|
| Bug | `Bug` | `Bug`, `Defect` |
| Incident | `Issue` (Agile) / `Impediment` (Scrum); with `incident` tag/label | `Incident`, `Outage`, anything tagged `incident` or `Sev-` |
| Story | `User Story` (Agile), `Product Backlog Item` (Scrum), `Requirement` (CMMI) | `Story`, `Feature`, `Enhancement`, `New Feature` |
| Feature | `Feature` | `Feature` (when not classified as Story) |
| Task | `Task` | `Task`, `Sub-task`, `Chore`, `Tech Debt` |
| Spike | `Task` with `spike` tag | `Spike`, `Research`, `Investigation` |

## Configuration

Read from `.claude/tracker-policy.json`. The keys this plugin uses:

- `states.investigating`, `states.waiting_reply`, `states.backlog` — abstract state mapping.
- `severity_scheme` — `sev1..sev4` → `{due_offset_days, escalate_immediately}`.
- `severity_label_map` — abstract tier → vendor label candidates.
- `escalation.{channel, primary_contact, fallback_contact}` — chat escalation.
- `skip_labels` — labels that opt an issue out.
- `triaged_label` — label appended after a successful run.
- `archetype_assignment_after_triage` — per-archetype assign-to policy.

When the file is absent, the agent uses defaults and lazy-prompts at the moment it encounters an unset key. Defaults are listed in [`issuekit/skills/tracker-adapter/references/policy-schema.md`](../issuekit/skills/tracker-adapter/references/policy-schema.md).

Legacy config files (`.claude/azure-issue-triage.config.json`, `.claude/jira-issue-triage.config.json`, `.claude/jira-bug-triage.config.json`) are read forward for the session with a one-time warning. To stop the warning, translate the values into `.claude/tracker-policy.json` and delete the legacy file. Lazy prompts persist any missing keys after that.

## Plugin-bundled skills

| Skill | Purpose |
|---|---|
| `issue-refiner` | Re-writes title and description into the archetype-matching template; emits canonical markdown with reserved tokens. |
| `requirements-investigator` | Investigates Story/Feature/Task/Spike issues (chat → tracker → docs → adjacent code areas). Distinct from `issuekit:issue-investigator`, which handles Bug/Incident. |

The agent also invokes `issuekit:tracker-adapter` (for every tracker read and write), `issuekit:issue-investigator` (for Bug/Incident investigation), and `issuekit:prose-style` (to clean any prose before write).

## Legacy config import

If your project still has `.claude/azure-issue-triage.config.json` or `.claude/jira-issue-triage.config.json` (or the older `.claude/jira-bug-triage.config.json`) from a previous version of this marketplace, the agent reads it forward for the session with a one-time warning. To stop the warning, translate the values into `.claude/tracker-policy.json` (shape documented in [`issuekit/skills/tracker-adapter/references/policy-schema.md`](../issuekit/skills/tracker-adapter/references/policy-schema.md)) and delete the legacy file. The lazy-prompt path will offer to persist any keys still missing.
