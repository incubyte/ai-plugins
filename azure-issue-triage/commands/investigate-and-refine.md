---
description: Investigate, refine, and post an Azure DevOps work item in one shot. Chains the investigator skill (azure-issue-investigator for Bug/Incident, azure-requirements-investigator for User Story/Feature/Task/Spike), azure-work-item-refiner, and prose-style, then asks whether to update the title and description, post as a comment, or both.
argument-hint: <work-item URL or ID>
allowed-tools: Skill, Read, AskUserQuestion, wit_get_work_item, wit_update_work_item, wit_add_work_item_comment, core_list_projects
---

# /azure-issue-triage:investigate-and-refine

Run investigation, refinement, and writing-style cleanup against one Azure DevOps work item, then write the result back to AzDO. This is the lightweight counterpart to the full `azure-issue-triage` agent: no severity assessment, no due date, no transitions, no sprint placement, no story-point prompt, no PR linking, no Teams summary. Just investigate, refine, and post.

Use this when you want a structured investigation report plus a cleaned-up title and description on a work item, without going through the full triage flow (assignment, severity, due date, escalation, iteration path, story points, ArtifactLink relations, Teams escalation).

## Scope

What this command does:

- Fetches the work item once and detects its archetype (Bug / Incident / User Story / Feature / Task / Spike).
- Runs the matching investigator skill end-to-end: `azure-issue-investigator` for Bug or Incident, `azure-requirements-investigator` for User Story, Feature, Task, or Spike.
- Runs `azure-work-item-refiner` in read-only-return mode to produce a refined title and HTML description, with the investigation findings folded in as source material.
- Runs `prose-style` over the refined title and description to strip writing-style anti-patterns.
- Asks the user whether to update the work item's title and description, post the findings as a comment, both, or cancel.
- Writes the chosen output via `wit_update_work_item` or `wit_add_work_item_comment` (or both).

What this command does NOT do:

- Does not assign the work item, change the reporter (`System.CreatedBy` is immutable on AzDO anyway), change priority, or change severity (`Microsoft.VSTS.Common.Severity`).
- Does not transition the work item between states (`System.State` / `System.Reason`).
- Does not set due dates (`Microsoft.VSTS.Scheduling.DueDate`), sprints (`System.IterationPath`), story points (`Microsoft.VSTS.Scheduling.StoryPoints`), tags, area path, or any custom fields.
- Does not link related work items or pull requests via `relations` / `ArtifactLink`.
- Does not post a Teams summary at the end.

For the full triage flow (with severity, due date, transitions, sprint, story points, PR links, Teams escalation), invoke the `azure-issue-triage` agent instead. The two entry points share the same skills underneath; this command is the strict subset.

## Input

The user supplies a work-item URL or bare ID as the first argument. Examples:

- `/azure-issue-triage:investigate-and-refine https://dev.azure.com/contoso/Platform/_workitems/edit/12345`
- `/azure-issue-triage:investigate-and-refine https://contoso.visualstudio.com/Platform/_workitems/edit/12345`
- `/azure-issue-triage:investigate-and-refine 12345`

Extract the numeric work-item ID from the input. Accept either the `https://dev.azure.com/<org>/<project>/_workitems/edit/<id>` shape, the legacy `https://<org>.visualstudio.com/<project>/_workitems/edit/<id>` shape, or the bare ID. Strip any trailing query string or anchor. If the argument is empty or unparseable, stop and ask the user for the URL or ID.

When the URL contains an organization slug and project name, prefer them over the values in `.claude/azure-issue-triage.config.json` for this run (the user is explicitly addressing a specific work item). When only the bare ID is supplied, read `organization_url` and `project` from the config; if either is missing, ask the user once before continuing.

## Working State

Track these caches across the command's phases. They mirror a small subset of the `azure-issue-triage` agent's working state.

