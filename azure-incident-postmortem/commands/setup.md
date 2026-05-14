---
description: First-time setup wizard for azure-incident-postmortem. Walks through configuration questions and writes .claude/azure-incident-postmortem.config.json.
argument-hint: (no args)
allowed-tools: Read, Write, AskUserQuestion, core_list_projects, wit_my_work_items
---

# azure-incident-postmortem Setup Wizard

Walk the user through five configuration questions and write the result to `.claude/azure-incident-postmortem.config.json`. Re-runnable: pointing the wizard at an existing config offers to overwrite or keep current.

## Steps

### 1. Check for existing config

Read `.claude/azure-incident-postmortem.config.json` if it exists.

- **Config exists:** Read it, show the current contents to the user as pretty-printed JSON, then ask via `AskUserQuestion`: "Overwrite the existing config?" Options: `Yes, walk through the wizard again`, `No, keep current and exit`. On "No", exit cleanly.
- **No config exists:** Continue to step 2.

### 2. Auto-discover defaults

Best-effort auto-discovery to suggest defaults. Failures are non-fatal; fall back to the static defaults listed in each question and tell the user the auto-discovery failed.

1. Call `core_list_projects` to list the AzDO projects accessible to the running user. If the call returns one project, suggest it as the default `project` and `organization_url`.
2. Call `wit_my_work_items` with `top: 1` to confirm work-item access. The response includes the running user's display name and unique-name.

### 3. Walk through the five wizard questions

Ask one at a time. Use `AskUserQuestion` for multiple-choice answers. Use plain free-text prompts for URLs, project names, and directory paths. Confirm each answer before moving to the next question.

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

#### Q3: Output directory

Free-text prompt:

> Where should the agent save generated postmortems? Default: `./docs/postmortems/`. Press Enter to accept, type a different path, or type `null` to disable file save (the agent will render the markdown inline only).

Default: `./docs/postmortems/`. Validate that the answer is either `null` (literal string) or a non-empty path. Trailing slash is optional; the agent normalizes it.

**Serialization rule.** A typed path writes the string verbatim. The literal `null` writes JSON `null`. Empty answer (Enter pressed) writes the default `"./docs/postmortems/"`.

#### Q4: Postmortem template

Use `AskUserQuestion`:

> Which postmortem template should the agent use?

Options:
- `Google-SRE-style blameless (recommended; the only template shipped in v0.1.0)`
- `Other (will be added in a future release; sticks with google-sre for now)`

In v0.1.0 only `google-sre` is supported. Future releases may add `etsy` (a more conversational variant) and `custom` (user-supplied template path).

**Serialization rule.** Save as `"postmortem_template": "google-sre"`.

#### Q5: Default Datadog service (optional)

Free-text prompt:

> Default Datadog service tag for log queries? (e.g., `payments-api`). The agent uses this when it can't infer a service from the incident's title or description. Press Enter to skip.

Default: empty.

**Serialization rule.** Empty answer maps to JSON `null`. A typed value writes the string verbatim.

#### Q6: Save?

Show the assembled config as pretty-printed JSON with sorted top-level keys. Use `AskUserQuestion`:

> Save this config to `.claude/azure-incident-postmortem.config.json`?

Options:
- `Yes, write the file`
- `No, discard and exit`
- `Edit a specific question (which one?)`

On `Edit`, ask which question number (1-5) to revisit, re-prompt that question, and loop back to Q6.

### 4. Write the config file

Use the `Write` tool with `path: ".claude/azure-incident-postmortem.config.json"`. Pretty-print with two-space indent and sort top-level keys alphabetically for stable diffs. The full schema (with all top-level keys, in alphabetical order):

```json
{
  "datadog_default_service": null,
  "description_preview_pause_seconds": 3,
  "include_action_items": true,
  "include_timeline_evidence_links": true,
  "incident_identifier": {
    "tag": "incident",
    "work_item_types": ["Issue", "Bug"]
  },
  "organization_url": "https://dev.azure.com/<org>",
  "output_directory": "./docs/postmortems/",
  "postmortem_template": "google-sre",
  "project": "<project-name>"
}
```

The wizard does NOT ask about these advanced fields: `description_preview_pause_seconds`, `include_action_items`, `include_timeline_evidence_links`, `incident_identifier`. They are written with their default values shown above so that the saved JSON is a complete, browsable config. Users edit the file directly to override.

### 5. Confirmation message

Print these lines:

> Wrote `.claude/azure-incident-postmortem.config.json`. You can re-run `/azure-incident-postmortem:setup` any time to update.
>
> Advanced config keys not asked here (defaults used; edit the file directly to override): `description_preview_pause_seconds`, `include_action_items`, `include_timeline_evidence_links`, `incident_identifier`. See the plugin README's "Configuration" section for what each one does.

## Notes

- This wizard never modifies Azure DevOps. Read-only auto-discovery only.
- If `core_list_projects` or `wit_my_work_items` fails, proceed with the static defaults and tell the user the auto-discovery failed.
- The wizard does not validate the output directory's writability; the agent's Phase 5 attempts the write at runtime and falls back to inline rendering if the path is not writable.
