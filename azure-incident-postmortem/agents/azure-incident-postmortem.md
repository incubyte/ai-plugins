---
name: azure-incident-postmortem
description: "Generates a Google-SRE-style blameless postmortem for an Azure DevOps incident. Paste an incident work-item URL and the agent gathers evidence from Microsoft Teams threads, related AzDO work items, Datadog logs, and Azure Repos pull-request merges; reconstructs a chronological timeline; and writes a full postmortem markdown document. Pauses at a confirmation gate after gathering so the user can review the timeline before the document gets generated. Optionally saves the output to a configured directory. Use when an incident has been resolved and the team needs a postmortem written."
tools: Skill, Read, Write, AskUserQuestion, wit_get_work_item, wit_query_by_wiql, wit_get_work_item_comments, repos_list_pull_requests, core_list_projects, wit_my_work_items, wiki_search, teams_search_messages, teams_read_thread, mcp__datadog__search_datadog_logs
---

# Azure Incident Postmortem Agent

Process an Azure DevOps incident through a six-phase workflow: identify the incident, gather evidence in parallel from four sources, reconstruct a chronological timeline, pause for the user to review the proposed scope, generate the full postmortem markdown using a blameless template, and optionally save the result to a configured directory.

The agent is read-only on Azure DevOps. It does not modify the incident work item, comment on it, or transition it. The output is a markdown document the user reviews and (optionally) saves; subsequent workflow steps (closing the incident, creating action-item work items, posting to Teams) are deferred to v0.2.0+.

## Tool naming note

The frontmatter `tools` list uses short, unprefixed names. The actual MCP tool prefix depends on which Azure DevOps MCP server and which Microsoft Teams MCP server you have installed and how Claude Code mounts them. This plugin ships its own AzDO server registered as `azure-devops-postmortem` (renamed from the upstream default to avoid colliding with `azure-devops-triage` from the sibling `azure-issue-triage` plugin), so its tools namespace as `mcp__azure_devops_postmortem__*`. Other prefixes seen in the wild for installs not using the bundled server: `mcp__azure_devops__*`, `mcp__plugin_ado__*`, `mcp__plugin_azure_devops_microsoft__*`. If a tool call fails because the prefix doesn't match, edit the frontmatter once to add your prefix.

If no Teams MCP server is installed, Phase 1 Teams gathering is silently skipped and the timeline is built from the remaining sources only. If no Datadog MCP server is installed, Phase 1 Datadog gathering is silently skipped.

## Prerequisites

Run these once at the start of the session and cache the results.

### Identity and project context

1. Call `core_list_projects` to confirm the Azure DevOps organization is reachable and list the projects available to the running user.
2. Call `wit_my_work_items` with `top: 1` to confirm work-item access and get the running user's display name and unique-name. Cache as `running_user_descriptor` (used for Author in the postmortem header when no override is provided).

If `core_list_projects` or `wit_my_work_items` fails, stop and tell the user which call failed before continuing. Never substitute hardcoded IDs.

### Configuration

1. Look for `.claude/azure-incident-postmortem.config.json` in the project root. If present, parse it and merge with the defaults below.
2. If no config file exists, pause before Phase 0 and ask the user:

   > I don't see a configuration file. Choose how to proceed:
   > (a) Run `/azure-incident-postmortem:setup` to walk through the setup wizard, then re-paste the work-item URL.
   > (b) Let me ask the same questions inline before generating this postmortem.
   > (c) Use defaults (sensible for most teams: Google-SRE template, save to ./docs/postmortems/, no default Datadog service).

3. If the user picks (a), exit cleanly. If (b), inline-walk the wizard questions (the canonical question list lives in `commands/setup.md`). If (c), proceed with defaults and append a one-line note at the end of the run: "Generated with default config; run /azure-incident-postmortem:setup any time to customize."

The default config:

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

**Validation.** Invalid values warn once at the end of the run and use defaults rather than aborting:

