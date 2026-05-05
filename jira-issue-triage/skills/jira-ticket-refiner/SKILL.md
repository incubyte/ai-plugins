---
name: jira-ticket-refiner
description: "Restructures a poorly written Jira ticket into a clear, self-contained document that a stranger can read cold and act on. Works on any ticket type (bug, feature, task, spike, incident). Updates the description and title via the Atlassian MCP and never deletes original content. Use when the user asks to refine, rewrite, restructure, clean up, or improve a Jira ticket."
metadata:
  author: Taha Bikanerwala
tools: AskUserQuestion, Read, mcp__plugin_atlassian_atlassian__getAccessibleAtlassianResources, mcp__plugin_atlassian_atlassian__getJiraIssue, mcp__plugin_atlassian_atlassian__editJiraIssue, mcp__plugin_atlassian_atlassian__addCommentToJiraIssue
---

# Jira Ticket Refiner

Take a Jira ticket that is hard to read and turn it into a document a stranger can open cold, in a year, and act on. Reorganize the content. Never delete it. Every fact in the original survives the rewrite, just placed somewhere it can be found.

This skill modifies Jira in its default mode: it updates the ticket's description and title (writing to the `fields.description` and `fields.summary` Jira API fields, respectively) via the Atlassian MCP, and posts an optional next-steps comment when the user asks for one. **One exception:** when invoked with `Calling context: skip_preview=true.` (the `jira-issue-triage` agent does this in Phase 5), the skill operates in **read-only-return mode** and performs no Jira writes at all; it returns the refined title and description as plain text for the caller to write. See the "Calling Convention" bullets below for the full read-only-return contract.

## Calling Convention

The skill works two ways. When a user pastes a ticket key and asks to refine it, run end to end. When the `jira-issue-triage` agent calls this skill in Phase 5, treat the agent's already-fetched payload and investigation findings as the source data and skip the fetch step.

- **One confirmation gate.** Always preview the rewrite before calling `editJiraIssue`. The user must approve. **Exception:** when the prompt passed to the skill begins with `Calling context: skip_preview=true.` (the `jira-issue-triage` agent inserts this leading line in Phase 5 because the agent already captured user approval at Phase 3 and renders its own informational preview before writing), the skill operates in **read-only-return mode**:
  - Do not call `AskUserQuestion` (no preview gate).
  - Do not call `editJiraIssue` (no description or title write).
  - Do not call `addCommentToJiraIssue` (no Step 8 next-steps comment, even if the input would normally trigger it).
  - Do not call any other Jira-mutating MCP tool.
  - The skill's only side effects are reading the cached payload and producing the refined title and description as plain-text output for the caller to consume.
  - The agent (Phase 5 step 4) owns the `editJiraIssue` write; if the user wants a Step 8 next-steps comment, they request it through a separate flow after the agent run completes.
- **Read-then-write.** Refuse to write before reading the description, comments, and (when relevant) changelog.
- **Strict superset.** The refined ticket contains every fact from the original. Restructure, rewrite, and re-tag, never truncate.
- **No solution prescription.** The skill structures information. It does not invent fixes, recommend roadmap, or editorialize on causes that are not in the ticket.

## Prerequisites

- The user provides a Jira ticket key (e.g., `BUG-1234`) or a ticket URL.
- The Atlassian MCP server is configured. `getAccessibleAtlassianResources` returns at least one site so the `cloudId` is resolvable.
- The user has edit permission on the ticket.

If any prerequisite fails, stop and tell the user which call failed before continuing.

## Workflow

The workflow is eight ordered steps. Steps 1, 5, and 6 require reading the corresponding reference file when you reach that step. Do not pre-load the references at the start of the run.

1. **Fetch** the ticket: fields, comments, changelog when needed, and linked tickets.
2. **Classify** the ticket archetype (Bug / Feature / Task / Incident / Spike). The archetype controls which sections appear in the refined description.
3. **Inventory** every distinct fact across the description, comments, changelog, and linked tickets. Tag each fact with its information category.
4. **Rewrite** the inventory into prose, applying the rewrite principles.
5. **Apply the template** in `assets/template.md`, including only the sections the archetype calls for.
6. **Rewrite the title** so a reader on a board view can decide whether to open the ticket.
7. **Preview** the proposed title and description as inline markdown. Wait for the user to approve.
8. **Post a next-steps comment** only when the user asks for one.

---

### Step 1: Fetch the Ticket

Read [references/gathering-guide.md](references/gathering-guide.md) when you reach this step. It documents which fields to request, the ADF content-loss check, and the completeness gate that blocks Step 2 until comments and changelog are read.

