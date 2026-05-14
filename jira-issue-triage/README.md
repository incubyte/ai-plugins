# jira-issue-triage

A Claude Code plugin that ships one subagent (`jira-issue-triage`) and two slash commands: `/jira-issue-triage:setup` (config wizard) and `/jira-issue-triage:investigate-and-refine` (one-shot investigate + refine + post). Paste any Jira ticket URL (Bug, Incident, Feature, Task, or Spike) and tell the agent to triage. The agent assigns the ticket to you, transitions it to investigating, runs the matching investigation skill, drafts an archetype-appropriate assessment comment, refines the title and description, applies the triaged label, and DMs you a one-line summary on Slack. The agent pauses at the Phase 3 confirmation gate (before posting any comment, changing the description, or updating other fields) to show you the full findings and get your approval.

When you want a lighter workflow that stops short of severity, transitions, and metadata writes, run `/jira-issue-triage:investigate-and-refine <TICKET>` instead. It chains the investigator skill (issue-investigator or requirements-investigator), `jira-ticket-refiner`, and `prose-style` end-to-end, then asks whether to update the title and description, post the investigation as a comment, both, or cancel. No assignment, no transitions, no Slack DM, no field writes outside title/description and one optional comment.

## Migration from `jira-bug-triage` v0.3.0

If you previously installed `jira-bug-triage`, the v1.0.0 release renames the plugin and the agent. Run:

```
/plugin uninstall jira-bug-triage
/plugin install jira-issue-triage
```

The agent name changes from `bug-triage-agent` to `jira-issue-triage`. Any scripts or `CLAUDE.md` memory entries that call the old name need to be updated.

The config file moves from `.claude/jira-bug-triage.config.json` to `.claude/jira-issue-triage.config.json`. The agent reads both paths through one minor version (1.x) and warns once per session when only the legacy file is present. Rename the file at your convenience; the schema is a strict superset (every v0.3.0 key still applies). Legacy support is removed in 2.0.0.

## Prerequisites

### Required

- **Atlassian MCP server.** The agent needs full Jira access (read tickets, edit fields, post comments, transition, link, look up users). Install via Claude Code's plugin system (e.g., `/plugin install atlassian` if available in your marketplace) and follow the Atlassian plugin's setup docs to authenticate against your Jira site.

### Recommended (the agent gracefully degrades without these)

- **Slack MCP server.** Used for Phase 1 investigation (search threads), reporter EM lookup, and the Phase 10 summary DM. Without it, the agent skips Slack search and prints the summary instead of DM'ing it.
- **Datadog MCP server.** Used for Phase 2 log search on Bug and Incident archetypes. Without it (or for Feature, Task, Spike archetypes), Phase 2 is silently skipped.

### Bundled skills

The agent calls four skills during the workflow. All four ship bundled with this plugin and install automatically.

| Skill name | Phase | Used for | Status |
|-----------|-------|----------|--------|
| `issue-investigator` | Phase 1 (Bug, Incident) | Slack/Jira/Confluence/Datadog/code investigation with evidence tags | Bundled, ready to use |
| `requirements-investigator` | Phase 1 (Feature, Task, Spike) | Slack/Jira/Confluence search for prior decisions, design refs, scope; per-archetype report templates | Bundled, ready to use |
| `jira-ticket-refiner` | Phase 5 (any archetype) | Title and description rewrite. Already archetype-aware (Bug, Feature, Task, Incident, Spike). | Bundled, ready to use |
| `prose-style` | Phase 2.5 + Phase 5 (any archetype) | Writing-rule application: strips em dashes, opener phrases, LLM vocabulary, bullet sprawl. Runs at Phase 2.5 on the assessment/scope comment draft and any reporter follow-up (so the user sees a styled version at the Phase 3 confirmation gate), and at Phase 5 on the refined title and description after `jira-ticket-refiner`. | Bundled, ready to use |

The agent body retains short defensive fallbacks for all four bundled skills. They fire only on rare runtime load failures (corrupted install, mid-session uninstall, etc.) and never need user attention in normal operation.

## Quick start

