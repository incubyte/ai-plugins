# azure-incident-postmortem

A Claude Code plugin that ships one subagent (`azure-incident-postmortem`) and a setup wizard (`/azure-incident-postmortem:setup`). Paste an Azure DevOps incident work-item URL and tell the agent to write a postmortem. The agent gathers evidence from Microsoft Teams threads, related work items, Datadog logs, and Azure Repos deploys; reconstructs a chronological timeline with source citations and evidence tags; and writes a Google-SRE-style blameless postmortem document. The agent pauses at the Phase 3 confirmation gate (after gathering, before generating) so you can review the timeline and proposed scope before the document gets written.

This plugin is a sibling of [`jira-issue-triage`](../jira-issue-triage/) and [`azure-issue-triage`](../azure-issue-triage/). All three install side by side; the workflows are conceptually distinct but share the evidence-tag taxonomy and the bundled `prose-style` skill (resolved via plugin namespacing).

## Plug and play: the 60-second tour

### One entry point, one shape

There's only one way to invoke this plugin: spawn the `azure-incident-postmortem` agent and paste an incident work-item URL. Unlike `azure-issue-triage`, there's no lightweight subset to extract as a separate slash command — the agent is already a one-shot gather + generate chain.

### What gets gathered in one run

The agent runs three phases of evidence gathering in parallel before pausing, then chains two skills to produce the document.

| Phase | What runs | Sources touched |
|---|---|---|
| 1 (parallel fan-out) | Teams search via `teams_search_messages` + `teams_read_thread` (when a Teams MCP is installed). WIQL query for related work items in the same area path during the incident window. Datadog log search for the inferred or configured service (when a Datadog MCP is installed). Azure Repos pull requests merged during the incident window via `repos_list_pull_requests`. | Microsoft Teams, AzDO work items, AzDO Repos, Datadog logs |
| 2 | `incident-timeline-builder` skill: reconstructs a chronological event timeline from the gathered evidence, with one UTC timestamp + one-sentence description + source citation + evidence tag per row. | Cached output from Phase 1 only (no fresh API calls) |
| 3 (user gate) | Pause for review. Agent prints the timeline + proposed scope and asks whether to proceed, revise scope, or cancel. | n/a |
| 4 | `postmortem-writer` skill: produces the full Google-SRE-style blameless markdown (summary, impact, timeline, root cause, contributing factors, what went well/wrong, action items, lessons learned, references). Then `prose-style` cleans the result. | Cached evidence + approved timeline |

Teams and Datadog gracefully degrade. Missing either one means the timeline is necessarily thinner (most incidents have key context in the response thread), but the agent never aborts.

### Plug-and-play status (read before installing)

Two things are true about this plugin today; one is a friction point worth knowing up front.

1. **The bundled `.mcp.json` is Rolai-shaped.** The plugin ships a `.mcp.json` that launches `@azure-devops/mcp` with the org hardcoded to `rolaillc` and the PAT pulled from `server/.env` via `dotenvx get`. If you work at Rolai with the standard `server/.env` + `.env.keys` setup, this is fully plug-and-play. If you don't, you'll need to override the file locally (drop your own `.mcp.json` in the project root with your org + auth) before the agent can read incident work items.
2. **Everything else auto-discovers.** Project, default service for Datadog queries, output directory for the saved postmortem, incident-window heuristics — the setup wizard prompts for each.

A universal version of the MCP config (`userConfig` schema, PAT in the system keychain, no dotenvx dependency, no hardcoded org) is on the follow-up list. When it lands, item 1 above flips to "fully plug-and-play for anyone."

## Status: v0.1.0

This is the initial release. Compared to a hypothetical fully-featured postmortem suite:

- **Included:** evidence gathering (Teams when installed, AzDO work items, Datadog logs, Azure Repos deploys), chronological timeline with evidence tags, Google-SRE-style blameless template, optional file save to a configured output directory, prose-style cleanup pass.
- **Deferred to v0.2.0+:** direct write to AzDO Wiki, auto-create AzDO work items for action items, Teams notification when the postmortem lands, capture-then-replay dry-run mode, Confluence write for legacy users.

