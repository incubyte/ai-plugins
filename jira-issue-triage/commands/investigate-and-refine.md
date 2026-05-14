---
description: Investigate, refine, and post a Jira ticket in one shot. Chains the investigator skill (issue-investigator for Bug/Incident, requirements-investigator for Feature/Task/Spike), jira-ticket-refiner, and prose-style, then asks whether to update the description, post as a comment, or both.
argument-hint: <ticket URL or key>
allowed-tools: Skill, Read, AskUserQuestion, mcp__plugin_atlassian_atlassian__getJiraIssue, mcp__plugin_atlassian_atlassian__editJiraIssue, mcp__plugin_atlassian_atlassian__addCommentToJiraIssue, mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources
---

# /jira-issue-triage:investigate-and-refine

Run investigation, refinement, and writing-style cleanup against one Jira ticket, then write the result back to Jira. This is the lightweight counterpart to the full `jira-issue-triage` agent: no severity assessment, no sprint placement, no transitions, no Slack DM. Just investigate, refine, and post.

Use this when you want a structured investigation report plus a cleaned-up title and description on a ticket, without going through the full triage flow (assignment, severity, due date, escalation, labels, links).

## Scope

What this command does:

- Fetches the ticket once and detects its archetype (Bug / Incident / Feature / Task / Spike).
- Runs the matching investigator skill end-to-end: `issue-investigator` for Bug or Incident, `requirements-investigator` for Feature, Task, or Spike.
- Runs `jira-ticket-refiner` in read-only-return mode to produce a refined title and description, with the investigation findings folded in as source material.
- Runs `prose-style` over the refined title and description to strip writing-style anti-patterns.
- Asks the user whether to update the ticket description, post the findings as a comment, both, or cancel.
- Writes the chosen output via `editJiraIssue` or `addCommentToJiraIssue` (or both).

What this command does NOT do:

- Does not assign the ticket, change the reporter, change priority, or change severity.
- Does not transition the ticket between statuses.
- Does not set due dates, sprints, story points, components, or any custom fields.
- Does not link related tickets or add labels.
- Does not DM you on Slack at the end.

For the full triage flow (with severity, due date, transitions, etc.), invoke the `jira-issue-triage` agent instead. The two entry points share the same skills underneath; this command is the strict subset.

## Input

The user supplies a Jira ticket URL or key as the first argument. Examples:

- `/jira-issue-triage:investigate-and-refine https://yourcompany.atlassian.net/browse/PROJ-12345`
- `/jira-issue-triage:investigate-and-refine PROJ-12345`

Extract the ticket key from the input (strip the URL prefix and any trailing query string). If the argument is empty or unparseable, stop and ask the user for the ticket URL or key.

## Working State

Track these caches across the command's phases. They mirror a small subset of the `jira-issue-triage` agent's working state.

| Cache key | Set in | Read in | Type |
|-----------|--------|---------|------|
| `ticket_key` | Phase 0 | All later phases | string (e.g., `PROJ-12345`) |
| `ticket_payload` | Phase 0 | Phases 1, 2, 4 | object (full `getJiraIssue` response) |
| `archetype` | Phase 0 | Phase 1 (skill choice), Phase 4 (comment shape) | enum (Bug / Incident / Feature / Task / Spike) |
| `investigation_report` | Phase 1 | Phases 2, 3, 4 | string (markdown) |
| `refined_title` | Phase 2 | Phases 3, 4 | string |
| `refined_description` | Phase 2 | Phases 3, 4 | string (markdown) |
| `cleaned_title` | Phase 3 | Phase 4 | string |
| `cleaned_description` | Phase 3 | Phase 4 | string (markdown) |
| `write_choice` | Phase 4 user panel | Phase 4 write step | enum (`update`, `comment`, `both`, `cancel`) |

## Phases

Run the phases in order. Phase 4 is the only user-facing pause; everything before that runs straight through.

---

### Phase 0: Fetch and Detect Archetype