1. Add the marketplace and install the plugin:

   ```
   /plugin marketplace add github.com/TahaBikanerwala/jt-bikanerwala-marketplace
   /plugin install jira-issue-triage
   ```

2. (Optional but recommended) Run the setup wizard:

   ```
   /jira-issue-triage:setup
   ```

   The wizard walks through 8 questions (project key, severity field, transitions, escalation contacts, etc.) and writes `.claude/jira-issue-triage.config.json`. You can re-run it any time to update.

   If you skip this step, the agent detects the missing config on first run and offers three options: run `/jira-issue-triage:setup`, walk through the same questions inline, or use defaults.

3. Verify the agent appears: open the Agent tool list and confirm `jira-issue-triage` appears.

4. Paste any Jira ticket URL and ask the agent to triage:

   > Triage `https://yourcompany.atlassian.net/browse/PROJ-12345`.

   The agent runs through phases 0-10, pauses at the Phase 3 confirmation gate, and waits for your approval before posting comments or changing fields. The investigation skill, the Phase 4 comment, and the Phase 6 metadata updates depend on the ticket's archetype (see Workflow phases below).

5. (Alternative) For a lighter flow, run the one-shot command:

   ```
   /jira-issue-triage:investigate-and-refine https://yourcompany.atlassian.net/browse/PROJ-12345
   ```

   See "Investigate-and-refine command" below for the full scope.

## Investigate-and-refine command

`/jira-issue-triage:investigate-and-refine <TICKET>` is the lightweight counterpart to the full agent. It chains three skills end-to-end and writes the result back to Jira, without touching severity, transitions, sprints, due dates, labels, links, or assignments.

The flow:

1. **Fetch and detect archetype.** One `getJiraIssue` call; archetype mapped from issue type with a content-override fallback (Bug, Incident, Feature, Task, Spike).
2. **Investigate.** Invokes `issue-investigator` for Bug/Incident or `requirements-investigator` for Feature/Task/Spike. Both skills run read-only and produce evidence-tagged reports (`[VERIFIED]`, `[OBSERVED]`, `[INFERRED]`, `[UNKNOWN]`).
3. **Refine.** Invokes `jira-ticket-refiner` in read-only-return mode (`Calling context: skip_preview=true.`) with the investigation findings folded in as source material. The skill returns the refined title and description as plain text.
4. **Style cleanup.** Invokes `prose-style` to strip writing-style anti-patterns (em dashes, opener phrases, LLM vocabulary, bullet sprawl) from the refined title and description.
5. **Preview and confirm.** Renders the cleaned title and description inline, then asks one `AskUserQuestion` with four options:
   - `Update title and description` (one `editJiraIssue` call).
   - `Post the investigation findings as a comment` (one `addCommentToJiraIssue` call, ADF only).
   - `Both` (comment first, then the description update).
   - `Cancel without writing`.
6. **Write.** Executes the chosen action. The comment is always ADF (`contentFormat: "adf"`); the description write uses `contentFormat: "markdown"` (the Atlassian MCP converts to ADF on write).

What this command does NOT touch: assignee, priority, severity, status, transitions, due date, sprint, story points, labels, components, custom fields, related links, or Slack. Use the full `jira-issue-triage` agent for any of those.

The command requires the same Atlassian MCP server the full agent needs. The investigator skills' Slack/Confluence/Datadog calls run through their own bundled tools when invoked via the `Skill` tool, so no additional permissions are needed on the command itself.

### Worked example: Bug archetype

Suppose the user runs:

```
/jira-issue-triage:investigate-and-refine https://acme.atlassian.net/browse/SUP-4501
```

`SUP-4501` is a poorly written bug ticket with the title `login broken` and a one-line description: `tenant MapleTower can't sign in, this started yesterday`.

**Phase 0** prints one line so the user knows what is running:

```
Investigating SUP-4501 (Bug). This will take a minute.
```

**Phase 1** invokes `issue-investigator`. The skill searches Slack for `SUP-4501` and `MapleTower`, finds an in-progress thread where on-call has named the SSO middleware deploy from the previous evening, and writes its six-section report. The relevant findings (paraphrased):