If the calling context (the `jira-issue-triage` agent in Phase 5) has already fetched the ticket and exposes the payload, reuse it. Do not refetch.

### Step 2: Classify the Archetype

Use the table below. The archetype is the single most important variable in the rewrite because it picks which template sections appear in the final description.

| Archetype | Typical Jira issue types | What the content looks like |
|-----------|--------------------------|------------------------------|
| **Bug** | Bug, Defect | A user-visible symptom, an error, broken behavior, or unexpected output. May include reproduction steps. |
| **Feature** | Story, Feature, Enhancement, New Feature | A user need or business goal, acceptance criteria, design specs, links to product briefs. |
| **Task** | Task, Sub-task, Chore, Tech Debt | Operational work: cleanup, configuration, migration, dependency upgrade, runbook execution. |
| **Incident** | Incident, Outage, SEV-tagged tickets | Production impact, blast radius, timeline, mitigation steps, post-mortem context. |
| **Spike** | Spike, Research, Investigation | Open questions to resolve, exploration scope, proof-of-concept boundaries, preliminary findings. |

**When the issue type and the content disagree, trust the content.** A ticket typed `Bug` whose body is acceptance criteria and a Figma link is a Feature. A ticket typed `Task` describing user-visible breakage is a Bug. The content drives the template, not the Jira issue type field.

Hold the archetype as working context. Do not surface it in the preview unless the user asks.

### Step 3: Inventory the Information

Catalog every distinct fact found in the description, every comment, the changelog (if read), and any linked tickets that add scope. Read [references/classification-guide.md](references/classification-guide.md) when you reach this step. It defines the seven information categories and the verified-vs-unverified flag every item carries.

### Step 4: Rewrite

Apply the rewrite principles from `references/classification-guide.md` (already loaded in Step 3). The principles cover symptoms-over-solutions, evidence-over-claims, prose-over-tables, and the rules for surfacing decisions buried in comment threads.

### Step 5: Apply the Template

Structure the rewritten content using `assets/template.md`. Read it now, alongside [references/jira-formatting.md](references/jira-formatting.md) for the markdown-to-ADF safety rules.

Three rules are non-negotiable:

- **Pick sections by archetype.** The template ships with an archetype-to-sections map. Include only the sections that map says belong to the current archetype.
- **Skip empty sections.** A section header with no content under it is noise. Omit it.
- **Fold raw metadata into the body.** Source-system blocks (intake forms, support escalation tables, Zendesk dumps, Applause exports) get their facts extracted and placed in the appropriate template section. Do not preserve the raw block verbatim. The only time an Original Metadata section is appropriate is when a fact is genuinely unclassifiable and has no other home.

### Step 6: Rewrite the Title

Read [references/title-guide.md](references/title-guide.md) when you reach this step. It documents the title pattern, the archetype-by-archetype examples, and the character budget.

### Step 7: Preview and Confirm

Preview before posting. The preview is the user's only chance to catch a mistake before the ticket is overwritten.

**Render the preview as inline markdown.** The refined description contains its own fenced code blocks (errors, queries, JSON). Wrapping the whole preview in an outer code fence breaks every inner block. Use this exact layout:

1. A horizontal rule.
2. The new title on its own line, formatted as bold `Title:` followed by the rewritten title text inside an inline-code span. "Title" here means the user-facing label and the value that will land in the Jira `fields.summary` field. The literal markdown to emit is shown below.
3. A blank line.
4. The full refined description rendered as plain markdown, no outer fence.
5. A horizontal rule.
6. A short prompt asking the user to approve or request changes.

The title line in step 2 looks like this when emitted as markdown:

```markdown
**Title:** `{the rewritten title}`
```

Do not pad the preview with workflow notes (`Archetype:`, `ADF warning:`, `Previous state:`). The preview is what will appear on the ticket. If the rewrite carries a real risk of losing ADF-only content (panels with substantive text, mentions, task lists with checked items, expand sections, embedded media, complex tables), say so in one sentence outside the preview. Do not warn for cosmetic-only losses such as a smart-link card becoming a plain URL.

After the user reviews:

- **Approved.** Call `editJiraIssue` once with `fields.summary` and `fields.description` set. Use `contentFormat: "markdown"` for the description. Never send raw ADF JSON in the description field.
- **Changes requested.** Revise and re-preview. Do not call `editJiraIssue` until the user explicitly approves.

### Step 8: Post a Next-Steps Comment

Skip this step unless the user asks for it.