| Cache key | Set in | Read in | Type |
|-----------|--------|---------|------|
| `work_item_id` | Phase 0 | All later phases | string (e.g., `12345`) |
| `organization_url` | Phase 0 | Phase 4 (comment links) | string (e.g., `https://dev.azure.com/contoso`) |
| `project` | Phase 0 | Phases 0, 4 (write calls) | string (e.g., `Platform`) |
| `work_item_payload` | Phase 0 | Phases 1, 2, 4 | object (full `wit_get_work_item` response) |
| `archetype` | Phase 0 | Phase 1 (skill choice), Phase 4 (comment heading) | enum (Bug / Incident / User Story / Feature / Task / Spike) |
| `investigation_report` | Phase 1 | Phases 2, 3, 4 | string (markdown) |
| `refined_title` | Phase 2 | Phases 3, 4 | string |
| `refined_description_html` | Phase 2 | Phases 3, 4 | string (HTML, safe for `System.Description`) |
| `cleaned_title` | Phase 3 | Phase 4 | string |
| `cleaned_description_html` | Phase 3 | Phase 4 | string (HTML) |
| `write_choice` | Phase 4 user panel | Phase 4 write step | enum (`update`, `comment`, `both`, `cancel`) |

## Phases

Run the phases in order. Phase 4 is the only user-facing pause; everything before that runs straight through.

---

### Phase 0: Fetch and Detect Archetype

1. **Parse the work-item ID** from the user's argument. Accept any of the three input shapes documented above. Cache as `work_item_id`. If the argument is missing or no integer can be extracted, stop and ask the user for the URL or ID before continuing.
2. **Resolve org and project.** When the input is a URL, parse `organization_url` from `https://dev.azure.com/<org>` or the equivalent `<org>.visualstudio.com` form, and parse `project` from the path segment immediately after the org. Otherwise read both from `.claude/azure-issue-triage.config.json` (`organization_url`, `project`). If neither input nor config supplies them, ask the user once: "Which AzDO org URL and project should I look this up in?" Cache both.
3. **Sanity-check the org is reachable.** Call `core_list_projects` once. If it fails (auth error, network, etc.), stop and tell the user which call failed. Do not proceed without a confirmed connection.
4. **Fetch the work item** via `wit_get_work_item` with `id: <work_item_id>`, `project: <project>`, `expand: "all"` and the field set:

   ```
   System.Id, System.Title, System.Description, System.State, System.WorkItemType,
   System.AssignedTo, System.CreatedBy, System.CreatedDate, System.ChangedDate,
   System.AreaPath, System.IterationPath, System.Tags, System.Reason, System.Parent
   ```

   The response includes the `relations` array (links) and comments either inline (with `expand: "all"`) or via a separate fetch depending on the MCP tool's shape; if comments are not in the expanded response, fetch them via `wit_get_work_item_comments` (or the MCP's equivalent) and merge into the cached payload. Cache the merged object as `work_item_payload`.

5. If `wit_get_work_item` fails (auth error, work item not found, network), stop and tell the user which call failed. Do not proceed without work-item data.

6. **Detect archetype.** Map `System.WorkItemType` to one of `Bug`, `Incident`, `User Story`, `Feature`, `Task`, `Spike` using the table below. The mapping is the inverse of `work_item_type_map` from the config; if the user has a custom config, prefer their mapping over the table.

   | AzDO work-item type | Archetype |
   |---------------------|-----------|
   | Bug | Bug |
   | Issue, Impediment | Incident |
   | User Story, Product Backlog Item, Requirement | User Story |
   | Feature, Epic | Feature |
   | Task | Task (or Spike, see special case) |

   **Spike special case.** Spike has no canonical work-item type in any built-in AzDO process template. Treat a Task carrying a `spike` tag (case-insensitive match on `System.Tags`) as a Spike, and treat any custom work-item type literally named `Spike` the same way.

   **Content overrides type.** When the work-item type and the description content disagree (e.g., type `Bug` but content is acceptance criteria and a Figma link), trust the content. Note the conflict and use the content-implied archetype for skill selection.

   **Unmapped types.** If `System.WorkItemType` does not match any row of the table and the config provides no mapping for it, pause and ask the user: "This is a `{type}` work item. Which archetype should I treat it as: Bug, Incident, User Story, Feature, Task, Spike, or cancel?" Use their answer for this run; do not write it to the config.

   Cache the archetype string as `archetype`.

7. Print one line so the user knows what is about to run: `Investigating work item {work_item_id} ({archetype}). This will take a minute.`

---

### Phase 1: Investigate

Branch by archetype. Invoke exactly one skill via the `Skill` tool.