1. Parse the ticket key from the user's argument. Accept either a full URL (`https://*.atlassian.net/browse/<KEY>`) or the bare key. Cache as `ticket_key`. If the argument is missing or the key cannot be extracted, stop and ask the user for the URL or key before continuing.
2. Call `getJiraIssue` with `responseContentFormat: "markdown"` and these fields: `summary`, `description`, `comment`, `status`, `issuetype`, `priority`, `labels`, `components`, `assignee`, `reporter`, `created`, `updated`, `parent`, `issuelinks`, `duedate`. Cache the full response as `ticket_payload`.
3. If `getJiraIssue` fails (auth error, ticket not found, network), stop and tell the user which call failed. Do not proceed without ticket data.
4. **Detect archetype.** Map the issue type field to one of: `Bug`, `Incident`, `Feature`, `Task`, `Spike`. Use the table below. If the issue type and the content disagree (e.g., issue type `Bug` but the body is acceptance criteria and a Figma link), trust the content. Cache the archetype string as `archetype`.

   | Jira issue type | Archetype |
   |-----------------|-----------|
   | Bug, Defect | Bug |
   | Incident, Outage, SEV-tagged tickets | Incident |
   | Story, Feature, Enhancement, New Feature | Feature |
   | Task, Sub-task, Chore, Tech Debt | Task |
   | Spike, Research, Investigation | Spike |

   Tickets whose issue type does not match any row default to the closest match by content. When ambiguous, pick `Task` as the safe default.
5. Print one line to the user so they know what is about to run: `Investigating {TICKET-KEY} ({archetype}). This will take a minute.`

---

### Phase 1: Investigate

Branch by archetype. Invoke exactly one skill via the `Skill` tool.

- **Bug or Incident:** Invoke the `issue-investigator` skill. Pass the cached ticket payload so the skill does not refetch.
- **Feature, Task, or Spike:** Invoke the `requirements-investigator` skill. Pass the cached payload and the archetype string.

Both skills are non-interactive and read-only. They return an evidence-tagged markdown report in their archetype-specific template (six sections for Bug/Incident, three to five sections for Feature/Task/Spike).

Cache the skill's returned report as `investigation_report`.

The skill prompt should look like this (one example, for Bug/Incident):

```
Calling context: bypass_fetch=true.

The orchestrator has already fetched the ticket and supplies the payload below. Use it directly. Return the investigation report as your final output; do not post or modify anything in Jira.

Ticket key: <ticket_key>
Archetype: <archetype>
Ticket payload (markdown):
<paste the ticket_payload markdown body here>
```

The `Calling context:` line is informational; both investigator skills already reuse a caller-provided payload when one is present (see their "Setup" sections). The leading line keeps the contract explicit.

**Fallback for when an investigator skill does not load:** apply the same minimal fallback the `jira-issue-triage` agent uses. For Bug/Incident, run 2-3 `slack_search_public_and_private` queries (ticket key, distinctive symptom, customer or area), then `searchConfluenceUsingCql` for runbooks or known-issues pages, then `searchJiraIssuesUsingJql` for prior tickets in the same area. For Feature/Task/Spike, do the same Slack and Confluence searches plus a Jira related-ticket search; skip Datadog. Tag every finding `[VERIFIED]`, `[OBSERVED]`, `[INFERRED]`, or `[UNKNOWN]`. Warn the user once at the start of this phase that the fallback was used. The command itself does not list the Slack, Confluence, or Datadog tools in `allowed-tools`, so the fallback only fires when the skill bundle is intact but the specific skill failed to load; the skill's own tool list covers the live search calls.

---

### Phase 2: Refine

Invoke `jira-ticket-refiner` via the `Skill` tool in read-only-return mode. The agent's Phase 5 already uses this contract; reuse the same calling convention.

The exact prompt to pass:

```
Calling context: skip_preview=true.

The orchestrator owns the user gate; do not run Step 7 preview or write via editJiraIssue. Return the refined title and description as your final output, in this format:

Title: <refined title on one line>

Description:
<refined description as plain markdown, no outer fence>

Ticket key: <ticket_key>
Archetype: <archetype>
Investigation report (use as additional source material; fold any new facts into the description):
<paste the cached investigation_report here>

Ticket payload (markdown):
<paste the ticket_payload markdown body here>
```