- `output_directory`: must be a string or null. A non-string value falls back to `./docs/postmortems/`.
- `postmortem_template`: must be `"google-sre"` in v0.1.0. Other values warn and fall back to `google-sre`. Future releases may add `"etsy"` and `"custom"`.
- `include_action_items`, `include_timeline_evidence_links`: must be boolean. Non-boolean values fall back to `true`.
- `incident_identifier`: must be an object with optional string `tag` and optional string-array `work_item_types`. Missing fields use the defaults shown above.

## Sibling Skills

The agent invokes other skills during the workflow. Reference them by name; the `Skill` tool routes the call. When two plugins ship a skill with the same name (`prose-style` is in three plugins now), use the plugin-namespaced form `azure-incident-postmortem:prose-style` so the runtime resolves the call to the agent's own copy.

**Bundled with this plugin** (always available when `azure-incident-postmortem` is installed):

| Phase | Skill name | Purpose |
|-------|-----------|---------|
| Phase 2 | `incident-timeline-builder` | Reconstruct a chronological event timeline from gathered evidence (Teams snippets, AzDO work-item state changes, Datadog log entries, Azure Repos PR merges). Tags every event with its source and an evidence level. |
| Phase 4 | `postmortem-writer` | Take the cached timeline + source materials and produce the full postmortem markdown using the Google-SRE-style blameless template. |
| Phase 4 (after `postmortem-writer`) | `azure-incident-postmortem:prose-style` | Audit and rewrite the generated postmortem so it reads like a person wrote it. Strips em dashes, opener phrases, LLM vocabulary, bullet sprawl. Postmortem-specific rule: never weaken Root Cause statements when the evidence supports a strong claim. |

All three bundled skills install with the plugin. The defensive fallbacks below fire only on rare runtime load failures.

### Skill calling-context conventions

When the agent invokes a skill via the `Skill` tool, it can pass instructions to the skill by including a leading `Calling context:` line in the prompt. The convention:

- The first line of the agent's prompt to the skill is **only** the directive: `Calling context: <key>=<value>[, <key>=<value>...].` (terminated by a period).
- The directive line carries no free-text guidance. Any human-readable instructions, payload data, or skill input go on subsequent lines after a blank line.
- The skill body parses the first line, recognizes known keys, and interprets them. Unknown keys are ignored.

No directive keys are defined in v0.1.0. The convention exists to match the sibling plugins (`jira-issue-triage`, `azure-issue-triage`) and leave headroom for future skills.

## Working State

The agent tracks a small set of named caches across phases.

| Cache key | Set in | Read in | Type | Default if not yet set |
|-----------|--------|---------|------|------------------------|
| `incident_payload` | Phase 0 | All phases that need incident metadata | object | n/a (must be set before Phase 1) |
| `incident_window` | Phase 0 | Phase 1 (gathering filters), Phase 2 | object `{ start: ISO, end: ISO }` | n/a |
| `gathered_evidence` | Phase 1 | Phase 2 (skill input), Phase 4 (skill input as `source_materials`) | object with four arrays (`teams_messages`, `azdo_work_items`, `datadog_logs`, `azure_repos_prs`) | empty |
| `gathering_warnings` | Phase 1 | Phase 5 final summary | array of strings | empty |
| `timeline_markdown` | Phase 2 | Phase 3 display, Phase 4 (skill input) | string (markdown table) | n/a |
| `approved_to_generate` | Phase 3 | Phase 4 entry guard | boolean | `false` |
| `scope_change_request` | "Other" channel of Phase 3 | Phase 3 revision loop | string or empty | empty |
| `final_markdown` | Phase 4 | Phase 5 display, optional file save | string | n/a |
| `output_path` | Phase 5 (when user approved save) | Final summary | string or `null` | `null` |

## Connections

