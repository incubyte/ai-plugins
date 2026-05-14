# azure-issue-triage

A Claude Code plugin that ships one subagent (`azure-issue-triage`) and a setup wizard (`/azure-issue-triage:setup`). Paste any Azure DevOps work-item URL (Bug, Incident, User Story, Feature, Task, or Spike) and tell the agent to triage. The agent assigns the work item to you, transitions it to investigating, runs the matching investigation skill, drafts an archetype-appropriate assessment comment, refines the title and description, applies a triaged tag, and posts a one-line summary on Microsoft Teams. The agent pauses at the Phase 3 confirmation gate (before posting any comment, changing the description, or updating other fields) to show you the full findings and get your approval.

This plugin is a sibling of [`jira-issue-triage`](../jira-issue-triage/). The two plugins install side by side; the workflows are conceptually identical but call platform-specific tools.

## What's new in v0.4.0

Three non-bug-flow upgrades that close the parity gap with `jira-issue-triage` and add a feature unique to the AzDO stack:

- **Sprint placement (iteration path).** New `iteration_path_strategy` config (`null` / `"current"` / `"explicit:<path>"`). When `"current"`, Phase 6 calls `work_list_team_iterations` for the configured `default_team` and writes the active iteration to `System.IterationPath`. When `"explicit:<path>"`, the agent writes that path verbatim. Applies to User Story / Feature / Task / Spike on the standard path.
- **Story-point estimation prompt.** New `story_points_field` config (defaults to null). When set, the Phase 3 main panel adds a fourth question for User Story or Feature work items: `1`, `3`, `5`, or `Skip` (with "Other" accepting any other number). Phase 6 writes the estimate to the configured field; null estimates skip the write.
- **Azure Repos pull-request linking.** New `pr_linking_enabled` config (defaults to `true`). The agent regex-matches Azure Repos PR URLs in the description, comments, Teams threads, and investigator output, resolves each via `repos_get_pull_request_by_id`, proposes up to 4 at the Phase 3 panel, and writes the user-approved subset as `ArtifactLink` relations using the AzDO `vstfs:///Git/PullRequestId/...` URL form.

All planned v0.x archetype-and-workflow surface area has now landed. Open follow-ups for v0.5.0 and later: capacity-aware sprint placement (overflow into next sprint when current is full), backfill PR links on already-merged work items, support for the `Microsoft.VSTS.CMMI.*` field family on CMMI projects.

## What's new in v0.3.0

Three Bug/Incident-flow upgrades that bring the agent closer to feature parity with `jira-issue-triage`:

- **Severity SLA due dates.** `severity_scheme` config (`due_offset_days`, `escalate_immediately`) maps each severity level to a target turnaround. Phase 6 writes `Microsoft.VSTS.Scheduling.DueDate` as `System.CreatedDate + due_offset_days`. The pre-triage value is preserved in revision history.
- **Microsoft Teams escalation routing.** A new `escalation` config block (`teams_channel`, `primary_contact`, `fallback_contact`) drives Phase 10 escalation when the recommended severity has `escalate_immediately: true`. The agent posts a separate channel message mentioning the resolved primary contact (looked up by email at session start), DMs the contact directly when no channel is configured, or no-ops when both are null.
- **EM-fallback for deactivated reporters.** When a follow-up is needed and the reporter appears unreachable, the agent now runs a three-step ladder: Teams profile manager lookup, AzDO team-admin scan, then ask-the-user with a proposed candidate. EM tagging requires explicit user approval; the question comment carries an "original reporter is unreachable" preamble.

All deferred items shipped in v0.4.0 (see above).

## What's new in v0.2.0

The archetype scope expanded from Bug + Task (v0.1.0) to all five archetypes. **Bug, Incident, User Story, Feature, Task, and Spike** all triage end-to-end now. Process-template-aware mapping in `work_item_type_map` lets Scrum (Product Backlog Item, Impediment) and CMMI (Requirement, Issue) projects override the work-item-type names.

## Prerequisites

### Required