```
1. Lead
Sessions for tenant MapleTower started failing at the join step yesterday after deploy
2026-04-29T18:00Z; the new SSO middleware is the most likely cause [OBSERVED].

5. What We Found
A Slack thread in #sso-rollout (link cited) confirms on-call paused the rollout
for MapleTower at 2026-04-29T19:14Z [VERIFIED]. The middleware fails token
exchange when the tenant's IDP returns SAML attributes in a non-standard order
[OBSERVED]. Two prior tickets in the same area (SUP-4310, SUP-4422) match the
symptom and were closed as fixed before the latest deploy [VERIFIED].
```

**Phase 2** invokes `jira-ticket-refiner` with `Calling context: skip_preview=true.` and the investigation report as source material. The skill returns:

```
Title: Auth: MapleTower sessions fail at join step after 2026-04-29 SSO deploy

Description:
## Summary
Sessions for tenant `MapleTower` fail at the join step. The failure started
2026-04-29T18:00Z, immediately after the SSO middleware deploy.

## Impact
All MapleTower users cannot complete sign-in. Other tenants are unaffected per
the on-call thread linked below.

## Reproduction
1. From MapleTower's SSO start URL, complete the IDP authentication step.
2. Observe a 500 response on the `/sso/join` callback.

## Investigation Notes
- On-call paused the rollout for MapleTower at 2026-04-29T19:14Z (Slack thread
  in #sso-rollout). [VERIFIED]
- The middleware fails token exchange when the tenant's IDP returns SAML
  attributes in a non-standard order. [OBSERVED]
- Prior tickets `SUP-4310` and `SUP-4422` match the symptom and were closed
  before the latest deploy. [VERIFIED]

## Working Hypotheses
1. The SSO middleware's attribute-order handling regressed in the
   2026-04-29T18:00Z deploy. [OBSERVED]
2. MapleTower's IDP changed its attribute order independently. [INFERRED]
```

**Phase 3** invokes `prose-style`. The cleaned output collapses one bullet-sprawl block back into prose and strips one opener phrase. Substance does not change.

**Phase 4** renders the preview to the user as inline markdown, then asks one question:

```
What should I do with this on SUP-4501?
  1. Update title and description
  2. Post the investigation findings as a comment
  3. Both
  4. Cancel without writing
```

If the user picks `Both`, the command posts the comment first (ADF, with the investigation findings under an `Investigation Findings (Bug)` heading), then calls `editJiraIssue` with the cleaned title and description. Final line printed to the user:

```
Posted investigation findings and updated title/description on SUP-4501.
```

If the user picks `Update title and description`, the comment step is skipped and the final line reads `Updated title and description on SUP-4501.` instead.

### Worked example: Feature archetype

The same command works on Feature/Task/Spike tickets; the only differences are which investigator runs and how the description is structured.

For a Feature ticket (`PROJ-820`, title `add csv export`), Phase 1 invokes `requirements-investigator` instead of `issue-investigator`. The investigator searches Slack and Confluence for prior decisions in the export area, follows linked design docs, and returns its Feature-template report (Lead / Background / Requirements Found / Design Refs / Open Questions). Phase 2's refiner uses the Feature section set (Summary / Context and Background / Requirements and Acceptance Criteria / Open Blockers) rather than the Bug section set. Phase 3 and Phase 4 are identical.

Datadog is silently skipped on non-bug archetypes, since `requirements-investigator` does not include a Datadog level in its ladder by default.

### Cancel and revision paths

The Phase 4 question is the only user-facing pause. Two non-obvious behaviours:

- **Cancel.** Picking `Cancel without writing` ends the run with no Jira mutations. The investigation report and refined draft are still visible in the transcript, so the user can copy them by hand if they want.
- **Revision via "Other".** The runtime automatically adds an "Other" channel to the four options. If the user types something like `refine but skip the title` or `re-run with the production-incident framing`, the command treats the free-text as guidance, re-enters Phase 2 with the guidance prefixed `User refinement guidance:` on the prompt to `jira-ticket-refiner`, and re-presents the panel. The loop caps at three rounds; on the fourth disagreement the panel collapses to a two-option `Approve as-is / Cancel` question.

## Setup wizard

The `/jira-issue-triage:setup` slash command walks through eight questions and writes the result to `.claude/jira-issue-triage.config.json`:

1. Default project key (or "infer from URL").
2. Severity field name (auto-discovers candidates).
3. Triaged label.
4. Skip labels (comma-separated).
5. Transition names (investigating, waiting reply, backlog).
6. Severity scheme (3-tier default, 5-tier, or custom).
7. Escalation: Slack channel, primary contact, fallback contact.
8. Save confirmation.

Auto-discovery uses `getAccessibleAtlassianResources` and `atlassianUserInfo` to suggest defaults for project key and severity field name. Failures are non-fatal; the wizard falls back to static defaults and tells you.

The wizard never modifies Jira (read-only auto-discovery). Re-running it on an existing config offers to overwrite or keep current.

## Configuration

Configuration is **optional**. The agent uses sensible defaults if no config file is found. To override, run `/jira-issue-triage:setup` or create `.claude/jira-issue-triage.config.json` in your project root by hand:

```json
{
  "project_key": null,
  "severity_field_name": null,
  "triaged_label": "triaged",
  "skip_labels": [],
  "transitions": {
    "investigating": "Under Investigation",
    "waiting_reply": "Waiting for Reply",
    "backlog": "Backlog"
  },
  "severity_scheme": {
    "Sev-1": { "due_offset_days": 7,  "escalate_immediately": true  },
    "Sev-2": { "due_offset_days": 14, "escalate_immediately": false },
    "Sev-3": { "due_offset_days": 90, "escalate_immediately": false }
  },
  "escalation": {
    "slack_channel": null,
    "primary_contact": null,
    "fallback_contact": null
  },
  "scope_summary_field_name": null,
  "sprint_field_name": null,
  "story_points_field_name": null,
  "non_bug_transitions": {
    "ready": null
  },
  "archetype_assignment_after_triage": {
    "Bug": "unassign",
    "Incident": "self",
    "Feature": "self",
    "Task": "self",
    "Spike": "self"
  },
  "description_preview_pause_seconds": 3
}
```

### Defaults (when config is absent)

- `project_key`: inferred from the ticket URL prefix (e.g., `BUG-123` -> `BUG`).
- `severity_field_name`: auto-discovered. Order: `Severity Level` -> `Severity` -> `Bug Severity`. Falls back to native `priority` if no Severity custom field is found.
- `triaged_label`: `triaged`.
- `skip_labels`: empty (no skip rule).
- `transitions`: names shown above.
- `severity_scheme`: 3-tier (Sev-1 / Sev-2 / Sev-3) with 7/14/90 day due-date offsets.
- `escalation`: all null. On Sev-1 the agent flags the severity in the assessment comment and DMs you on Slack. No comment tags, no channel pings.
- `scope_summary_field_name`, `sprint_field_name`, `story_points_field_name`, `non_bug_transitions.ready`: all null. The agent skips the steps that reference them. See Advanced Configuration below.

### Escalating to a person

Set `escalation.primary_contact` (and optionally `fallback_contact`) to an object with `name` and `email`:

```json
{
  "escalation": {
    "slack_channel": "#bug-triage",
    "primary_contact": { "name": "Alice Kumar", "email": "alice@example.com" },
    "fallback_contact": { "name": "Bob Singh", "email": "bob@example.com" }
  }
}
```

The agent looks up Alice's Jira `accountId` (via `lookupJiraAccountId`) and Slack `user_id` (via `slack_search_users`) once per session and caches both. On Sev-1 (any level marked `escalate_immediately: true`):

- Posts an escalation message to `#bug-triage` tagging Alice's Slack handle.
- If Alice doesn't acknowledge within the SLA your team uses (the agent doesn't track this; your runbook does), you can ask the agent to ping `fallback_contact` the same way.

**Ad-hoc escalation:** mid-conversation you can also say "escalate this to Alice" and the agent will look her up, confirm the match, and post, without changing your config file.

Escalation only applies to Bug and Incident archetypes (severity is not used for Feature, Task, Spike).

### 5-tier severity scheme