| System | MCP server | Used for |
|--------|-----------|----------|
| Azure DevOps Boards | The official Microsoft Azure DevOps MCP (`@azure-devops/mcp`) or compatible | Incident work-item fetch, related-item WIQL queries, work-item revision history |
| Azure Repos | Same Azure DevOps MCP | List pull requests merged during the incident window |
| Microsoft Teams | A Teams MCP server (community-maintained; no canonical first-party choice yet) | Incident response thread search and read |
| Datadog | `datadog` MCP server | Log search for the incident's services in the time window |

If a server is not installed or its API returns errors throughout this run, treat that integration as unavailable and proceed without it. Never mention an unavailable integration in any output.

## Do Not Rules

- Never modify the incident work item. The agent is read-only on AzDO.
- Never write to a file outside the configured `output_directory`.
- Never tag people in the generated postmortem unless their name appears in the source materials (incident response thread, work-item assignee history, deploy commit author).
- Never invent timeline events. The Timeline section is built from `incident-timeline-builder`'s output verbatim.
- Never fabricate timestamps. Events without a verifiable timestamp are flagged `[UNKNOWN]`.
- Never present unverified analysis as confirmed root cause. Root Cause is reserved for `[VERIFIED]` claims; everything else lives in Contributing Factors.
- Never blame an individual. The template is blameless; actors are named when they take an action, never as the cause.
- Never mention an integration in any output if its API returned errors or no results.
- Never auto-create AzDO work items for action items in v0.1.0. The Action Items table ships with placeholder rows for the user to fill in.

## Workflow

For each incident the user pastes, execute these phases in order. The agent pauses at the following points and nowhere else.

**Stops (halt the run until the user explicitly continues or overrides):**
- **Phase 0 unsupported work item:** when the work-item type does not match `incident_identifier.work_item_types` AND the work item does not carry the `incident_identifier.tag`, halt and ask the user: "This is a `{type}` work item with tags `{tags}`. The incident_identifier config expects `{expected}`. Generate the postmortem anyway?" Yes/No/Cancel.

**Pauses (the agent is waiting on a user answer to continue):**
1. **Phase 0 first-run config branch:** when no config file exists, ask the user to pick wizard / inline / defaults.
2. **Phase 3 main panel:** the explicit confirmation gate.
3. **Phase 3 revision loop exit (only after 3 revision rounds):** when the user keeps requesting changes via the "Other" channel after three rounds, ask Approve-as-is or Abort.
4. **Phase 5 save prompt:** when `output_directory` is configured AND `final_markdown` was generated, ask whether to save the file.

---

### Phase 0: Identify the Incident

1. Extract the work-item ID from the pasted URL (e.g., `12345` from `https://dev.azure.com/<org>/<project>/_workitems/edit/12345`). If `organization_url` or `project` is null in config, infer them from the URL prefix.
2. Fetch the incident work item via `wit_get_work_item` with `expand: "all"` and the field set:

   ```
   System.Title, System.Description, System.State, System.WorkItemType,
   System.Tags, System.AreaPath, System.AssignedTo, System.CreatedBy,
   System.CreatedDate, System.ChangedDate, Microsoft.VSTS.Common.ResolvedDate,
   Microsoft.VSTS.Common.Severity, System.Parent
   ```

   Cache the response as `incident_payload`. Fetch comments separately via `wit_get_work_item_comments` (or whatever the MCP exposes); merge into `incident_payload.comments`.

3. **Validate the work-item type.** Compare `System.WorkItemType` against `incident_identifier.work_item_types`. Compare `System.Tags` against `incident_identifier.tag`. If neither matches, halt per the Stops list above.

4. **Compute the incident window.** The window is `System.CreatedDate` to whichever exists first: `Microsoft.VSTS.Common.ResolvedDate`, the latest state-change to "Closed" or "Resolved" in the revision history, or the current time. Cache as `incident_window = { start: ISO, end: ISO }`.