## Prerequisites

### Required

- **Azure DevOps MCP server.** The agent needs Boards access (read incident work items, query related work items via WIQL, list deploys via Repos). Microsoft ships an official server at [github.com/microsoft/azure-devops-mcp](https://github.com/microsoft/azure-devops-mcp) (`@azure-devops/mcp`).

  **Auto-registered by this plugin (Rolai-shaped).** The plugin ships a `.mcp.json` that launches `@azure-devops/mcp` via `npx -y` with a `bash -c` wrapper that pulls the PAT from an encrypted env file with [dotenvx](https://dotenvx.com/):
  ```
  export AZURE_DEVOPS_PAT=$(dotenvx get AZURE_DEVOPS_PAT -f server/.env) \
    && npx -y @azure-devops/mcp rolaillc
  ```
  Working assumptions today, hardcoded in the shipped config:
  - Organization slug: `rolaillc`.
  - PAT location: `server/.env`, relative to the directory Claude Code is launched from, encrypted with dotenvx, with the matching `.env.keys` available for decryption.

  This matches the Rolai dev workflow and is the working state of the config. A universal version (`userConfig` schema, keychain-stored PAT, no dotenvx dependency) is on the follow-up list.

  **Server name + tool-prefix note.** The MCP server is registered as `azure-devops-postmortem` (renamed from the upstream default `azure-devops`) so it doesn't collide with `azure-devops-triage` shipped by [`azure-issue-triage`](../azure-issue-triage/) when both plugins are enabled. Tools therefore namespace as `mcp__azure_devops_postmortem__wit_get_work_item`, etc. The agent body lists them in their commonly-used short form (`wit_get_work_item`, `wit_query_by_wiql`, `repos_list_pull_requests`, `wiki_search`). If your install requires the full prefix, edit the agent's frontmatter once.

### Recommended (the agent gracefully degrades without these)

- **Microsoft Teams MCP server.** Used to find the incident response thread and pull its messages into the timeline. Without one, the agent skips Teams gathering and notes the gap in the timeline.
- **Datadog MCP server.** Used for log search during the incident window. Without it, the agent skips Datadog gathering.

The plugin does not depend on Slack or Confluence. If you also use `azure-issue-triage` or `jira-issue-triage`, all plugins coexist; their `prose-style` skills resolve via plugin namespacing.

### Bundled skills

The agent calls three skills during the workflow. All three ship bundled with this plugin and install automatically.

| Skill name | Phase | Used for | Status |
|-----------|-------|----------|--------|
| `incident-timeline-builder` | Phase 2 | Reconstruct a chronological event timeline from gathered evidence (Teams snippets, AzDO work-item revisions, Datadog log entries, deploy commits). Tags every event with its source and an evidence level. | Bundled |
| `postmortem-writer` | Phase 4 | Take the cached timeline + source materials and produce the full postmortem markdown using a Google-SRE-style blameless template. | Bundled |
| `prose-style` | Phase 4 (after `postmortem-writer`) | Writing-rule application: strips em dashes, opener phrases, LLM vocabulary, bullet sprawl. Mirror of `azure-issue-triage/skills/prose-style/`. | Bundled |

## Quick start

1. Add the marketplace and install the plugin:

   ```
   /plugin marketplace add github.com/TahaBikanerwala/jt-bikanerwala-marketplace
   /plugin install azure-incident-postmortem
   ```

2. (Optional but recommended) Run the setup wizard:

   ```
   /azure-incident-postmortem:setup
   ```

   The wizard walks through five questions (organization URL, project, output directory, postmortem template, default Datadog service) and writes `.claude/azure-incident-postmortem.config.json`.

3. Verify the agent appears in the agent list, then paste an Azure DevOps incident work-item URL:

   > Write a postmortem for `https://dev.azure.com/<org>/<project>/_workitems/edit/12345`.

   The agent runs through phases 0-5, pauses at the Phase 3 confirmation gate, and waits for your approval before generating the final document.

## Configuration

Configuration is **optional**. The agent uses sensible defaults if no config file is found. To override, run `/azure-incident-postmortem:setup` or create `.claude/azure-incident-postmortem.config.json` in your project root by hand:

```json
{
  "organization_url": null,
  "project": null,
  "output_directory": "./docs/postmortems/",
  "postmortem_template": "google-sre",
  "datadog_default_service": null,
  "include_action_items": true,
  "include_timeline_evidence_links": true,
  "incident_identifier": { "tag": "incident", "work_item_types": ["Issue", "Bug"] },
  "description_preview_pause_seconds": 3
}
```

### Defaults (when config is absent)

- `organization_url` and `project`: required at first run if not configured. The agent inspects the work-item URL and asks you to confirm or override.
- `output_directory`: `./docs/postmortems/`. The agent saves the generated markdown to a date-prefixed file (e.g., `2026-05-06-payment-outage.md`) when the user accepts the save prompt at Phase 5. Set to `null` to disable file save (Phase 5 still renders the markdown inline).
- `postmortem_template`: `google-sre`. The bundled template is documented in `skills/postmortem-writer/references/postmortem-template.md`. Other values (`etsy`, `custom`) are reserved for future releases; the v0.1.0 build only ships the `google-sre` template.
- `datadog_default_service`: null. Used as a fallback when the agent can't infer a service from the incident's description or comments. Set to your team's default service tag for cleaner Datadog queries.
- `include_action_items`: `true`. The Action Items section appears in the generated postmortem with placeholder rows the user fills in. Set to `false` to omit the section entirely (some teams track action items in a separate ticket flow).
- `include_timeline_evidence_links`: `true`. Each timeline row carries a clickable link to the source (Teams message, work-item revision, Datadog log entry, commit URL). Set to `false` for a plainer timeline.
- `incident_identifier`: how the agent recognizes a work item as an incident. Default: any work item tagged `incident` OR whose work-item-type is `Issue` or `Bug`. The agent uses this only to refuse to generate postmortems for clearly-non-incident work items (User Story, Feature, Spike); the user can always force-run with an explicit "yes, run anyway" override.

### Postmortem template

The Google-SRE-style blameless template ships with these sections:

1. **Header.** Title, status, author, severity, duration, detection method, customer-impact summary.
2. **Summary.** One to three sentences. The anchor; a reader who reads only this should know what happened.
3. **Impact.** Customer count, duration, symptoms, business impact.
4. **Timeline (UTC).** Chronological table of events with sources.
5. **Root Cause.** Plain prose, evidence-tagged.
6. **Contributing Factors.** Bulleted list of secondary causes.
7. **Detection.** How the incident was detected and time-to-detect.
8. **Resolution.** What stopped the bleeding, who did it, when.
9. **What Went Well.** Bulleted list.
10. **What Went Wrong.** Bulleted list.
11. **Action Items.** Table with owner, target date, severity. Skipped when `include_action_items: false`.
12. **Lessons Learned.** Prose summary.
13. **References.** Links to the incident work item, Teams thread, Datadog dashboards, related deploys.

Sections with no content collapse into a one-line placeholder ("No data gathered for this section. Add manually.") rather than disappearing — the structure is intentional even when data is sparse.

### Output directory not writable

When `output_directory` is set but the agent can't write to it (permission denied, missing directory), the agent renders the markdown inline and notes the failure: "Could not save to `{path}`; copy the rendered output above into a file manually." The run does not abort.

### Datadog not installed

The Datadog gathering step is silently skipped. The timeline is built from the remaining sources only. The agent never mentions Datadog in any output if its API errored or returned no results.

### Teams not installed

Teams gathering is silently skipped. The agent notes the gap once at the start of Phase 1 ("No Teams MCP detected; the timeline will not include incident-channel messages") and continues. Without Teams, the timeline is necessarily thinner — most incidents have key context in the response thread.

## Workflow phases

| Phase | What it does |
|-------|--------------|
| Prerequisites | Auto-discover identity, load config (with first-run wizard fallback if missing), confirm the work-item type matches `incident_identifier`. |
| Phase 0 | Fetch the incident work item via `wit_get_work_item`, identify the incident time window (`System.CreatedDate` to `System.ResolvedDate` or `System.ChangedDate`), confirm the work item is an incident (or pause to ask the user when it's not). |
| Phase 1 | **Gather evidence in parallel.** Teams: search the response thread via `teams_search_messages` (skipped if no Teams MCP). AzDO: WIQL query for related work items in the same area path during the incident window. Datadog: log search for the inferred or configured service in the time window (skipped if no Datadog MCP). Repos: list pull requests merged during the incident window via `repos_list_pull_requests`. |
| Phase 2 | Invoke `incident-timeline-builder` skill on all gathered evidence. The skill produces a chronological event list with timestamps (UTC), descriptions, source citations, and evidence tags. |
| Phase 3 | **Hard pause.** Show the detected incident summary (title, time window, severity, response thread link), the source-by-source evidence count, and the proposed timeline (truncated to the first 10 events for review). Ask: `Generate the full postmortem now?` Options: `Yes`, `Adjust scope (let me edit the timeline first)`, `Cancel`. |
| Phase 4 | Invoke `postmortem-writer` skill with the cached timeline and source materials. The skill produces the full markdown using `postmortem_template`. Then run `prose-style` (namespaced as `azure-incident-postmortem:prose-style`) to clean writing anti-patterns. |
| Phase 5 | Render the final markdown inline. If `output_directory` is configured, ask: `Save to {output_directory}/{slug}.md?` Options: `Yes, save it`, `No, skip the save`. The slug derives from the incident's title plus its creation date (e.g., `2026-05-06-payment-outage.md`). |

## Limitations

The agent will never:

- Generate a postmortem without showing you the timeline first AND getting explicit approval at the Phase 3 gate.
- Guess at root-cause text. The Root Cause section is grounded in evidence; speculation goes into Contributing Factors with `[INFERRED]` tags.
- Write to a file outside the configured `output_directory`.
- Modify the incident work item itself. The agent reads from AzDO; it does not edit, comment, or transition.
- Tag people in the generated postmortem unless their name appears in the source materials (incident response thread, work-item assignee history, deploy commit author).
- Mention an integration (Teams, Datadog) in any output if its API returned errors or no results.
- Fabricate timestamps. Every timeline entry carries a source citation; events without a verifiable timestamp are flagged `[UNKNOWN]` rather than guessed.

## FAQ

**Q: What if my incident isn't a single work item — it's a Slack thread plus a Teams call plus a debug session?**
A: Create or find an AzDO work item that anchors the incident (the convention most teams follow). The agent uses the work item as the entry point but pulls from all the side-channel sources you mention. If your team genuinely doesn't track incidents in AzDO, this plugin isn't the right fit.

**Q: Can I edit the timeline before the postmortem gets written?**
A: At the Phase 3 gate, picking `Adjust scope` lets you describe the edits in free text ("drop the 14:32 Teams message; add a 14:45 entry for the manual restart"). The agent applies the edits and re-shows the timeline. Cap of 3 revision rounds.

**Q: Does the postmortem auto-close the incident?**
A: No. The agent is read-only on the AzDO work item. After you review and save the generated markdown, you (or another workflow) close the incident manually.

**Q: I use `azure-issue-triage` and `azure-incident-postmortem`. Will they collide?**
A: No. Skill names are prefixed (`incident-timeline-builder`, `postmortem-writer`, `azure-issue-investigator`, `azure-work-item-refiner`). The shared `prose-style` skills resolve via plugin namespacing (`azure-issue-triage:prose-style`, `azure-incident-postmortem:prose-style`); each agent calls its own copy.

## Contributing

Issues and PRs welcome at the marketplace repo. The agent body is at `agents/azure-incident-postmortem.md`; the manifest is at `.claude-plugin/plugin.json`. Bundled skills live under `skills/`.

## License

MIT. See the [`LICENSE`](../../LICENSE) at the repo root.