The first line is the machine-parseable `Calling context:` directive (one key=value, terminated by a period). The skill's body parses that line, recognizes `skip_preview=true`, and short-circuits its Step 7 (no `AskUserQuestion`, no `editJiraIssue`, no comment posting). It returns the refined title and description as plain text.

Parse the returned text into two strings:

- The line after `Title:` is `refined_title`.
- Everything after the `Description:` line (up to end of output) is `refined_description`.

Cache both. If the skill returns content that does not match this shape, prefer the longest contiguous block as the description and the ticket's original title as a fallback for the refined title rather than failing the run.

**Fallback for when `jira-ticket-refiner` does not load:** restructure the original description plus investigation findings into archetype-appropriate sections per the fallback rules in the `jira-issue-triage` agent's Phase 5. Rewrite the title using `{Area}: {specific problem or goal}` for Bug/Feature/Task, `P{n}: {Area} {short problem statement}` for incidents, or `Spike: {Area} {question to answer}` for spikes. Warn the user once at the start of this phase that the fallback was used.

---

### Phase 3: Style Cleanup

Invoke `prose-style` via the `Skill` tool. Pass the refined title and description from Phase 2 as input and ask for the same content with writing-style rules applied.

The exact prompt to pass:

```
Rewrite the following so the prose reads like a person wrote it. Apply your standard rules: no em dashes or spaced hyphens as separators, no opener phrases, no LLM vocabulary, no bullet sprawl, lead with the answer. Preserve every fact. Return the cleaned content in the same shape as the input.

Title: <refined_title>

Description:
<refined_description>
```

Parse the returned text the same way as Phase 2 (line after `Title:` is `cleaned_title`; the block after `Description:` is `cleaned_description`).

Cache both.

**Fallback for when `prose-style` does not load:** apply these rules inline to the refined title and description before caching them as `cleaned_*`: no em dashes, no spaced hyphens as separators, no LLM vocabulary (`delve`, `leverage`, `robust`, `seamlessly`, `comprehensive`, `nuanced`, `elevate`, `foster`, `paradigm`, `ecosystem`, `holistic`, `innovative`, `synergy`, `empower`, `facilitate`), lead with the answer, no opener phrases, no trailing summaries on short sections, prose over bullet lists when content flows naturally as sentences. Warn the user once at the start of this phase that the fallback was used.

---

### Phase 4: Preview, Confirm, and Write

This is the only user-facing pause in the command.

1. Render a preview to the user as inline markdown (not wrapped in an outer code fence; the description contains its own fenced blocks). Use this layout:

   - A horizontal rule.
   - The cleaned title on its own line: `**Title:** \`{cleaned_title}\``
   - A blank line.
   - The cleaned description as plain markdown.
   - A horizontal rule.
   - A short summary line naming the investigation findings ("Found N hypotheses, evidence at L1/L2/L3/L4" or similar), so the user knows what the comment would include if they pick that option.

2. Ask the user via `AskUserQuestion` with one question and four options:

   - Question: `What should I do with this on {TICKET-KEY}?`
   - Options:
     - `Update title and description` (calls `editJiraIssue` with the cleaned title and description).
     - `Post the investigation findings as a comment` (calls `addCommentToJiraIssue` with the investigation report as ADF; leaves title and description untouched).
     - `Both` (post the comment first, then update title and description).
     - `Cancel without writing` (end the run; nothing is written).

   Cache the answer as `write_choice` (`update`, `comment`, `both`, or `cancel`). The runtime adds an "Other" channel automatically; if the user uses it to request revisions, treat the free-text as guidance and re-enter Phase 2 with the guidance prefixed `User refinement guidance:` on the prompt to `jira-ticket-refiner`. Cap the revision loop at three rounds; on the fourth disagreement, ask `Approve as-is` or `Cancel` as a two-option question and accept the answer.

3. Execute the choice:

   - `cancel`: print `No changes written to {TICKET-KEY}.` and exit.
   - `update`: call `editJiraIssue` once with `fields.summary` set to `cleaned_title` and `fields.description` set to `cleaned_description`. Use `contentFormat: "markdown"` for the description. Never send raw ADF JSON in the description field; the Atlassian MCP converts markdown to ADF on write.
   - `comment`: call `addCommentToJiraIssue` with `contentFormat: "adf"` and `commentBody` set to a JSON-stringified ADF doc built from the investigation report. The ADF structure is described below.
   - `both`: post the comment first (as above), then update the title and description (as above). Two calls. Print one consolidated confirmation at the end.