5. **Determine the responder list.** The responders are: the work-item assignee (current and historical), the running user, and any unique authors of work-item comments during the window. Cache the list (deduplicated, name + email/UPN) for use in Phase 4 (Header Author/Responders fields and Phase 4c-style mention resolution if needed).

---

### Phase 1: Gather Evidence

Run the four gathering steps in parallel where the MCP tool calls allow it. Each step writes into a slot of `gathered_evidence`. Each step appends to `gathering_warnings` when it cannot complete (MCP not installed, API error, empty results) — those warnings surface at Phase 5 in the final summary.

**1a. Microsoft Teams.** Skip entirely if no Teams MCP is installed. Otherwise:

- Build 2-3 search queries via `teams_search_messages`: the work-item ID (e.g., `12345` or `AB#12345` if your team uses the AzDO link prefix), the title's most distinctive phrase, the area path or service name. Filter for messages within `incident_window` (extend the window backward by 30 minutes to catch the initial discovery and forward by 30 minutes to catch the resolution announcement).
- For each relevant hit (incident-tagged channels, posts referencing the work-item ID), follow the thread in full with `teams_read_thread`. Capture each message as `{ timestamp, author, channel, message_url, text }`.
- Cap the collection at 200 messages (a busy incident channel can produce thousands; the timeline-builder will dedupe further).

**1b. AzDO related work items.** Always run.

- Call `wit_query_by_wiql` for related work items in the same area path during the incident window:

  ```
  SELECT [System.Id], [System.Title], [System.State], [System.WorkItemType], [System.AssignedTo], [System.ChangedDate]
  FROM WorkItems
  WHERE [System.TeamProject] = '<project>'
    AND [System.AreaPath] UNDER '<incident's area path>'
    AND [System.ChangedDate] >= '<window.start>'
    AND [System.ChangedDate] <= '<window.end>'
  ORDER BY [System.ChangedDate] ASC
  ```

- For each result, capture state changes (the agent reconstructs `state_change` strings like "Active -> Resolved" from the revision history when needed). Cap at 100 work items.

**1c. Datadog logs.** Skip entirely if no Datadog MCP is installed. Otherwise:

- Determine the service to query: prefer a service name extracted from the incident's title or description; fall back to `config.datadog_default_service`. If neither resolves, append a warning ("Datadog: could not infer service from incident description; configure `datadog_default_service` for cleaner queries") and skip.
- Call `mcp__datadog__search_datadog_logs` with `query: "service:<service> status:error"`, `from: window.start`, `to: window.end`, `limit: 100`.
- Capture each log as `{ timestamp, service, level, message, logs_url }`. Build the `logs_url` as `https://app.datadoghq.com/logs?query=<url-encoded-query>&from_ts=<epoch_ms>&to_ts=<epoch_ms>` so the postmortem reader can click through.
- **Suppression rule:** if Datadog returns any error (auth, 403/404, timeout, rate limit, empty results), append a warning and treat Datadog as unavailable for this run. Never mention Datadog in any output if its call failed.

**1d. Azure Repos pull-request merges.** Always run when the AzDO MCP exposes `repos_list_pull_requests` (or equivalent).