- **Bug or Incident:** Invoke the `azure-issue-investigator` skill. Pass the cached work-item payload so the skill does not refetch.
- **User Story, Feature, Task, or Spike:** Invoke the `azure-requirements-investigator` skill. Pass the cached payload and the archetype string.

Both skills are non-interactive and read-only. They return an evidence-tagged markdown report in their archetype-specific template (six sections for Bug/Incident, three to five sections for User Story / Feature / Task / Spike).

Cache the skill's returned report as `investigation_report`.

The skill prompt should look like this (one example, for Bug/Incident):

```
Calling context: bypass_fetch=true.

The orchestrator has already fetched the work item and supplies the payload below. Use it directly. Return the investigation report as your final output; do not post or modify anything in Azure DevOps.

Work-item ID: <work_item_id>
Archetype: <archetype>
Work-item payload (JSON):
<paste the work_item_payload object here as JSON>
```

The `Calling context:` line is informational; both investigator skills already reuse a caller-provided payload when one is present (see their "Setup" sections). The leading line keeps the contract explicit.

**Fallback for when an investigator skill does not load:** apply the same minimal fallback the `azure-issue-triage` agent uses. For Bug/Incident, run 2-3 `teams_search_messages` queries (work-item ID, distinctive symptom, customer or area) when a Teams MCP is installed, then `wiki_search` for runbooks or known-issues pages, then `wit_query_by_wiql` for prior work items in the same area. For User Story / Feature / Task / Spike, do the same Teams and Wiki searches plus a WIQL related-work-item search; skip Datadog. Tag every finding `[VERIFIED]`, `[OBSERVED]`, `[INFERRED]`, or `[UNKNOWN]`. Warn the user once at the start of this phase that the fallback was used. The command itself does not list the Teams, Wiki, WIQL, or Datadog tools in `allowed-tools`, so the fallback only fires when the skill bundle is intact but the specific skill failed to load; the skill's own tool list covers the live search calls.

---

### Phase 2: Refine

Invoke `azure-work-item-refiner` via the `Skill` tool in read-only-return mode. The agent's Phase 5 already uses this contract; reuse the same calling convention.

The exact prompt to pass:

```
Calling context: skip_preview=true.

The orchestrator owns the user gate; do not run Step 7 preview or write via wit_update_work_item. Return the refined title and description as your final output, in this format:

Title: <refined title on one line>

Description:
<refined description as safe HTML, using the rules in references/azure-html-formatting.md, no outer fence>

Work-item ID: <work_item_id>
Archetype: <archetype>
Investigation report (use as additional source material; fold any new facts into the description):
<paste the cached investigation_report here>

Work-item payload (JSON):
<paste the work_item_payload object here as JSON>
```

The first line is the machine-parseable `Calling context:` directive (one key=value, terminated by a period). The skill's body parses that line, recognizes `skip_preview=true`, and short-circuits its Step 7 (no `AskUserQuestion`, no `wit_update_work_item`, no comment posting). It returns the refined title and HTML description as plain text.

Parse the returned text into two strings:

- The line after `Title:` is `refined_title`.
- Everything after the `Description:` line (up to end of output) is `refined_description_html`.

Cache both. If the skill returns content that does not match this shape, prefer the longest contiguous block as the description and the work item's original `System.Title` as a fallback for the refined title rather than failing the run.

**Fallback for when `azure-work-item-refiner` does not load:** restructure the original description plus investigation findings into archetype-appropriate sections per the fallback rules in the `azure-issue-triage` agent's Phase 5 (the section titled "Inline fallback when `azure-work-item-refiner` is unavailable"). Render the result as safe HTML (no `<script>`, no `<iframe>`, no inline event handlers; AzDO sanitizes but defense in depth applies). Rewrite the title using `{Area}: {specific problem or goal}` for any archetype, or `P{n}: {Area} {short problem statement}` for incidents, or `Spike: {Area} {question to answer}` for spikes. Warn the user once at the start of this phase that the fallback was used.

---

### Phase 3: Style Cleanup

Invoke `prose-style` via the `Skill` tool. Pass the refined title and description from Phase 2 as input and ask for the same content with writing-style rules applied.

The exact prompt to pass:

```
Rewrite the following so the prose reads like a person wrote it. Apply your standard rules: no em dashes or spaced hyphens as separators, no opener phrases, no LLM vocabulary, no bullet sprawl, lead with the answer. Preserve every fact. The description is HTML; preserve every tag exactly (only rewrite the text inside tags). Return the cleaned content in the same shape as the input.

Title: <refined_title>

Description:
<refined_description_html>
```

Parse the returned text the same way as Phase 2 (line after `Title:` is `cleaned_title`; the block after `Description:` is `cleaned_description_html`).

Cache both.

**Fallback for when `prose-style` does not load:** apply these rules inline to the refined title and description before caching them as `cleaned_*`: no em dashes, no spaced hyphens as separators, no LLM vocabulary (`delve`, `leverage`, `robust`, `seamlessly`, `comprehensive`, `nuanced`, `elevate`, `foster`, `paradigm`, `ecosystem`, `holistic`, `innovative`, `synergy`, `empower`, `facilitate`), lead with the answer, no opener phrases, no trailing summaries on short sections, prose over bullet lists when content flows naturally as sentences. For the HTML description, only rewrite text content inside tags; never alter tag names, attributes, or structure. Warn the user once at the start of this phase that the fallback was used.

---

### Phase 4: Preview, Confirm, and Write

This is the only user-facing pause in the command.

1. Render a preview to the user as inline markdown (not wrapped in an outer code fence; the description is HTML and will render as a code block when fenced). Use this layout:

   - A horizontal rule.
   - The cleaned title on its own line: `**Title:** \`{cleaned_title}\``
   - A blank line.
   - The cleaned description rendered as an HTML snippet inside a fenced ```html block so the user sees the markup that will be written (the AzDO web UI renders it as styled HTML).
   - A horizontal rule.
   - A short summary line naming the investigation findings ("Found N hypotheses, evidence at L1/L2/L3/L4" or similar), so the user knows what the comment would include if they pick that option.

2. Ask the user via `AskUserQuestion` with one question and four options:

   - Question: `What should I do with work item {work_item_id}?`
   - Options:
     - `Update title and description` (calls `wit_update_work_item` with the cleaned title and HTML description).
     - `Post the investigation findings as a comment` (calls `wit_add_work_item_comment` with the investigation report as HTML; leaves title and description untouched).
     - `Both` (post the comment first, then update title and description).
     - `Cancel without writing` (end the run; nothing is written).

   Cache the answer as `write_choice` (`update`, `comment`, `both`, or `cancel`). The runtime adds an "Other" channel automatically; if the user uses it to request revisions, treat the free-text as guidance and re-enter Phase 2 with the guidance prefixed `User refinement guidance:` on the prompt to `azure-work-item-refiner`. Cap the revision loop at three rounds; on the fourth disagreement, ask `Approve as-is` or `Cancel` as a two-option question and accept the answer.

3. Execute the choice:

   - `cancel`: print `No changes written to work item {work_item_id}.` and exit.
   - `update`: call `wit_update_work_item` once with `id: <work_item_id>`, `project: <project>`, and the JSON Patch body:

     ```json
     [
       { "op": "add", "path": "/fields/System.Title",       "value": "<cleaned_title>" },
       { "op": "add", "path": "/fields/System.Description", "value": "<cleaned_description_html>" }
     ]
     ```

     Send the title as a plain string and the description as the safe-HTML string from Phase 3. Never send markdown; the AzDO REST API stores the description field verbatim and renders it as HTML. Validate the HTML one last time before sending: no `<script>`, no `<iframe>`, no inline event handlers, no `javascript:` URLs. The refiner skill enforces this, but the command verifies as defense in depth.

   - `comment`: call `wit_add_work_item_comment` once with `workItemId: <work_item_id>`, `project: <project>`, and `text` set to a safe-HTML comment body built from the investigation report. The HTML structure is described below.

   - `both`: post the comment first (as above), then update the title and description (as above). Two calls. Print one consolidated confirmation at the end.

4. Print a one-line confirmation summarizing what was written:

   - `update`: `Updated title and description on work item {work_item_id}.`
   - `comment`: `Posted investigation findings as a comment on work item {work_item_id}.`
   - `both`: `Posted investigation findings and updated title/description on work item {work_item_id}.`

---

## Comment HTML Construction

When the user picks `comment` or `both`, build the comment body as a safe-HTML string. AzDO comments do not use ADF; they use sanitized HTML the same way work-item descriptions do. The same rules from `skills/azure-work-item-refiner/references/azure-html-formatting.md` apply here.

The comment carries the investigation findings only, not the refined title or description (those go on the work item itself when the user picks `update` or `both`). Build the HTML with:

- An `<h2>` element whose text is `Investigation Findings ({archetype})`.
- A `<p>` for each paragraph of the investigation report.
- `<ul><li>` (or `<ol><li>` where ordering matters) for any bullet sections.
- Inline work-item IDs become `<a href="{organization_url}/{project}/_workitems/edit/{id}">#{id}</a>` links. Resolve `{organization_url}` and `{project}` from the cached values.
- Bold uses `<strong>...</strong>`. Italic uses `<em>...</em>`.
- Evidence tags (`[VERIFIED]`, `[OBSERVED]`, `[INFERRED]`, `[UNKNOWN]`) stay inline in the same paragraph as the surrounding sentence; do not promote them to their own list items.
- Pull request references (`!12345` or full Azure Repos URLs) become `<a>` links using the Azure Repos web URL form `{organization_url}/{project}/_git/<repo>/pullrequest/<id>` when the repo can be determined, otherwise plain `#{id}` text.

