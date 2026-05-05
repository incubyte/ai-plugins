---
description: First-time setup wizard for jira-issue-triage. Walks through configuration questions and writes .claude/jira-issue-triage.config.json.
argument-hint: (no args)
allowed-tools: Read, Write, AskUserQuestion, mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources, mcp__plugin_atlassian_atlassian__atlassianUserInfo
---

# jira-issue-triage Setup Wizard

Walk the user through eight configuration questions and write the result to `.claude/jira-issue-triage.config.json`. Re-runnable: pointing the wizard at an existing config offers to overwrite or keep current.

## Steps

### 1. Check for existing config

Read `.claude/jira-issue-triage.config.json` if it exists. Also check `.claude/jira-bug-triage.config.json` (the legacy path used by the v0.3.0 plugin).

- **New-path config exists:** Read it, show the current contents to the user as pretty-printed JSON, then ask via `AskUserQuestion`: "Overwrite the existing config?" Options: `Yes, walk through the wizard again`, `No, keep current and exit`. On "No", exit cleanly.
- **Only the legacy file exists:** Read it, show the contents, and tell the user: "The legacy file works for now but the new path `.claude/jira-issue-triage.config.json` is preferred. The wizard will write the new path; you can delete the legacy file once the new one is written." Continue to step 2.
- **Neither exists:** Continue to step 2.

### 2. Auto-discover defaults

Best-effort auto-discovery to suggest defaults. Failures are non-fatal; fall back to the static defaults listed in each question and tell the user the auto-discovery failed.

1. Call `getAccessibleAtlassianResources` to get the cloudId and the list of accessible Atlassian sites.
2. Call `atlassianUserInfo` to get the user's account info.
3. From the user's accessible sites, pick the first site as the suggested Atlassian/Jira context for later operations. The two calls above do not return a Jira project list, so the wizard does not auto-detect a project key. Keep the Q1 default as `infer` and only switch to a real key if the user types one in.
4. Pre-populate the severity field name auto-discovery order: `Severity Level` -> `Severity` -> `Bug Severity` -> `priority`. The wizard surfaces these as Q2 options.

### 3. Walk through the eight wizard questions

Ask one at a time. Use `AskUserQuestion` for multiple-choice answers. Use plain free-text prompts for names, emails, labels, and channel names. Confirm each answer before moving to the next question.

#### Q1: Default project key

Free-text prompt:

> Default Jira project key? Type a key like `ENG` or `BUG`, or type `infer` to derive it from each ticket URL.

Default: `infer`. Validate that the answer is either `infer` or a non-empty alphanumeric string (uppercase Jira keys allowed).

**Serialization rule.** `infer` is a UI sentinel, not a saved value. When the user answers `infer` (or accepts the default), write `"project_key": null` in the saved JSON config. The agent's Phase 0 inspects `project_key` and infers from each ticket URL when the value is `null`; saving the literal string `"infer"` would be treated as a real Jira project key in JQL and break ticket lookups. When the user types a real key, save it as a JSON string (e.g., `"project_key": "ENG"`).

#### Q2: Severity field name

Use `AskUserQuestion`:

> Which Jira field holds the severity for bug tickets?

Options:
- `Severity Level` (recommended default for many Jira instances)
- `Severity`
- `Bug Severity`
- `priority` (use the native Jira priority field as severity)
- `Custom (type the name)`

On "Custom", ask for the field name as free text. Validate the answer is non-empty.

#### Q3: Triaged label

Free-text prompt:

> Label to add to tickets after triage? Default: `triaged`.

Default: `triaged`.

#### Q4: Skip labels

Free-text prompt:

> Comma-separated list of label prefixes that should skip triage entirely (e.g., `applause,external-vendor`). Press Enter for none.

Default: empty list. Parse the answer by splitting on `,` and trimming whitespace; reject any entry containing whitespace inside the value (warn and re-prompt).

**Serialization rule.** Save as a JSON array of strings, even when empty. An empty answer (Enter pressed) writes `"skip_labels": []`, not `null` and not `""`.

#### Q5: Transition names

Three free-text prompts in sequence:

1. > Transition name for "investigating"? Default: `Under Investigation`.
2. > Transition name for "waiting for reply"? Default: `Waiting for Reply`.
3. > Transition name for "backlog"? Default: `Backlog`.

#### Q6: Severity scheme

Use `AskUserQuestion`:

> Which severity scheme do you want to use?

