---
description: First-time setup wizard for azure-issue-triage. Walks through configuration questions and writes .claude/azure-issue-triage.config.json.
argument-hint: (no args)
allowed-tools: Read, Write, AskUserQuestion, core_list_projects, core_list_project_teams, wit_my_work_items, work_list_team_iterations
---

# azure-issue-triage Setup Wizard

Walk the user through ten configuration questions and write the result to `.claude/azure-issue-triage.config.json`. Re-runnable: pointing the wizard at an existing config offers to overwrite or keep current.

## Steps

### 1. Check for existing config

Read `.claude/azure-issue-triage.config.json` if it exists.

- **Config exists:** Read it, show the current contents to the user as pretty-printed JSON, then ask via `AskUserQuestion`: "Overwrite the existing config?" Options: `Yes, walk through the wizard again`, `No, keep current and exit`. On "No", exit cleanly.
- **No config exists:** Continue to step 2.

### 2. Auto-discover defaults

Best-effort auto-discovery to suggest defaults. Failures are non-fatal; fall back to the static defaults listed in each question and tell the user the auto-discovery failed.

1. Call `core_list_projects` to list the AzDO projects accessible to the running user. If the call returns one project, suggest it as the default `project` and `organization_url`. If multiple, list them and let the user pick at Q2.
2. Call `wit_my_work_items` with `top: 1` to confirm work-item access. The response includes the running user's display name and unique-name, useful for assignment writes; not surfaced in the wizard, but the agent uses these at runtime.
3. Pre-populate the severity field default as `Microsoft.VSTS.Common.Severity` (the Agile process template's built-in field).

### 3. Walk through the six wizard questions

Ask one at a time. Use `AskUserQuestion` for multiple-choice answers. Use plain free-text prompts for URLs, project names, and area paths. Confirm each answer before moving to the next question.

#### Q1: Organization URL

Free-text prompt:

> Azure DevOps organization URL? Format: `https://dev.azure.com/<org>` (no trailing slash).

Default: pre-fill from auto-discovery if a single org was found. Validate the answer matches the URL pattern.

**Serialization rule.** Save as a JSON string. Example: `"organization_url": "https://dev.azure.com/contoso"`.

#### Q2: Project name

Use `AskUserQuestion` if step 2's auto-discovery found multiple projects:

> Which Azure DevOps project?

Options: each accessible project name from auto-discovery, plus `Custom (type the name)`.

If only one project was found, use it as the default and confirm via free-text prompt:

> Default project: `{project-name}`. Press Enter to accept, or type a different project name.

**Serialization rule.** Save as a JSON string. Example: `"project": "Contoso.Platform"`.

#### Q3: Area path prefix (optional)

Free-text prompt:

> Default area path prefix for triaged work items? (Optional; press Enter to skip.) Format: `MyProject\\Backend` (use double backslashes inside JSON).

Default: empty (the agent leaves area path untouched at triage time).

**Serialization rule.** Empty answer maps to JSON `null`. A typed value writes the string verbatim (e.g., `"area_path_prefix": "Contoso.Platform\\\\Backend"`).

#### Q4: Severity field

Use `AskUserQuestion`:

> Which field holds the severity for Bug and Incident work items?

Options:
- `Microsoft.VSTS.Common.Severity` (recommended for Agile and CMMI process templates)
- `Microsoft.VSTS.Common.Priority` (use if your project disabled Severity, common on Scrum)
- `Custom (type the field reference name)`

On "Custom", ask for the field reference name (e.g., `Custom.MySeverityField`) as free text. Validate the answer is non-empty.

#### Q5: State + Reason mapping

Two free-text prompts:

1. > State name for "investigating"? Default: `Active`.
2. > Reason for "investigating"? Default: `Investigating`.

Then two more:

3. > State name for "waiting reply"? Default: `Active`.
4. > Reason for "waiting reply"? Default: `Awaiting Customer`.

**Process-template note.** The defaults match Agile. For CMMI use `Proposed -> Active` for investigating; for Scrum `Approved -> Committed`.

**Serialization rule.** Save under `states`:
```json
"states": {
  "investigating": { "state": "Active", "reason": "Investigating" },
  "waiting_reply": { "state": "Active", "reason": "Awaiting Customer" }
}
```

#### Q6: Teams channel (optional)

Free-text prompt:

> Microsoft Teams channel for the Phase 10 per-run summary? Format: team name + channel name (e.g., `Engineering > Triage`). Press Enter to skip; the agent will print the summary inline instead of sending a Teams message.

Default: empty.

**Serialization rule.** Empty answer maps to JSON `null`. A typed value writes the string verbatim. The agent does not validate the channel against the live Teams instance; the actual channel ID resolution happens at runtime.

#### Q7: Severity scheme

Use `AskUserQuestion`:

> Which severity scheme do you want to use?

Options:
- `4-tier (1 - Critical, 2 - High, 3 - Medium, 4 - Low) with 7/14/30/90 day SLAs` (recommended default; matches the built-in `Microsoft.VSTS.Common.Severity` enum)
- `Custom (specify each level)`

On "Custom", walk through each level: ask for the level name (string, must match an option of the configured `severity_field`), the `due_offset_days` integer, and via `AskUserQuestion` whether `escalate_immediately` is `Yes` or `No`. Loop until the user types `done` for the level name. The agent uses the keys you define at runtime, so make sure they exactly match the option names in your Severity custom field.

**Serialization rule.** Save under `severity_scheme`:

```json
"severity_scheme": {
  "1 - Critical": { "due_offset_days": 7,  "escalate_immediately": true  },
  "2 - High":     { "due_offset_days": 14, "escalate_immediately": false },
  "3 - Medium":   { "due_offset_days": 30, "escalate_immediately": false },
  "4 - Low":      { "due_offset_days": 90, "escalate_immediately": false }
}
```

#### Q8: Escalation contacts (optional)

Three free-text sub-prompts. Each accepts an empty answer (Enter for none).

1. > Microsoft Teams channel for high-severity escalation pings? (e.g., `Incident Response > Escalations`) Press Enter for none.
2. > Primary escalation contact? Format: `Alice Kumar <alice@example.com>`. Press Enter for none.
3. > Fallback escalation contact? Same format. Press Enter for none.

Parse the contact strings into `{ "name": "Alice Kumar", "email": "alice@example.com" }`. If the format does not match, warn and re-prompt.

**Serialization rule.** Empty answers map to JSON `null`, not empty strings or empty objects. Save under `escalation`:

```json
"escalation": {
  "teams_channel": null,
  "primary_contact": null,
  "fallback_contact": null
}
```

The agent's Prerequisites step 4 resolves the contacts to Teams user descriptors at session start; if a contact's email cannot be resolved, the channel post (when configured) mentions them by name only and a deferred warning surfaces in the Phase 10 summary.

#### Q9: Sprint placement (optional)

Use `AskUserQuestion`:

> Should the agent place User Story / Feature / Task / Spike work items into a sprint at triage time?

Options:
- `No, skip sprint placement` (recommended default)
- `Yes, current sprint of the default team` — uses `work_list_team_iterations` with `timeframe: "current"` at runtime to find the active iteration. Requires `default_team` to be set; the wizard prompts for it as a follow-up if it's still null.
- `Yes, a fixed iteration path I'll specify` — prompts for an explicit path like `MyProject\\Backend\\Sprint 42`.

**Serialization rule.** "No" writes `"iteration_path_strategy": null`. "Current" writes `"iteration_path_strategy": "current"`. "Fixed" writes `"iteration_path_strategy": "explicit:<path>"`. When "Current" is chosen and `default_team` is null, ask:

> What's your team name in Azure DevOps? (e.g., `Platform Engineering`). The agent uses this to find the active iteration.

Save the answer to `default_team`.

#### Q10: Story-point estimation (optional)

Use `AskUserQuestion`:

> Should the agent prompt for a story-point estimate at the Phase 3 confirmation gate (User Story / Feature work items)?

Options:
- `No, skip estimation` (recommended default)
- `Yes, write to Microsoft.VSTS.Scheduling.StoryPoints` — the built-in field on Agile and Scrum process templates.
- `Custom field reference name (type the name)` — for projects using a custom story-point field.

**Serialization rule.** "No" writes `"story_points_field": null`. "Yes" writes `"story_points_field": "Microsoft.VSTS.Scheduling.StoryPoints"`. "Custom" writes the typed reference name verbatim. Validate non-empty.

#### Q11: Save?

Show the assembled config as pretty-printed JSON with sorted top-level keys. Use `AskUserQuestion`:

> Save this config to `.claude/azure-issue-triage.config.json`?

Options:
- `Yes, write the file`
- `No, discard and exit`
- `Edit a specific question (which one?)`

On `Edit`, ask which question number (1-10) to revisit, re-prompt that question, and loop back to Q11.

### 4. Write the config file

Use the `Write` tool with `path: ".claude/azure-issue-triage.config.json"`. Pretty-print with two-space indent and sort top-level keys alphabetically for stable diffs. The full schema (with all top-level keys, in alphabetical order):

```json
{
  "archetype_assignment_after_triage": {
    "Bug": "unassign",
    "Incident": "self",
    "User Story": "self",
    "Feature": "self",
    "Task": "self",
    "Spike": "self"
  },
  "area_path_prefix": null,
  "default_team": null,
  "description_preview_pause_seconds": 3,
  "escalation": {
    "teams_channel": null,
    "primary_contact": null,
    "fallback_contact": null
  },
  "iteration_path_strategy": null,
  "organization_url": "https://dev.azure.com/<org>",
  "pr_linking_enabled": true,
  "project": "<project-name>",
  "severity_field": "Microsoft.VSTS.Common.Severity",
  "severity_scheme": {
    "1 - Critical": { "due_offset_days": 7,  "escalate_immediately": true  },
    "2 - High":     { "due_offset_days": 14, "escalate_immediately": false },
    "3 - Medium":   { "due_offset_days": 30, "escalate_immediately": false },
    "4 - Low":      { "due_offset_days": 90, "escalate_immediately": false }
  },
  "skip_tags": [],
  "story_points_field": null,
  "states": {
    "investigating": { "state": "Active", "reason": "Investigating" },
    "waiting_reply": { "state": "Active", "reason": "Awaiting Customer" }
  },
  "teams_channel": null,
  "triaged_tag": "triaged",
  "work_item_type_map": {
    "Bug": "Bug",
    "Incident": "Issue",
    "User Story": "User Story",
    "Feature": "Feature",
    "Task": "Task",
    "Spike": "Task"
  }
}
```

The wizard does NOT ask about these advanced fields: `archetype_assignment_after_triage`, `description_preview_pause_seconds`, `pr_linking_enabled`, `skip_tags`, `triaged_tag`, `work_item_type_map`. They are written with their default values shown above so that the saved JSON is a complete, browsable config. Users edit the file directly to override. (`default_team` is asked only when Q9 picks "current sprint" — it stays null otherwise.)

### 5. Confirmation message

Print these lines:

> Wrote `.claude/azure-issue-triage.config.json`. You can re-run `/azure-issue-triage:setup` any time to update.
>
> Advanced config keys not asked here (defaults used; edit the file directly to override): `archetype_assignment_after_triage`, `description_preview_pause_seconds`, `default_team`, `skip_tags`, `triaged_tag`, `work_item_type_map`. See the plugin README's "Configuration" section for what each one does.

## Notes

- This wizard never modifies Azure DevOps. Read-only auto-discovery only.
- If `core_list_projects` or `wit_my_work_items` fails, proceed with the static defaults and tell the user the auto-discovery failed.
- The wizard does not validate the entered Teams channel name against the live Teams instance. The agent's Phase 10 attempts the send at runtime; if the channel doesn't resolve, the agent falls back to inline output and notes the failure in the summary.
- The wizard does not auto-detect the process template (Agile / Scrum / CMMI). Q5's defaults match Agile; users on Scrum or CMMI override Q5 manually based on their workflow.