```json
{
  "severity_scheme": {
    "Sev-1":   { "due_offset_days": 7,  "escalate_immediately": true  },
    "Sev-1.5": { "due_offset_days": 7,  "escalate_immediately": true  },
    "Sev-2":   { "due_offset_days": 14, "escalate_immediately": false },
    "Sev-2.5": { "due_offset_days": 30, "escalate_immediately": false },
    "Sev-3":   { "due_offset_days": 90, "escalate_immediately": false }
  }
}
```

The agent uses the keys you define. Make sure they exactly match the option names in your Severity custom field.

### Custom transition names

```json
{
  "transitions": {
    "investigating": "In Triage",
    "waiting_reply": "Pending Customer",
    "backlog": "Open"
  }
}
```

Match against actual transition names from your Jira workflow. Case-insensitive partial match is allowed.

### Skipping triage on certain tickets

Use `skip_labels` to skip triage on tickets carrying any matching label:

```json
{ "skip_labels": ["applause", "external-vendor", "compliance-review"] }
```

A label whose name *starts with* any prefix in `skip_labels` (case-insensitive) triggers the skip. The agent reports the matched label and stops. You can override per-ticket by telling the agent to proceed anyway.

### Jira instances without a Severity custom field

The agent tries `Severity Level` -> `Severity` -> `Bug Severity` automatically. If none exist, it falls back to native `priority` for severity decisions on Bug and Incident tickets. Phase 6 will then update `priority` instead of a custom field. The Do-Not-modify-`priority` rule is relaxed only in this fallback case.

### Datadog not installed

Phase 2 is silently skipped. The agent never mentions Datadog in any output. No configuration needed. Phase 2 also skips silently for Feature, Task, and Spike archetypes regardless of installation.

### Optional Jira fields not present on your project

Optional fields (`Bug Description`, `Scope Summary`, `Work Type`, `Components`, `Customers`, `Impacted Party`, `Sprint`, `Story Points`) are looked up by name. If a field doesn't exist, the agent skips the steps that update it. No configuration needed.

### Advanced configuration (per-archetype tuning)

Six optional fields tune the agent's behavior. The setup wizard writes them into the saved JSON with their default values so the file is a complete, browsable config; override them by editing the file directly when you want different behavior.

| Field | Purpose | When to set |
|-------|---------|-------------|
| `scope_summary_field_name` | Custom Jira field name (e.g., `Scope Summary`, `Acceptance Criteria`). When set, Phase 4b also writes the scope summary to this field as raw ADF in addition to posting it as a comment. | Your project tracks scope summaries in a custom field, not just comments. |
| `sprint_field_name` | Custom Jira field name (e.g., `Sprint`). When set, Phase 6 (on Feature/Task/Spike tickets) places the ticket into the active sprint of the configured project. | Your team uses sprints and triage should auto-place new tickets into the current sprint. |
| `story_points_field_name` | Custom Jira field name (e.g., `Story Points`). When set, the Phase 3 confirmation gate prompts you for a point estimate, and Phase 6 writes it. | Your team estimates non-bug tickets at triage time. |
| `non_bug_transitions.ready` | Transition name (e.g., `Ready for Development`). When set, Phase 9 transitions Feature/Task/Spike tickets to this state instead of leaving them in `investigating`. | Your workflow has a distinct "ready to pick up" state for non-bug work. |
| `archetype_assignment_after_triage` | Object mapping each archetype (`Bug`, `Incident`, `Feature`, `Task`, `Spike`) to either `"unassign"` (return to the team pool) or `"self"` (keep assigned to the running user). Defaults: `Bug = "unassign"`, all others `"self"`. Missing keys are filled from defaults. Validation runs at session start (Phase 0); warnings about invalid values are surfaced once in the Phase 10 Slack DM, not as inline output. See the Validation block below. | Your team's ownership rule differs from the default. Sev-1 incidents that auto-route to on-call: set `"Incident": "unassign"`. Bug-fix ownership stays with triager: set `"Bug": "self"`. |
| `description_preview_pause_seconds` | Integer seconds to pause between the Phase 5 informational preview and the `editJiraIssue` write. Default `3`. Set higher (`5`-`10`) if you want more time to read the preview before the write commits. Set to `0` to write immediately (not recommended). | Your team wants more time to skim the rendered description before it lands on the ticket. |