4. Print a one-line confirmation summarizing what was written:

   - `update`: `Updated title and description on {TICKET-KEY}.`
   - `comment`: `Posted investigation findings as a comment on {TICKET-KEY}.`
   - `both`: `Posted investigation findings and updated title/description on {TICKET-KEY}.`

---

## Comment ADF Construction

When the user picks `comment` or `both`, build the comment body as a JSON-stringified ADF doc. The same rule the rest of the plugin enforces applies here: never use `contentFormat: "markdown"` for comments. Markdown escapes mention brackets and silently breaks link rendering and notifications.

The comment carries the investigation findings only, not the refined title or description (those go on the ticket itself when the user picks `update` or `both`). Build the ADF with:

- A `heading` node (`attrs.level: 2`) whose text is `Investigation Findings ({archetype})`.
- A `paragraph` for each paragraph of the investigation report.
- `bulletList` -> `listItem` -> `paragraph` -> `text` for any bullet sections.
- Inline ticket keys become `text` nodes with a `link` mark pointing at `<jira-base-url>/browse/<KEY>`. Resolve `<jira-base-url>` from the `cloudId` returned by `getAccessibleAtlassianResources`; call it once and cache the URL for the rest of the run.
- Bold uses `marks: [{"type": "strong"}]`.
- Evidence tags (`[VERIFIED]`, `[OBSERVED]`, `[INFERRED]`, `[UNKNOWN]`) stay inline in the same paragraph as the surrounding sentence; do not promote them to their own bullets.

Pass the JSON-stringified ADF as `commentBody`.

---

## Do Not Rules

- Never modify the ticket without showing the user the cleaned title and description first and getting an explicit answer via `AskUserQuestion`.
- Never change the assignee, priority, severity, status, labels, components, or any custom field. This command's scope is title, description, and one comment. For everything else, use the full `jira-issue-triage` agent.
- Never drop screenshots, videos, images, recordings, file attachments, or inline links from the original description. The refined version is a strict superset of the original; every fact and every embedded media reference survives. This rule is inherited from `jira-ticket-refiner` and applies even when the refiner output looks complete.
- Never post a comment using `contentFormat: "markdown"`. All comments are ADF (`contentFormat: "adf"`, `commentBody` = JSON-stringified ADF doc).
- Never send raw ADF JSON in the description field. The Atlassian MCP converts markdown to ADF on write; a raw ADF object fails with `Failed to convert markdown to adf`.
- Never tag the reporter or anyone else in the comment. Reporter follow-up is the `jira-issue-triage` agent's job, not this command's.
- Never invent content during refinement. The refiner and prose-style skill both enforce this; the command does too. If a fact is missing, leave it missing.

## Writing Rules

These apply to all text this command produces (the preview line, the confirmation line, the comment body, and the cleaned title and description before they go to Jira). They duplicate the floor that `prose-style` and `jira-ticket-refiner` already enforce; they're listed here so the command stays consistent even if either skill is unavailable.

- No em dashes or spaced hyphens as separators. Em dashes inside parenthetical asides are fine.
- No LLM vocabulary: `delve`, `leverage`, `robust`, `seamlessly`, `comprehensive`, `nuanced`, `elevate`, `foster`, `paradigm`, `ecosystem`, `holistic`, `innovative`, `synergy`, `empower`, `facilitate`.
- Lead with the answer. No opener phrases.
- No trailing summaries on short sections.
- Prose over bullet lists when the content flows naturally as sentences.
- Never present unverified analysis as a confirmed root cause.

## Examples

A few invocation shapes the command supports:

```
/jira-issue-triage:investigate-and-refine https://acme.atlassian.net/browse/BUG-12345
/jira-issue-triage:investigate-and-refine PROJ-99
/jira-issue-triage:investigate-and-refine SUP-4501
```

Each runs Phases 0-4 in order and pauses at Phase 4 for the user to pick a write action.