Options:
- `3-tier (Sev-1, Sev-2, Sev-3) with 7/14/90 day SLAs` (recommended default)
- `5-tier (Sev-1, Sev-1.5, Sev-2, Sev-2.5, Sev-3)`
- `Custom (specify each level)`

On "5-tier", use the static 5-tier scheme that strictly extends the 3-tier defaults so users do not get surprise SLA changes when they switch tiers: `Sev-1` (7 days, escalate), `Sev-1.5` (7 days, escalate), `Sev-2` (14 days), `Sev-2.5` (30 days), `Sev-3` (90 days). This matches the 5-tier example in the plugin README.

On "Custom", walk through each level: ask for the level name, the `due_offset_days` integer, and via `AskUserQuestion` whether `escalate_immediately` is `Yes` or `No`. Loop until the user types `done` for the level name.

#### Q7: Escalation

Three free-text sub-prompts. Each accepts an empty answer (Enter for none).

1. > Slack channel for high-severity escalation pings? (e.g., `#bug-triage`) Press Enter for none.
2. > Primary escalation contact? Format: `Alice Kumar <alice@example.com>`. Press Enter for none.
3. > Fallback escalation contact? Same format. Press Enter for none.

Parse the contact strings into `{ "name": "Alice Kumar", "email": "alice@example.com" }`. If the format does not match, warn and re-prompt.

**Serialization rule.** Empty answers map to JSON `null`, not empty strings or empty objects. Specifically: an empty Slack channel writes `"slack_channel": null`; an empty primary contact writes `"primary_contact": null`; an empty fallback contact writes `"fallback_contact": null`. The agent treats `null` on any of these three fields as "no escalation configured for this slot".

#### Q8: Save?

Show the assembled config as pretty-printed JSON with sorted top-level keys. Use `AskUserQuestion`:

> Save this config to `.claude/jira-issue-triage.config.json`?

Options:
- `Yes, write the file`
- `No, discard and exit`
- `Edit a specific question (which one?)`

On `Edit`, ask which question number to revisit, re-prompt that question, and loop back to Q8.

### 4. Write the config file

Use the `Write` tool with `path: ".claude/jira-issue-triage.config.json"`. Pretty-print with two-space indent and sort top-level keys alphabetically for stable diffs. The full schema (with all top-level keys, in alphabetical order):

```json
{
  "archetype_assignment_after_triage": {
    "Bug": "unassign",
    "Incident": "self",
    "Feature": "self",
    "Task": "self",
    "Spike": "self"
  },
  "description_preview_pause_seconds": 3,
  "escalation": { "slack_channel": null, "primary_contact": null, "fallback_contact": null },
  "non_bug_transitions": { "ready": null },
  "project_key": null,
  "scope_summary_field_name": null,
  "severity_field_name": null,
  "severity_scheme": {
    "Sev-1": { "due_offset_days": 7,  "escalate_immediately": true  },
    "Sev-2": { "due_offset_days": 14, "escalate_immediately": false },
    "Sev-3": { "due_offset_days": 90, "escalate_immediately": false }
  },
  "skip_labels": [],
  "sprint_field_name": null,
  "story_points_field_name": null,
  "transitions": {
    "investigating": "Under Investigation",
    "waiting_reply": "Waiting for Reply",
    "backlog": "Backlog"
  },
  "triaged_label": "triaged"
}
```

The wizard does NOT ask about these advanced fields: `scope_summary_field_name`, `sprint_field_name`, `story_points_field_name`, `non_bug_transitions.ready`, `archetype_assignment_after_triage`, `description_preview_pause_seconds`. They are written with their default values shown above so that the saved JSON is a complete, browsable config. Users edit the file directly to override. See the plugin README's "Advanced configuration" section for what each field does.

### 5. Confirmation message

Print these lines:

> Wrote `.claude/jira-issue-triage.config.json`. You can re-run `/jira-issue-triage:setup` any time to update.
>
> Advanced config keys not asked here (defaults used; edit the file directly to override): `archetype_assignment_after_triage`, `description_preview_pause_seconds`, `scope_summary_field_name`, `sprint_field_name`, `story_points_field_name`, `non_bug_transitions.ready`. See the plugin README's "Advanced configuration" section for what each one does.

## Notes

- This wizard never modifies Jira. Read-only auto-discovery only.
- If `getAccessibleAtlassianResources` or `atlassianUserInfo` fails, proceed with the static defaults and tell the user the auto-discovery failed.
- The wizard does not validate the entered Jira field names against the live instance. The agent's auto-discovery (in Prerequisites) handles validation at runtime; if a configured field name does not resolve, the agent falls back to its built-in auto-discovery order and warns the user.