**Backwards compatibility.** When any of these is null, the agent uses the default behavior described above. The two keys with non-null defaults (`archetype_assignment_after_triage`, `description_preview_pause_seconds`) also backfill on omission: existing 1.2.0 configs that don't include either key get `archetype_assignment_after_triage = {Bug: "unassign", Incident: "self", Feature: "self", Task: "self", Spike: "self"}` and `description_preview_pause_seconds = 3` applied at runtime. No migration steps required; the saved JSON does not need to be edited to upgrade.

**Validation.** The agent normalizes invalid values at session start and warns once via the Phase 10 DM rather than failing the run:

- `description_preview_pause_seconds`: must be a non-negative integer. Negative, float, string, or null falls back to `3`.
- `archetype_assignment_after_triage`: must be an object whose values are `"unassign"` or `"self"`. A non-object value (string, array, null) is treated as omitted and the full default object applies. Per-key invalid values warn and use the archetype default. Unknown archetype keys (typos like `"Bg"`) are ignored with a warning.
- `scope_summary_field_name`, `sprint_field_name`, `story_points_field_name`, `non_bug_transitions.ready`: must be strings or null. Non-string values are treated as null with a warning, and the steps that reference them are skipped.

## Workflow phases

The workflow runs a generic core for every archetype. Five phases gate on the detected archetype.