- **Azure DevOps MCP server.** The agent needs full Boards access (read work items, edit fields, post comments, query via WIQL, link work items, look up users). Microsoft ships an official server at [github.com/microsoft/azure-devops-mcp](https://github.com/microsoft/azure-devops-mcp) (`@azure-devops/mcp`).

  **Auto-registered by this plugin (Rolai-shaped).** The plugin ships a `.mcp.json` that launches `@azure-devops/mcp` via `npx -y` with a `bash -c` wrapper that pulls the PAT from an encrypted env file with [dotenvx](https://dotenvx.com/):
  ```
  export AZURE_DEVOPS_PAT=$(dotenvx get AZURE_DEVOPS_PAT -f server/.env) \
    && npx -y @azure-devops/mcp rolaillc
  ```
  Working assumptions today, hardcoded in the shipped config:
  - Organization slug: `rolaillc`.
  - PAT location: `server/.env`, relative to the directory Claude Code is launched from, encrypted with dotenvx, with the matching `.env.keys` available for decryption.

  This matches the Rolai dev workflow and is the working state of the config. A universal version (`userConfig` schema, keychain-stored PAT, no dotenvx dependency) is on the follow-up list.

  **Server name + tool-prefix note.** The MCP server is registered as `azure-devops-triage` (renamed from the upstream default `azure-devops`) so it doesn't collide with `azure-devops-postmortem` shipped by [`azure-incident-postmortem`](../azure-incident-postmortem/) when both plugins are enabled. Tools therefore namespace as `mcp__azure_devops_triage__wit_get_work_item`, etc. The agent body lists them in their commonly-used short form (`wit_get_work_item`, `wit_query_by_wiql`, `wiki_search`, `core_list_projects`). If your install requires the full prefix, the frontmatter and inline references in `agents/azure-issue-triage.md` need the prefix added once. The setup wizard prints the prefix it detects so you can update the agent body in one pass.

### Recommended (the agent gracefully degrades without these)

- **Microsoft Teams MCP server.** Used for the Phase 10 summary message. There is no canonical first-party Teams MCP yet; community options include InditexTech/mcp-teams-server and msfeldstein/MCP-MS-Teams. Without one installed, the agent prints the summary inline instead of sending a Teams message.
- **Datadog MCP server.** Used for Phase 2 log search on Bug and Incident archetypes. Without it (or for User Story / Feature / Task / Spike archetypes), Phase 2 is silently skipped.

The plugin does not depend on Slack or Confluence. If you also use `jira-issue-triage`, both plugins coexist; their `prose-style` skills resolve via plugin namespacing.

### Bundled skills

The agent calls four skills during the workflow. All four ship bundled with this plugin and install automatically.

| Skill name | Phase | Used for | Status |
|-----------|-------|----------|--------|
| `azure-issue-investigator` | Phase 1 (Bug, Incident) | Teams/AzDO/Wiki/Datadog/code investigation with evidence tags | Bundled |
| `azure-requirements-investigator` | Phase 1 (User Story, Feature, Task, Spike) | Teams/AzDO/Wiki search for prior decisions, design refs, scope; per-archetype report templates (Feature template for User Story/Feature, Task template for Task, Spike template for Spike) | Bundled |
| `azure-work-item-refiner` | Phase 5 (any archetype) | Title and description rewrite. Archetype-aware across all five archetypes. | Bundled |
| `prose-style` | Phase 2.5 + Phase 5 (any archetype) | Writing-rule application: strips em dashes, opener phrases, LLM vocabulary, bullet sprawl. Mirror of `jira-issue-triage/skills/prose-style/`. | Bundled |

The agent body retains short defensive fallbacks for all four bundled skills.

## Quick start

1. Add the marketplace and install the plugin:

   ```
   /plugin marketplace add github.com/TahaBikanerwala/jt-bikanerwala-marketplace
   /plugin install azure-issue-triage
   ```

2. (Optional but recommended) Run the setup wizard:

   ```
   /azure-issue-triage:setup
   ```

   The wizard walks through six questions (organization URL, project, area path, severity field, transition mapping, Teams channel) and writes `.claude/azure-issue-triage.config.json`. You can re-run it any time to update.

   If you skip this step, the agent detects the missing config on first run and offers to walk through the same questions inline or use defaults.

3. Verify the agent appears: open the Agent tool list and confirm `azure-issue-triage` appears.

4. Paste any Azure DevOps work-item URL and ask the agent to triage:

   > Triage `https://dev.azure.com/<org>/<project>/_workitems/edit/12345`.

   The agent runs through phases 0-10, pauses at the Phase 3 confirmation gate, and waits for your approval before posting comments or changing fields.

## Setup wizard

The `/azure-issue-triage:setup` slash command walks through six questions and writes the result to `.claude/azure-issue-triage.config.json`:

1. Organization URL (e.g., `https://dev.azure.com/contoso`).
2. Project name (or "infer from URL").
3. Default area path prefix (optional).
4. Severity field — built-in `Microsoft.VSTS.Common.Severity` (default) or fall back to `Microsoft.VSTS.Common.Priority`.
5. State + Reason mapping for `investigating` and `waiting_reply`.
6. Teams channel for the Phase 10 summary (optional; null disables Teams).

Auto-discovery uses `core_list_projects` and `wit_my_work_items` to suggest defaults. Failures are non-fatal; the wizard falls back to static defaults and tells you.

The wizard never modifies Azure DevOps (read-only auto-discovery). Re-running it on an existing config offers to overwrite or keep current.

## Configuration

Configuration is **optional**. The agent uses sensible defaults if no config file is found. To override, run `/azure-issue-triage:setup` or create `.claude/azure-issue-triage.config.json` in your project root by hand:

```json
{
  "organization_url": null,
  "project": null,
  "default_team": null,
  "area_path_prefix": null,
  "severity_field": "Microsoft.VSTS.Common.Severity",
  "triaged_tag": "triaged",
  "skip_tags": [],
  "states": {
    "investigating": { "state": "Active", "reason": "Investigating" },
    "waiting_reply": { "state": "Active", "reason": "Awaiting Customer" }
  },
  "work_item_type_map": {
    "Bug": "Bug",
    "Incident": "Issue",
    "User Story": "User Story",
    "Feature": "Feature",
    "Task": "Task",
    "Spike": "Task"
  },
  "archetype_assignment_after_triage": {
    "Bug": "unassign",
    "Incident": "self",
    "User Story": "self",
    "Feature": "self",
    "Task": "self",
    "Spike": "self"
  },
  "severity_scheme": {
    "1 - Critical": { "due_offset_days": 7,  "escalate_immediately": true  },
    "2 - High":     { "due_offset_days": 14, "escalate_immediately": false },
    "3 - Medium":   { "due_offset_days": 30, "escalate_immediately": false },
    "4 - Low":      { "due_offset_days": 90, "escalate_immediately": false }
  },
  "escalation": {
    "teams_channel": null,
    "primary_contact": null,
    "fallback_contact": null
  },
  "iteration_path_strategy": null,
  "story_points_field": null,
  "pr_linking_enabled": true,
  "teams_channel": null,
  "description_preview_pause_seconds": 3
}
```

### Defaults (when config is absent)

- `organization_url` and `project`: required at first run if not configured. The agent inspects the work-item URL and asks you to confirm or override.
- `severity_field`: `Microsoft.VSTS.Common.Severity` (the Agile process template's built-in field). Falls back to `Microsoft.VSTS.Common.Priority` if Severity is not enabled on your project.
- `triaged_tag`: `triaged` (Azure DevOps stores tags as a semicolon-delimited string; the agent appends without overwriting existing tags).
- `skip_tags`: empty (no skip rule).
- `states`: shown above. Azure DevOps requires a `State` + `Reason` pair on most transitions, so each entry is an object. Mapping depends on your process template (Agile, Scrum, CMMI). The defaults match Agile.
- `work_item_type_map`: assumes the **Agile** process template. `Bug -> Bug`, `Incident -> Issue`, `User Story -> User Story`, `Feature -> Feature`, `Task -> Task`, `Spike -> Task` (Spike has no canonical work-item type; the agent treats a Task tagged `spike` as a Spike). Override for Scrum (`User Story` becomes `Product Backlog Item`; `Incident` becomes `Impediment` or stays as a Bug with an `incident` tag) or CMMI (`User Story` becomes `Requirement`; `Incident` becomes `Issue`). Unknown work-item types pause the run and ask you which archetype to apply.
- `archetype_assignment_after_triage`: `Bug = "unassign"`; `Incident, User Story, Feature, Task, Spike = "self"`. Override per archetype. Common overrides: `"Incident": "unassign"` to route Sev-1 incidents back to the on-call pool; `"Bug": "self"` when bug triage and bug fixing are the same person.
- `severity_scheme`: 4-tier (`1 - Critical` / `2 - High` / `3 - Medium` / `4 - Low`) with 7/14/30/90-day SLA offsets. Critical is flagged for immediate escalation. The keys must exactly match the option names in your Severity field.
- `escalation`: all null. The Phase 10 summary still lands in the per-run `teams_channel` (when configured), but no separate Sev-1 channel post or contact DM happens. Set `escalation.teams_channel` and `escalation.primary_contact` to enable.
- `iteration_path_strategy`: null. Sprint placement (Phase 6 on User Story / Feature / Task / Spike) is disabled. Set to `"current"` (and configure `default_team`) or `"explicit:<full iteration path>"` to enable.
- `story_points_field`: null. The Phase 3 story-points question and Phase 6 estimate write are disabled. Set to `"Microsoft.VSTS.Scheduling.StoryPoints"` (or your custom field's reference name) to enable.
- `pr_linking_enabled`: `true`. The agent surfaces Azure Repos PRs found during investigation as proposed `ArtifactLink` relations at the Phase 3 gate. Set to `false` to skip both the collection and the proposal.
- `teams_channel`: null. The agent prints the per-run summary inline (separate from `escalation.teams_channel`, which is for the high-severity routing).
- `description_preview_pause_seconds`: `3`. The pause between the Phase 5 informational preview and the actual write.

### Sprint placement

When `iteration_path_strategy = "current"`, Phase 6 calls `work_list_team_iterations` with `team: <default_team>` and `timeframe: "current"` to find the team's active sprint. The response carries the iteration path; Phase 6 writes it to `System.IterationPath`. If the team has no active sprint window (between two iterations), the agent warns once and skips the iteration write — the work item stays in its current iteration (which is usually the team's default backlog area for unscheduled work).

When `iteration_path_strategy = "explicit:MyProject\\Backend\\Sprint 42"`, the agent writes that exact path verbatim. Useful when the work item belongs to a future sprint, a hardening sprint, or a non-default team.

`default_team` must be set when `iteration_path_strategy = "current"` and the project has more than one team. The setup wizard prompts for it as a follow-up to Q9.

Sprint placement only applies to User Story / Feature / Task / Spike. Bug and Incident don't use iteration paths in v0.4.0.

### Story-point estimation

When `story_points_field` is set and the archetype is User Story or Feature, the Phase 3 main panel adds a fourth question: `1`, `3`, `5`, or `Skip`. The "Other" channel accepts any other integer or the Fibonacci values most teams use (`2`, `8`, `13`, `21`). Phase 6 writes the chosen value to the configured field via `wit_update_work_item`.

The estimate is voluntary; picking "Skip" leaves the field at its existing value (which may be unset). The `null` cache value means "no estimate captured" — never "estimated zero." Bug, Incident, Task, and Spike work items do not see the prompt.

### Azure Repos pull-request linking

The agent regex-matches Azure Repos PR URLs (`https://dev.azure.com/<org>/<project>/_git/<repo>/pullrequest/<id>`) in the description, comments, Teams threads, and investigator output. It calls `repos_get_pull_request_by_id` to resolve the title, project GUID, and repo GUID for each unique URL, capping the proposed list at 8 most-recent PRs.

The Phase 3 main panel surfaces up to 4 of these as a multi-select question. The user picks any subset to link (or the "Other" channel to add a PR URL the agent didn't propose). Phase 7 writes each approved PR as an `ArtifactLink` relation with the AzDO-required `vstfs:///Git/PullRequestId/<projectId>%2F<repoId>%2F<prId>` URL form. Surplus entries (more than 4 proposed) are listed in the Phase 10 summary as "skipped (panel cap)" so the user can link them manually.

Set `pr_linking_enabled = false` to disable both the collection step and the Phase 3 proposal entirely.

### Severity SLA and the 4-tier default

The default scheme aligns with the built-in `Microsoft.VSTS.Common.Severity` enum:

| Level | Due offset | Escalate immediately |
|-------|-----------|----------------------|
| `1 - Critical` | 7 days | yes |
| `2 - High` | 14 days | no |
| `3 - Medium` | 30 days | no |
| `4 - Low` | 90 days | no |

Phase 6 reads `severity_scheme[severity_recommendation].due_offset_days`, computes `System.CreatedDate + due_offset_days`, and writes the result to `Microsoft.VSTS.Scheduling.DueDate` (as a `YYYY-MM-DDT00:00:00Z` ISO timestamp; midnight UTC keeps the rendered date stable across viewers' time zones). When the recommended level is missing from `severity_scheme`, the agent skips the due-date write and notes the miss in the Phase 10 summary.

Override the keys to match a renamed Severity field's options. Add or remove tiers freely; the agent uses whatever keys you define at runtime.

### Escalation contacts

Set `escalation.primary_contact` (and optionally `fallback_contact`) to an object with `name` and `email`:

```json
{
  "escalation": {
    "teams_channel": "Incident Response > Escalations",
    "primary_contact": { "name": "Alice Kumar", "email": "alice@example.com" },
    "fallback_contact": { "name": "Bob Singh",  "email": "bob@example.com"  }
  }
}
```

The agent's Prerequisites step 4 looks up Alice's Teams user descriptor via her email once per session and caches it. On any severity level marked `escalate_immediately: true`:

- If `escalation.teams_channel` is set, the agent posts a separate Teams message to that channel mentioning Alice.
- If only `primary_contact` is set, the agent DMs Alice directly.
- If both are null, the running-user summary is the only escalation; the operator decides what to do.
- `fallback_contact` is not auto-paged on a timer; you can ask the agent ad hoc to ping the fallback later.

Escalation only applies to Bug and Incident archetypes (severity is not used for User Story / Feature / Task / Spike). When a contact's email cannot be resolved at session start, the channel post mentions them by name only and the Phase 10 summary appends an unresolvable-contact warning.

### EM-fallback when the reporter is deactivated

When a follow-up question is warranted and the reporter appears unreachable (no recent assignments and Teams MCP user lookup fails), the agent runs a three-step ladder before asking you:

1. **Teams profile manager.** If the Teams MCP exposes a profile call returning a `manager` field, the agent uses the manager's email as a candidate.
2. **AzDO team admin.** If the reporter belongs to one or more project teams, the agent proposes the team administrator (when distinct from the reporter and unique) as a candidate.
3. **Ask the user.** If the ladder produces a candidate, the agent surfaces it for confirmation. Otherwise it asks you to enter someone, or to skip the follow-up entirely.

EM-tagged comments carry a one-sentence preamble: "The original reporter on this work item is unreachable. Tagging you as their EM (or alternate contact) to route this forward." Tagging requires explicit user approval; the agent never auto-tags an EM.

### Process-template note

The defaults assume the **Agile** process template. If your project uses Scrum or CMMI, override `work_item_type_map` and (for Scrum) `severity_field`:

- **Scrum:** Replace `"User Story": "User Story"` with `"User Story": "Product Backlog Item"`. Replace `"Incident": "Issue"` with `"Incident": "Impediment"` (or `"Bug"` if your team uses Bugs tagged `incident` instead). Severity is not present by default; override `severity_field` to `Microsoft.VSTS.Common.Priority` and use the 1-4 priority field instead.
- **CMMI:** Replace `"User Story": "User Story"` with `"User Story": "Requirement"`. Bug, Task, Feature, Issue keep the same names. Severity is built in. Investigation states differ ("Proposed", "Active", "Resolved"). Override the `states` block.

The wizard does not auto-detect the process template; it presents Agile defaults and you override the relevant fields if your project differs.

### Skipping triage on certain work items

Use `skip_tags` to skip triage on work items carrying any matching tag:

```json
{ "skip_tags": ["external-vendor", "compliance-review"] }
```

A tag whose name *starts with* any prefix in `skip_tags` (case-insensitive) triggers the skip. The agent reports the matched tag and stops. You can override per-work-item by telling the agent to proceed anyway.

### Custom states

Mapping logical states to AzDO `State + Reason` pairs:

```json
{
  "states": {
    "investigating": { "state": "Active", "reason": "In Triage" },
    "waiting_reply": { "state": "Active", "reason": "Awaiting Customer Response" }
  }
}
```

The agent reads this map and writes both `System.State` and `System.Reason` in a single `wit_update_work_item` call.

### Datadog not installed

Phase 2 is silently skipped. The agent never mentions Datadog in any output. No configuration needed. Phase 2 also skips silently for User Story / Feature / Task / Spike archetypes regardless of installation.

### Teams not installed

Phase 10 prints the summary inline as agent output instead of sending a Teams message. The agent notes once at the end of the run: "Teams DM unavailable; install a Teams MCP server to enable."

## Workflow phases

The workflow runs a generic core for every archetype. Four phases gate on archetype.

| Phase | What it does | Archetypes |
|-------|--------------|------------|
| Prerequisites | Auto-discover identity, load config (with first-run wizard fallback if missing), confirm work-item-type and severity-field availability. | All |
| Phase 0 | Fetch work item via `wit_get_work_item`, run skip-tag check, detect archetype, assign to you (`System.AssignedTo`), transition to `investigating` state+reason. | All |
| Phase 1 | Investigation: `azure-issue-investigator` (Bug, Incident) or `azure-requirements-investigator` (User Story, Feature, Task, Spike). | All (skill choice gates on archetype) |
| Phase 2 | Datadog log search using signals from Phase 1. Silently suppressed on errors or when archetype is User Story / Feature / Task / Spike. | Bug, Incident |
| Phase 2.5 | Decide whether reporter follow-up is warranted. Form severity recommendation (Bug, Incident) or scope summary (User Story, Feature, Task, Spike). Draft the matching Phase 4 comment in markdown, then run `prose-style` on it. | All |
| Phase 3 | **Hard pause.** Show findings, archetype detection, and proposed updates. Asks all decisions side by side in a single `AskUserQuestion` panel. Metadata writes always run after the gate. | All |
| Phase 4a | Convert the cleaned draft to safe HTML and post the severity assessment as a discussion comment via `wit_add_work_item_comment`. | Bug, Incident |
| Phase 4b | Convert the cleaned draft to safe HTML and post the scope summary comment. The "What's in scope" body adapts to archetype (User Story / Feature: requirements found and design refs; Task: definition of done and why-now; Spike: question to answer and what's already known). | User Story, Feature, Task, Spike |
| Phase 4c | Convert the cleaned draft to safe HTML and post the follow-up question tagging the reporter. Replaces 4a or 4b. | All (only when follow_up_needed) |
| Phase 5 | Refine via `azure-work-item-refiner` (with `Calling context: skip_preview=true.` to suppress the skill's own preview gate), then run `prose-style` on the refined title and description, render the cleaned output inline as an informational preview, and write `System.Title` + `System.Description` after `description_preview_pause_seconds`. | All |
| Phase 6 | **Bug / Incident:** severity write (`Microsoft.VSTS.Common.Severity`) + due-date write (`Microsoft.VSTS.Scheduling.DueDate` computed from `severity_scheme`). **User Story / Feature / Task / Spike:** sprint placement (when `iteration_path_strategy` is set) writing `System.IterationPath`, plus optional story-point write (when `story_points_field` and `story_point_estimate` are both set). | All |
| Phase 7 | Link related/duplicate work items via `wit_update_work_item` adding `relations` entries (`System.LinkTypes.Related`, `System.LinkTypes.Hierarchy-Reverse`, `System.LinkTypes.Duplicate-Forward`). When `pr_linking_enabled = true`, also link the user-approved Azure Repos PRs as `ArtifactLink` relations using the `vstfs:///Git/PullRequestId/...` URL form. | All (PR links any archetype) |
| Phase 8 | Append the triaged tag to `System.Tags`. | All |
| Phase 9 | Final assignee per `archetype_assignment_after_triage[<archetype>]`. The follow-up path moves to `waiting_reply` here; the standard path leaves the work item in `investigating` from Phase 0. | All |
| Phase 10 | Per-run summary (Teams when `teams_channel` is set; otherwise inline). Then escalation routing: when the recommended severity has `escalate_immediately: true`, post a separate channel message to `escalation.teams_channel` (or DM the resolved primary contact) mentioning `escalation.primary_contact`. | All (escalation routing on Bug/Incident only) |

## Limitations

The agent will never:
- Close or resolve a work item without your approval.
- Modify `Microsoft.VSTS.Common.Priority` unless `severity_field` is configured to it.
- Post a comment without showing you the text first AND getting an explicit yes at the Phase 3 gate.
- Refine the title or description without an explicit yes at the Phase 3 gate. Phase 5 then renders the cleaned output inline as an informational preview and pauses for `description_preview_pause_seconds` (default 3) before writing.
- Tag the reporter until investigation is exhausted and a specific gap blocks meaningful triage. Reporter contact is a last resort. EM-fallback (when the reporter is deactivated) is best-effort and requires explicit user approval before tagging.
- Remove or overwrite reporter-provided information during refinement (only append).
- Fabricate reproduction steps without verification.
- Mention an integration (Datadog, Teams, etc.) in any output if its API errored or returned no results.
- Drop screenshots, attachments, or inline links from the original description during refinement.

## FAQ

**Q: Can I run the agent on work items I'm not assigned to?**
A: Yes. Phase 0 assigns the work item to you as part of triage. After triage, the work item either stays with you or returns to the team pool based on `archetype_assignment_after_triage[<archetype>]`. Defaults: Bug unassigns; Incident, User Story, Feature, Task, and Spike stay assigned. Override per archetype if your team uses a different ownership rule.

**Q: Can I run the agent on a non-bug work item?**
A: Yes. Phase 1 calls `azure-requirements-investigator` instead of `azure-issue-investigator` for User Story, Feature, Task, and Spike. Phase 4 posts a scope summary instead of a severity assessment, with content adapted to the archetype. Phase 6 (severity write) is skipped.

**Q: Can I run only part of the workflow?**
A: Yes. The Phase 3 confirmation gate asks separately whether to post the proposed comment and whether to refine the title and description. Answer No to either and the agent skips that write while still doing the other updates.

**Q: Do I need to run `/azure-issue-triage:setup` before the first work item?**
A: Optional. The agent detects missing config on first run and offers to walk through the wizard inline or use defaults.

**Q: What happens if the agent encounters an error mid-flight?**
A: It stops at the failing phase, tells you what went wrong, and asks how to proceed. It does not roll back changes already made (Azure DevOps revision history is the audit trail).

**Q: How does archetype detection work?**
A: Phase 0 maps the work item's `System.WorkItemType` to one of Bug, Incident, User Story, Feature, Task, or Spike using the inverse of `work_item_type_map`. If the work-item type doesn't match any value in the map (e.g., a custom type), the agent pauses and asks which archetype to apply. If the type and content disagree (e.g., a Bug filed with acceptance criteria and a Figma link), the agent trusts the content and asks you to confirm at Phase 3.

**Q: I use `jira-issue-triage` for one project and `azure-issue-triage` for another. Will they collide?**
A: No. The investigator and refiner skills are prefixed (`azure-issue-investigator`, `azure-work-item-refiner`, etc.). The `prose-style` skills in the two plugins share a name but are addressed via plugin namespacing (`jira-issue-triage:prose-style`, `azure-issue-triage:prose-style`); the agents call their own copy.

## Contributing

Issues and PRs welcome at the marketplace repo. The agent body is at `agents/azure-issue-triage.md`; the manifest is at `.claude-plugin/plugin.json`. Bundled skills live under `skills/`.

## License

MIT. See the [`LICENSE`](../../LICENSE) at the repo root.