When asked, post via `addCommentToJiraIssue` with `contentFormat: "adf"`. The comment body is a JSON-stringified ADF (Atlassian Document Format) doc. Never use `contentFormat: "markdown"` for comments in this plugin: markdown escapes mention brackets, link targets, and rich marks, which silently breaks notifications and renders chips as literal text. The same rule appears in the `jira-issue-triage` agent body so the plugin stays consistent.

Build the ADF doc with these nodes:

- A `heading` node (`attrs.level: 2`) whose text is `Next Steps (YYYY-MM-DD)`. Substitute today's date in `YYYY-MM-DD` form. Use parentheses for the date so the heading does not need a separator.
- An `orderedList` node containing one `listItem` per action. Each `listItem` wraps a `paragraph` whose `content` is one or more `text` nodes.
- Every action names an owner or team (as plain text, not a `mention` node, unless the user explicitly approved tagging that account).
- Use concrete verbs. Write `Verify token rotation schedule with Platform team` rather than `Look into auth`.

The skeleton below is the structure to build, shown as a JSON object for readability. Before passing it to `addCommentToJiraIssue`, serialize it with `JSON.stringify(adfDoc)` and put the resulting string in `commentBody`. The `YYYY-MM-DD` token is a placeholder; substitute the real date.

```json
{
  "type": "doc",
  "version": 1,
  "content": [
    {
      "type": "heading",
      "attrs": { "level": 2 },
      "content": [{ "type": "text", "text": "Next Steps (YYYY-MM-DD)" }]
    },
    {
      "type": "orderedList",
      "content": [
        {
          "type": "listItem",
          "content": [
            {
              "type": "paragraph",
              "content": [
                { "type": "text", "text": "Verify token rotation schedule with Platform team." }
              ]
            }
          ]
        }
      ]
    }
  ]
}
```

The full call shape (with the structure above stringified into `commentBody`):

```json
{
  "contentFormat": "adf",
  "commentBody": "{\"type\":\"doc\",\"version\":1,\"content\":[ ... ]}"
}
```

Comment body actions belong here, not in the description. The description records what is known and unknown. The comment records what happens next.

---

## Anti-Patterns

These are hard rules. Each one prevents a failure mode that has been observed on real refinements.

1. **Never present unverified analysis as confirmed root cause.** Frame it as a working hypothesis in the Working Hypotheses section, in plain prose. No disclaimer block, no warning panel.
2. **Never inject solutions that are not in the original ticket.** If the original contains evidence pointing toward a fix, surface the evidence. Drop the solution.
3. **Never add roadmap or tech-debt suggestions.** A ticket description is a record. It is not a forum for "we should also...".
4. **Never replace the description with less information.** The refined version is a strict superset of the original. The amount of unique information cannot decrease.
5. **Never lose investigation artifacts.** Customer IDs, log links, query results, error strings, attachment URLs, screenshot embeds, video links: every one survives.
6. **Never use escaped newlines.** `\n` renders as a literal backslash-n in Jira. Use real line breaks.
7. **Never send raw ADF JSON in the description field.** The MCP server runs markdown-to-ADF conversion every time. A raw ADF object fails with `Failed to convert markdown to adf`.
8. **Never restate sidebar metadata.** Status, priority, issue type, parent epic, assignee, reporter, labels, and components are all visible in the Jira UI. Repeating them in the body adds noise. The exception is comment-thread context, which is hidden behind a tab and worth surfacing.
9. **Never use bug sections on non-bug tickets.** Features have no reproduction steps. Tasks have no expected/actual behavior. Spikes have no acceptance criteria. The archetype-to-sections map exists for this reason.
10. **Never put a to-do list in the description.** Queries to run, dashboards to check, flags to verify: those are next-step actions. They belong in a comment (Step 8) when the user asks for one. Frame open questions in the description as named open questions, not as a checklist.

## Writing Style

These rules apply to everything this skill produces: ticket descriptions, summaries, preview text, comments, and any prose addressed to the user.

- **No em dashes or spaced hyphens as separators.** Restructure the sentence. Em dashes inside parenthetical asides are fine.
- **No LLM vocabulary.** Strike: delve, leverage, robust, seamlessly, comprehensive, nuanced, elevate, foster, paradigm, ecosystem, holistic, innovative, synergy, empower, facilitate.
- **Lead with the answer.** No opener phrases (`In this ticket, we need to...`). The first sentence states what the ticket is about.
- **No trailing summary on a short section.** If the section is three sentences, the third sentence is not a recap of the first two.
- **Prefer prose over bullets** when the content reads cleanly as sentences. Bullets are for genuinely list-shaped data.

If the user has the `prose-style` skill installed, defer to it after this skill produces the rewrite. The rules above are the floor.