Pass the assembled HTML string as the `text` parameter to `wit_add_work_item_comment`.

---

## Do Not Rules

- Never modify the work item without showing the user the cleaned title and description first and getting an explicit answer via `AskUserQuestion`.
- Never change the assignee (`System.AssignedTo`), state (`System.State`), reason (`System.Reason`), severity (`Microsoft.VSTS.Common.Severity`), priority (`Microsoft.VSTS.Common.Priority`), tags, area path, iteration path, story points, due date, or any custom field. This command's scope is `System.Title`, `System.Description`, and one comment. For everything else, use the full `azure-issue-triage` agent.
- Never drop screenshots, videos, images, recordings, file attachments, or inline links from the original description. The refined HTML is a strict superset of the original; every fact and every embedded media reference survives. This rule is inherited from `azure-work-item-refiner` and applies even when the refiner output looks complete.
- Never post a comment using a markdown body. All comments are HTML (the `text` parameter on `wit_add_work_item_comment` is HTML by convention; the MCP wraps the AzDO REST API which expects HTML for `comments.add`).
- Never send raw markdown in `System.Description`. AzDO stores the field verbatim and renders it as HTML; raw markdown appears literally with `#` and `*` characters visible to readers.
- Never write `<script>`, `<iframe>`, inline event handlers, or `javascript:` URLs in the description or any comment. AzDO sanitizes most unsafe HTML but the policy is "defense in depth, not lean on the sanitizer."
- Never tag the reporter or anyone else in the comment. Reporter follow-up is the `azure-issue-triage` agent's job, not this command's.
- Never invent content during refinement. The refiner and prose-style skill both enforce this; the command does too. If a fact is missing, leave it missing.
- Never add or remove `relations` entries (no `ArtifactLink` writes, no related-work-item linking). PR linking is the full agent's job.

## Writing Rules

These apply to all text this command produces (the preview line, the confirmation line, the comment body, and the cleaned title and description before they go to AzDO). They duplicate the floor that `prose-style` and `azure-work-item-refiner` already enforce; they're listed here so the command stays consistent even if either skill is unavailable.

- No em dashes or spaced hyphens as separators. Em dashes inside parenthetical asides are fine.
- No LLM vocabulary: `delve`, `leverage`, `robust`, `seamlessly`, `comprehensive`, `nuanced`, `elevate`, `foster`, `paradigm`, `ecosystem`, `holistic`, `innovative`, `synergy`, `empower`, `facilitate`.
- Lead with the answer. No opener phrases.
- No trailing summaries on short sections.
- Prose over bullet lists when the content flows naturally as sentences.
- Never present unverified analysis as a confirmed root cause.

## Examples

A few invocation shapes the command supports:

```
/azure-issue-triage:investigate-and-refine https://dev.azure.com/contoso/Platform/_workitems/edit/12345
/azure-issue-triage:investigate-and-refine https://contoso.visualstudio.com/Platform/_workitems/edit/12345
/azure-issue-triage:investigate-and-refine 12345
```

Each runs Phases 0-4 in order and pauses at Phase 4 for the user to pick a write action.
