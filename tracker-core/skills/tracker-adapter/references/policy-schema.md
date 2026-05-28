# Policy schema

Path: `.claude/tracker-policy.json` (project-root). Optional. When absent, the adapter uses the shipped defaults below and lazy-prompts at the moment a missing key is needed.

## Shape

```json
{
  "states": {
    "investigating": "In Progress",
    "waiting_reply": "Waiting for Reply",
    "backlog": "Backlog"
  },
  "severity_scheme": {
    "sev1": { "due_offset_days": 1,  "escalate_immediately": true },
    "sev2": { "due_offset_days": 3,  "escalate_immediately": true },
    "sev3": { "due_offset_days": 7,  "escalate_immediately": false },
    "sev4": { "due_offset_days": 30, "escalate_immediately": false }
  },
  "severity_label_map": {
    "sev1": ["1 - Critical", "Sev-1", "Critical"],
    "sev2": ["2 - High",     "Sev-2", "High"],
    "sev3": ["3 - Medium",   "Sev-3", "Medium"],
    "sev4": ["4 - Low",      "Sev-4", "Low"]
  },
  "escalation": {
    "channel": null,
    "primary_contact": null,
    "fallback_contact": null
  },
  "skip_labels": ["triaged"],
  "triaged_label": "triaged",
  "output_directory": "./docs/postmortems/",
  "archetype_assignment_after_triage": {
    "Bug":       "unassign",
    "Incident":  "self",
    "Story":     "self",
    "Feature":   "self",
    "Task":      "self",
    "Spike":     "self"
  }
}
```

All keys are optional. Missing keys fall back to defaults.

## Key reference

### `states` (object)

Maps abstract state names to the vendor-side state or transition name.

- **`investigating`** — the state set when triage begins. Examples: AzDO `"Active"` (Agile process), Jira `"Under Investigation"`, `"In Progress"`.
- **`waiting_reply`** — the state used when the agent needs information from the reporter. Examples: AzDO `"Active"` with `Reason: "Awaiting Customer"`, Jira `"Waiting for Reply"`.
- **`backlog`** — the state used when an issue should not be worked on yet.

The adapter looks the value up on the live state graph:
- **Jira:** calls `getTransitionsForJiraIssue` and finds the transition by name.
- **AzDO:** matches against the issue type's state list from `wit_get_work_item_type`; for `investigating`, the adapter also sets `System.Reason` based on a `Reason: "<value>"` suffix in the state string if present (e.g. `"Active; Reason: Investigating"`).

**Default if unset:** lazy-prompt. The adapter presents the list of valid transitions / states from the live schema and asks the user to pick.

### `severity_scheme` (object)

Maps abstract severity tiers (`sev1`..`sev4`) to SLA semantics.

- **`due_offset_days`** — number of days from today to set as the due date.
- **`escalate_immediately`** — boolean; if true, the verb-plugin pings the escalation channel as soon as severity is determined.

**Default if unset:** the shape above (1/3/7/30 days; sev1 and sev2 escalate). Lazy-prompt only the parts the user wants to override.

### `severity_label_map` (object)

Maps abstract severity tiers to the vendor-side label values. The adapter uses this to project `severity: "sev1"` (abstract) to the vendor's actual option value (`"1 - Critical"` for AzDO Agile, `"Sev-1"` for many Jira projects).

If unset, the adapter uses the default above. If the vendor schema (from `getIssueTypeSchema`) does not contain any of the listed values, it lazy-prompts the user with the schema's enum options.

### `escalation` (object)

- **`channel`** — opaque string the verb-plugin passes to the chat adapter's `sendMessage`. For Slack: a channel ID or `#name`. For Teams: a channel or chat ID.
- **`primary_contact`** — `{name, email}` of the on-call human. The adapter resolves to `UserRef` on demand via `resolveUser({email})`.
- **`fallback_contact`** — same shape as `primary_contact`.

**Default if unset:** the verb-plugin skips the escalation step and logs a one-time note.

### `skip_labels` (string[])

When an issue carries any of these labels, the triage agent declines to re-process it. Default: `["triaged"]`.

### `triaged_label` (string)

The label the triage agent appends after a successful run. Default: `"triaged"`.

### `output_directory` (string)

Where postmortems get saved when the user accepts the save prompt. Default: `"./docs/postmortems/"`.

### `archetype_assignment_after_triage` (object)

After triage finishes, who should be assigned to the issue. Per-archetype:
- `"self"` — the running user (the human who ran the agent).
- `"unassign"` — clear the assignee.
- `"keep"` — leave the assignee unchanged.

Default: shape above. Bugs get unassigned (because triage hands off to whoever picks them up). Everything else stays with the triager.

## Lazy-prompt question text

When a missing key is encountered, ask via `AskUserQuestion` using these question templates:

| Missing key | Question | Options |
|---|---|---|
| `states.investigating` | "Which state means 'investigation is underway' on this tracker?" | live list from schema |
| `states.waiting_reply` | "Which state means 'waiting on reporter for more info'?" | live list from schema |
| `severity_scheme.<tier>` | "How many days should sev-<n> have until due date, and does it escalate immediately?" | numeric + yes/no |
| `severity_label_map.<tier>` | "Which vendor label corresponds to sev-<n>?" | schema enum |
| `escalation.channel` | "Which chat channel should receive escalations? (Leave blank to skip.)" | free text or skip |
| `escalation.primary_contact` | "Email of the primary on-call contact? (Leave blank to skip.)" | email or skip |
| `triaged_label` | "What label should mark an issue as triaged?" | free text, default "triaged" |

After every answer, offer:

> Save this to `.claude/tracker-policy.json` so I don't ask again? (yes/no)

On yes, write the file (creating it if absent) with the new key merged in. On no, keep the answer in session memory only.

## Schema validation

When the file exists, validate it on load:

- Reject extra top-level keys with a one-line warning (`Unknown policy key '<key>' in tracker-policy.json. Ignored.`).
- Reject malformed `severity_scheme` entries with a fallback to the default for that tier and a one-line warning.
- Reject malformed `archetype_assignment_after_triage` values with a fallback to `"keep"` and a one-line warning.

Do not abort on validation errors. The user can fix the file or accept the fallbacks.

## Migration from legacy configs

The verb-plugins read these legacy paths forward for the session if they exist and no `tracker-policy.json` is present:

- `.claude/azure-incident-postmortem.config.json`
- `.claude/azure-issue-triage.config.json`
- `.claude/jira-issue-triage.config.json`
- `.claude/jira-bug-triage.config.json`

They print one warning per session pointing at the legacy file path. To stop the warning, translate the values into `.claude/tracker-policy.json` (the shape above) and delete the legacy file. Lazy prompts will offer to persist any missing keys after that.