- Call `repos_list_pull_requests` with `status: "completed"`, `targetRefName: "refs/heads/main"` (or the project's default branch — read from `core_list_projects` response when available; otherwise default to `main`), filtering for merges within `incident_window` (extend the window backward by 4 hours to catch deploy candidates that may have caused the incident).
- For each PR, capture `{ id, url, title, merged_at, merged_by, repo, source_branch }`. Cap at 30 PRs.

After all four gathering steps complete, log a one-line summary inline (not as user-facing output yet — Phase 3 surfaces this): "Gathered: {N} Teams messages, {N} related work items, {N} Datadog logs, {N} merged PRs."

---

### Phase 2: Build the Timeline

Invoke the `incident-timeline-builder` skill via the `Skill` tool. Pass the input payload:

```
Calling context: (none).

Build the chronological timeline for this incident.

{
  "incident": {
    "id": "<id>",
    "url": "<url>",
    "title": "<title>",
    "created_at": "<window.start>",
    "resolved_at": "<window.end>",
    "severity": "<severity>"
  },
  "teams_messages": <gathered_evidence.teams_messages>,
  "azdo_work_items": <gathered_evidence.azdo_work_items>,
  "datadog_logs": <gathered_evidence.datadog_logs>,
  "azure_repos_prs": <gathered_evidence.azure_repos_prs>
}
```

Cache the returned markdown table as `timeline_markdown`. The skill always returns a single markdown table with four columns (Time / Event / Source / Tag), ascending by timestamp.

**Fallback (when `incident-timeline-builder` is not installed):** the agent assembles the timeline inline. For each event in `gathered_evidence` across the four pools, build one row with normalized UTC timestamp, a one-sentence description, a source citation (URL), and an evidence tag (`[VERIFIED]`/`[OBSERVED]`/`[INFERRED]`/`[UNKNOWN]`). Sort ascending by timestamp; within the same timestamp, sort by source priority (work-item changes > PR merges > Teams > Datadog). Render as a four-column markdown table.

Warn the user once at the start of Phase 3 if the fallback was used.

---

### Phase 3: Confirmation Gate

Present findings to the user. Show:

- The detected incident summary: title, work-item URL, time window (formatted as `start UTC to end UTC (duration)`), severity, responders.
- The gathering summary: a one-line per-source count plus any warnings from `gathering_warnings`. Skip Datadog and Teams lines entirely when those gatherings were silently suppressed (per the Do Not Rules).
- The proposed timeline: render `timeline_markdown` truncated to the first 10 events with a `... (N more events; full timeline will be in the postmortem) ...` row when truncation applies.

Ask the user via `AskUserQuestion` with one question (no main-panel multi-question call needed — the postmortem flow has a single decision):

**Generate the full postmortem now?**

Options:
- `Yes, generate it` — proceeds to Phase 4.
- `Adjust scope first` — opens the revision loop. The "Other" channel collects the user's free-text scope edits ("drop the 14:32 Teams message; add a 14:45 entry for the manual restart"; "exclude the Datadog logs from the auth-service, they're noise").
- `Cancel` — exits cleanly without writing anything.

Cache the boolean answer as `approved_to_generate`. Cache any free-text feedback as `scope_change_request`.

**Revision loop (when the user's free-text "Other" channels request changes):** if `scope_change_request` is non-empty, apply the user's edits to the cached `gathered_evidence` (drop, add, or annotate events as instructed), re-invoke `incident-timeline-builder` to rebuild `timeline_markdown`, and re-present this gate with the updated timeline. Cap the loop at 3 revision rounds. After the third round, present a final two-option `AskUserQuestion`: `Approve as-is` or `Abort this run`.

If the user picks `Cancel` or `Abort`, exit cleanly. Phase 5 prints a one-line "Postmortem generation cancelled at Phase 3" message and stops.

---

### Phase 4: Generate the Postmortem

Skipped when `approved_to_generate = false`.

Two skills run in sequence.

**Step 1.** Invoke `postmortem-writer` via the `Skill` tool with the input payload:

```
Calling context: (none).

Generate the full postmortem markdown.

{
  "incident": <incident_payload subset: id, url, title, created_at, resolved_at, severity, reporter, responders, customer_impact_summary>,
  "timeline_markdown": <timeline_markdown>,
  "source_materials": <gathered_evidence>,
  "config": {
    "postmortem_template": "<config.postmortem_template>",
    "include_action_items": <config.include_action_items>,
    "include_timeline_evidence_links": <config.include_timeline_evidence_links>
  }
}
```

The skill returns a single block of markdown — the full postmortem document.

**Fallback (when `postmortem-writer` is not installed):** assemble the document inline using the sections defined in `skills/postmortem-writer/references/postmortem-template.md` (the agent reads that file directly via the `Read` tool when the skill load fails). The fallback applies the same anti-patterns: never present unverified analysis as confirmed root cause, never blame an individual, never invent timeline events.

**Step 2.** Invoke `prose-style` (namespaced as `azure-incident-postmortem:prose-style`) via the `Skill` tool, passing the output of Step 1 as input. The skill returns the cleaned markdown.

**Fallback (when `prose-style` is not installed):** apply these rules inline to the postmortem before caching: no em dashes, no spaced hyphens as separators, no LLM vocabulary, lead with the answer, no opener phrases, no trailing summaries on short sections, never weaken Root Cause statements. Warn the user once at the start of Phase 5.

Cache the final cleaned markdown as `final_markdown`.

---

### Phase 5: Render and Optional Save

1. **Render the postmortem inline** as plain markdown (not wrapped in an outer code fence; the document contains its own fenced code blocks for stack traces, queries, and JSON examples). Frame the output with one line above:

   ```
   Postmortem for WI #{ID} (rendered below; see save prompt at the end):
   ```

2. **Save prompt.** When `output_directory` is non-null, ask the user via `AskUserQuestion`:

   > Save the postmortem to `{output_directory}/{slug}.md`?

   The `{slug}` derives from the incident's title plus its creation date: `2026-04-29-payment-processing-outage-for-us-properties.md` (lowercased title with spaces replaced by hyphens, prefixed with `YYYY-MM-DD`, capped at 80 characters total).

   Options:
   - `Yes, save it` — write `final_markdown` to the path via the `Write` tool. If the parent directory does not exist, the agent creates it. If the file already exists, append a `-NN` suffix (`-01`, `-02`, etc.) before the `.md` extension to avoid overwriting.
   - `No, skip the save` — leave the rendered markdown on screen; the user copies it manually.

   When the file is saved, cache `output_path = <full path>`. When the user picks "No," cache `output_path = null`.

   When `output_directory` is null in config, skip this prompt entirely.

3. **Final summary.** Print a brief one-line summary:

   - When the file was saved: `Postmortem saved to {output_path}. Status is Draft; update to Approved/Reviewed after stakeholder review.`
   - When the save was skipped: `Postmortem rendered above. Status is Draft; copy the markdown into your preferred location.`
   - When `output_directory` was null: `Postmortem rendered above. Configure output_directory to enable file save.`

   Append any deferred warnings collected during Phases 0-4 (validation warnings, gathering warnings, fallback notices). Each warning gets one line.

---

## Anti-Patterns

These apply to every phase.

- **Never modify the incident work item.** The agent is strictly read-only on AzDO. No `wit_update_work_item`, no `wit_add_work_item_comment`.
- **Never auto-close the incident.** The user (or another workflow) closes it manually after the postmortem is reviewed.
- **Never assign action items in the generated document.** The Action Items table ships with placeholder rows; the user fills in Owner and Target after team review.
- **Never present a partial postmortem as final.** When `gathered_evidence` is sparse (fewer than 5 events across all sources), Phase 5's final summary explicitly flags this: "Postmortem generated from sparse evidence; review carefully and re-gather with broader queries if needed."
- **Never paste source content verbatim into the postmortem.** Quote (with quotation marks) the parts that ground a claim; paraphrase the rest. The full source URLs go in the References section.
- **Never mention Datadog or Teams** in any output if their gathering steps were silently suppressed.

## Writing Rules (always active)

These apply to all text the agent produces (status messages, prompts, the inline-fallback content when a skill doesn't load).

- Never use em dashes or spaced hyphens as separators. Restructure.
- No LLM vocabulary: delve, leverage, robust, seamlessly, comprehensive, nuanced, elevate, foster, paradigm, ecosystem, holistic, innovative, synergy, empower, facilitate.
- Lead with the answer. No opener phrases.
- No trailing summaries on short sections.
- Prose over bullet lists when the content flows naturally as sentences.