| Phase | What it does | Archetypes |
|-------|--------------|------------|
| Prerequisites | Auto-discover identity, load config (with first-run wizard fallback if missing), look up severity field and transitions by name. | All |
| Phase 0 | Fetch ticket, run skip-label check, detect archetype, assign to you, transition to investigating. | All |
| Phase 1 | Investigation: `issue-investigator` (Bug/Incident) or `requirements-investigator` (Feature/Task/Spike). | All (skill choice gates on archetype) |
| Phase 2 | Datadog log search using signals from Phase 1. Silently suppressed on errors. | Bug, Incident |
| Phase 2.5 | Decide whether reporter follow-up is warranted (missing data / clarification / fix verification or relevance check). Form severity recommendation (Bug/Incident) or scope summary (Feature/Task/Spike). Draft the matching Phase 4 comment (assessment, scope summary, or follow-up question) in markdown, then run `prose-style` on it so Phase 3 previews a styled draft. | All |
| Phase 3 | **Hard pause.** Show findings, archetype detection, and proposed updates. Asks all decisions side by side in a single `AskUserQuestion` panel: post the proposed comment? refine the title and description? story-point estimate (when configured)? approve the follow-up tag (when applicable)? You can approve some and skip others. Archetype-correction question (when issue type and content disagree) runs as a separate pre-gate so the draft on the main panel matches the corrected archetype. Metadata writes and the final transition always run after the gate. | All |
| Phase 4a | Convert the Phase 2.5 cleaned draft to ADF and post the severity assessment comment. | Bug, Incident |
| Phase 4b | Convert the Phase 2.5 cleaned draft to ADF and post the scope or AC summary comment. Optionally writes to `scope_summary_field_name` if configured. | Feature, Task, Spike |
| Phase 4c | Convert the Phase 2.5 cleaned draft to ADF and post the follow-up question tagging reporter or EM. Replaces Phase 4a or 4b. | All (only when follow_up_needed) |
| Phase 5 | Refine ticket via `jira-ticket-refiner` (the agent passes `Calling context: skip_preview=true.` as the leading line of the skill prompt so the skill's own preview-and-write gate is suppressed), then run `prose-style` on the refined title + description, render the cleaned output inline as an informational preview, then write after a `description_preview_pause_seconds` pause (default 3). The render is **not** a second confirmation; Phase 3 already captured your approval to refine. Interrupt during the pause to abort if something looks wrong. | All |
| Phase 6 | Severity + due date (Bug/Incident) OR optional sprint placement + story points (Feature/Task/Spike). Skipped on follow-up path. | All (behavior gates on archetype) |
| Phase 7 | Link related/duplicate tickets. | All |
| Phase 8 | Append triaged label. Fill optional fields if discoverable. | All |
| Phase 9 | Final assignee + transition. Assignment reads `archetype_assignment_after_triage[<archetype>]` from config: `"unassign"` returns the ticket to the team pool, `"self"` leaves it with you. Defaults: Bug unassigns; Incident, Feature, Task, Spike stay assigned. Transition: Backlog for low-severity Bug/Incident, configured ready transition for Feature/Task/Spike if set, Waiting for Reply on follow-up path, otherwise stay in investigating. | All (assignment configurable per archetype) |
| Phase 10 | Slack DM summary. Optional channel/contact escalation per config. | All |

## Limitations

The agent will never:
- Close or resolve a ticket without your approval.
- Modify the `priority` field unless `priority` is the configured severity field.
- Post a comment without showing you the text first AND getting an explicit yes at the Phase 3 gate.
- Refine the title or description without an explicit yes at the Phase 3 gate. Phase 5 then renders the cleaned output inline as an informational preview and pauses for `description_preview_pause_seconds` (default 3) before writing, so you have a chance to interrupt if something looks wrong; users who want a second confirmation prompt can opt in per run via the "Other" channel on Phase 3 question 2.
- Tag the reporter or their EM until investigation is exhausted and a specific gap blocks meaningful triage. Reporter contact is a last resort.
- Tag anyone other than the reporter or their EM in a follow-up question.
- Remove or overwrite reporter-provided information during refinement (only append).
- Fabricate reproduction steps without verification.
- Mention an integration (Datadog, Slack, etc.) in any output if its API errored or returned no results.
- Drop screenshots, videos, attachments, or inline links from the original description during refinement.
- Assign story points or pick a sprint without your approval at the Phase 3 gate.

## FAQ

**Q: Can I run the agent on tickets I'm not assigned to?**
A: Yes. Phase 0 assigns the ticket to you as part of triage. After triage, the ticket either stays with you or returns to the team pool based on `archetype_assignment_after_triage[<archetype>]`. Defaults: Bug unassigns; Incident, Feature, Task, and Spike stay assigned. Override per archetype if your team uses a different ownership rule (see Advanced configuration above).

**Q: Can I run the agent on a Feature ticket?**
A: Yes. Phase 1 calls `requirements-investigator` instead of `issue-investigator`. Phase 4 posts a scope summary instead of a severity assessment. Phase 6 is skipped (or does sprint placement + story points if `sprint_field_name` and `story_points_field_name` are configured). Phase 9 keeps you assigned by default; override `archetype_assignment_after_triage.Feature` to `"unassign"` if your team prefers Feature tickets to return to the team pool after triage.

**Q: Can I run only part of the workflow, e.g., refine the description but skip the comment?**
A: Yes. The Phase 3 confirmation gate asks separately whether to post the proposed comment and whether to refine the title and description. Answer No to either and the agent skips that write while still doing the metadata updates (severity / sprint / labels / links), the final transition, and the Slack DM summary.

**Q: Do I need to run `/jira-issue-triage:setup` before the first ticket?**
A: Optional. The agent detects missing config on first run and offers three choices: run the setup command, walk through the same wizard inline, or use defaults.

**Q: What happens if the agent encounters an error mid-flight?**
A: It stops at the failing phase, tells you what went wrong, and asks how to proceed. It does not roll back changes already made (Jira ticket history is the audit trail).

**Q: Does the agent re-triage tickets that already have the triaged label?**
A: It runs the workflow again. Add the triaged label to `skip_labels` if you want it to skip re-triaged tickets.

**Q: How do I undo an agent action?**
A: Use Jira's history view to see what changed and revert manually. The agent does not have an undo command.

**Q: How does archetype detection work?**
A: Phase 0 maps the Jira `issuetype` field to one of Bug / Incident / Feature / Task / Spike using a built-in table. If the issue type and content disagree (e.g., issue type Bug but the ticket has acceptance criteria and a Figma link), the agent trusts the content and asks you to confirm at Phase 3.

## Contributing

Issues and PRs welcome at the marketplace repo. The agent body is at `agents/jira-issue-triage.md`; the manifest is at `.claude-plugin/plugin.json`. Bundled skills live under `skills/`.

## License

MIT. See the [`LICENSE`](../../LICENSE) at the repo root.
