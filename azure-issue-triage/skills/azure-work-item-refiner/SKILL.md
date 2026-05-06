---
name: azure-work-item-refiner
description: "Restructures a poorly written Azure DevOps work item into a clear, self-contained document that a stranger can read cold and act on. Works on any work-item type (Bug, Incident, User Story / Feature, Task, Spike). Updates the description (System.Description) and title (System.Title) via the Azure DevOps MCP and never deletes original content. Use when the user asks to refine, rewrite, restructure, clean up, or improve an Azure DevOps work item."
metadata:
  author: Taha Bikanerwala
tools: AskUserQuestion, Read, wit_get_work_item, wit_update_work_item, wit_add_work_item_comment, core_list_projects
---

# Azure Work Item Refiner

Take an Azure DevOps work item that is hard to read and turn it into a document a stranger can open cold, in a year, and act on. Reorganize the content. Never delete it. Every fact in the original survives the rewrite, just placed somewhere it can be found.

This skill modifies Azure DevOps in its default mode: it updates the work item's title and description (writing to the `System.Title` and `System.Description` fields, both submitted as a JSON Patch document via `wit_update_work_item`), and posts an optional next-steps comment when the user asks for one. **One exception:** when invoked with `Calling context: skip_preview=true.` (the `azure-issue-triage` agent does this in Phase 5), the skill operates in **read-only-return mode** and performs no Azure DevOps writes at all; it returns the refined title and description as plain text for the caller to write. See the "Calling Convention" bullets below for the full read-only-return contract.

## Calling Convention

The skill works two ways. When a user pastes a work-item ID or URL and asks to refine it, run end to end. When the `azure-issue-triage` agent calls this skill in Phase 5, treat the agent's already-fetched payload and investigation findings as the source data and skip the fetch step.

- **One confirmation gate.** Always preview the rewrite before calling `wit_update_work_item`. The user must approve. **Exception:** when the prompt passed to the skill begins with `Calling context: skip_preview=true.` (the `azure-issue-triage` agent inserts this leading line in Phase 5 because the agent already captured user approval at Phase 3 and renders its own informational preview before writing), the skill operates in **read-only-return mode**:
  - Do not call `AskUserQuestion` (no preview gate).
  - Do not call `wit_update_work_item` (no description or title write).
  - Do not call `wit_add_work_item_comment` (no Step 8 next-steps comment, even if the input would normally trigger it).
  - Do not call any other Azure-DevOps-mutating MCP tool.
  - The skill's only side effects are reading the cached payload and producing the refined title and description as plain-text output for the caller to consume.
  - The agent (Phase 5 step 4) owns the `wit_update_work_item` write; if the user wants a Step 8 next-steps comment, they request it through a separate flow after the agent run completes.
- **Read-then-write.** Refuse to write before reading the description, comments, and (when relevant) revision history.
- **Strict superset.** The refined work item contains every fact from the original. Restructure, rewrite, and re-tag, never truncate.
- **No solution prescription.** The skill structures information. It does not invent fixes, recommend roadmap, or editorialize on causes that are not in the work item.

## Prerequisites

- The user provides a work-item ID (e.g., `12345`) or a work-item URL (e.g., `https://dev.azure.com/<org>/<project>/_workitems/edit/12345`).
- The Azure DevOps MCP server is configured. `core_list_projects` returns at least one project so the organization context is resolvable.
- The user has edit permission on the work item.

If any prerequisite fails, stop and tell the user which call failed before continuing.

## Workflow

The workflow is eight ordered steps. Steps 1, 5, and 6 require reading the corresponding reference file when you reach that step. Do not pre-load the references at the start of the run.

1. **Fetch** the work item: fields, comments, revision history when needed, and linked work items.
2. **Classify** the work-item archetype (Bug / Feature / Task / Incident / Spike). The archetype controls which sections appear in the refined description.
3. **Inventory** every distinct fact across the description, comments, revision history, and linked work items. Tag each fact with its information category.
4. **Rewrite** the inventory into prose, applying the rewrite principles.
5. **Apply the template** in `assets/template.md`, including only the sections the archetype calls for.
6. **Rewrite the title** so a reader on a board can decide whether to open the work item.
7. **Preview** the proposed title and description as inline markdown. Wait for the user to approve.
8. **Post a next-steps comment** only when the user asks for one.

---

### Step 1: Fetch the Work Item

Read [references/gathering-guide.md](references/gathering-guide.md) when you reach this step. It documents which fields to request, the HTML content-loss check, and the completeness gate that blocks Step 2 until comments and revision history are read.

If the calling context (the `azure-issue-triage` agent in Phase 5) has already fetched the work item and exposes the payload, reuse it. Do not refetch.

### Step 2: Classify the Archetype

Use the table below. The archetype is the single most important variable in the rewrite because it picks which template sections appear in the final description.

| Archetype | Typical Azure DevOps work-item types | What the content looks like |
|-----------|---------------------------------------|------------------------------|
| **Bug** | Bug | A user-visible symptom, an error, broken behavior, or unexpected output. May include reproduction steps. |
| **Feature** | User Story (Agile), Product Backlog Item (Scrum), Requirement (CMMI), Feature, Epic | A user need or business goal, acceptance criteria, design specs, links to product briefs. |
| **Task** | Task | Operational work: cleanup, configuration, migration, dependency upgrade, runbook execution. |
| **Incident** | Issue (Agile), Impediment (Scrum), Issue (CMMI). Some teams also use Bug + a `incident` tag. | Production impact, blast radius, timeline, mitigation steps, post-mortem context. |
| **Spike** | Task or User Story tagged `spike`, or a custom Spike work-item type. | Open questions to resolve, exploration scope, proof-of-concept boundaries, preliminary findings. |

**When the work-item type and the content disagree, trust the content.** A work item typed `Bug` whose body is acceptance criteria and a Figma link is a Feature. A work item typed `Task` describing user-visible breakage is a Bug. The content drives the template, not the work-item type field.

Hold the archetype as working context. Do not surface it in the preview unless the user asks.

### Step 3: Inventory the Information

Catalog every distinct fact found in the description, every comment, the revision history (if read), and any linked work items that add scope. Read [references/classification-guide.md](references/classification-guide.md) when you reach this step. It defines the seven information categories and the verified-vs-unverified flag every item carries.

### Step 4: Rewrite

Apply the rewrite principles from `references/classification-guide.md` (already loaded in Step 3). The principles cover symptoms-over-solutions, evidence-over-claims, prose-over-tables, and the rules for surfacing decisions buried in comment threads.

### Step 5: Apply the Template

Structure the rewritten content using `assets/template.md`. Read it now, alongside [references/azure-html-formatting.md](references/azure-html-formatting.md) for the markdown-to-HTML safety rules.

Three rules are non-negotiable:

- **Pick sections by archetype.** The template ships with an archetype-to-sections map. Include only the sections that map says belong to the current archetype.
- **Skip empty sections.** A section header with no content under it is noise. Omit it.
- **Fold raw metadata into the body.** Source-system blocks (intake forms, support escalation tables, Zendesk dumps, customer-feedback exports) get their facts extracted and placed in the appropriate template section. Do not preserve the raw block verbatim. The only time an Original Metadata section is appropriate is when a fact is genuinely unclassifiable and has no other home.

### Step 6: Rewrite the Title

Read [references/title-guide.md](references/title-guide.md) when you reach this step. It documents the title pattern, the archetype-by-archetype examples, and the character budget.

### Step 7: Preview and Confirm

Preview before posting. The preview is the user's only chance to catch a mistake before the work item is overwritten.

**Render the preview as inline markdown.** The refined description contains its own fenced code blocks (errors, queries, JSON). Wrapping the whole preview in an outer code fence breaks every inner block. Use this exact layout:

1. A horizontal rule.
2. The new title on its own line, formatted as bold `Title:` followed by the rewritten title text inside an inline-code span. "Title" here means the user-facing label and the value that will land in the `System.Title` field. The literal markdown to emit is shown below.
3. A blank line.
4. The full refined description rendered as plain markdown, no outer fence. The agent body converts this markdown to HTML before writing; see `references/azure-html-formatting.md` for the safe-HTML subset and conversion rules.
5. A horizontal rule.
6. A short prompt asking the user to approve or request changes.

The title line in step 2 looks like this when emitted as markdown:

```markdown
**Title:** `{the rewritten title}`
```

Do not pad the preview with workflow notes (`Archetype:`, `HTML warning:`, `Previous state:`). The preview is what will appear on the work item. If the rewrite carries a real risk of losing HTML-only content (rich attachments, embedded videos, complex tables, in-line mentions, color-tinted callouts), say so in one sentence outside the preview. Do not warn for cosmetic-only losses.

After the user reviews:

- **Approved.** Call `wit_update_work_item` once with a JSON Patch document setting `System.Title` and `System.Description`. The patch's `System.Description` value is HTML; convert the markdown rewrite to HTML using the rules in `references/azure-html-formatting.md`. Never send raw markdown into `System.Description`: the AzDO API stores it verbatim and renders the literal markdown characters on the work item.
- **Changes requested.** Revise and re-preview. Do not call `wit_update_work_item` until the user explicitly approves.

### Step 8: Post a Next-Steps Comment

Skip this step unless the user asks for it.

When asked, post via `wit_add_work_item_comment`. Comments in Azure DevOps are stored as HTML; convert your draft from markdown to safe HTML using the rules in `references/azure-html-formatting.md` before submitting.

Build the comment with these elements:

- An `<h2>` heading whose text is `Next Steps (YYYY-MM-DD)`. Substitute today's date in `YYYY-MM-DD` form. Use parentheses for the date so the heading does not need a separator.
- An `<ol>` list containing one `<li>` per action.
- Every action names an owner or team (as plain text, not an `@mention`, unless the user explicitly approved tagging that account).
- Use concrete verbs. Write `Verify token rotation schedule with Platform team` rather than `Look into auth`.

The skeleton below is the structure to build. Substitute the real date for `YYYY-MM-DD`.

```html
<h2>Next Steps (YYYY-MM-DD)</h2>
<ol>
  <li>Verify token rotation schedule with Platform team.</li>
  <li>Page on-call if customer impact persists past 14:00 UTC.</li>
</ol>
```

Comment body actions belong here, not in the description. The description records what is known and unknown. The comment records what happens next.

---

## Anti-Patterns

These are hard rules. Each one prevents a failure mode that has been observed on real refinements.

1. **Never present unverified analysis as confirmed root cause.** Frame it as a working hypothesis in the Working Hypotheses section, in plain prose. No disclaimer block, no warning panel.
2. **Never inject solutions that are not in the original work item.** If the original contains evidence pointing toward a fix, surface the evidence. Drop the solution.
3. **Never add roadmap or tech-debt suggestions.** A work-item description is a record. It is not a forum for "we should also...".
4. **Never replace the description with less information.** The refined version is a strict superset of the original. The amount of unique information cannot decrease.
5. **Never lose investigation artifacts.** Customer IDs, log links, query results, error strings, attachment URLs, screenshot embeds, video links: every one survives.
6. **Never emit raw markdown into `System.Description`.** The API stores HTML; it does not run a markdown-to-HTML conversion. Convert before writing.
7. **Never inject `<script>` or other unsafe HTML.** AzDO sanitizes most unsafe HTML on render but the patch may be rejected. Stick to the safe subset in `references/azure-html-formatting.md`.
8. **Never restate sidebar metadata.** State, work-item type, parent, assignee, tags, area path, and iteration path are all visible in the AzDO UI. Repeating them in the body adds noise. The exception is comment-thread context, which is hidden behind the Discussion tab and worth surfacing.
9. **Never use bug sections on non-bug work items.** Features have no reproduction steps. Tasks have no expected/actual behavior. Spikes have no acceptance criteria. The archetype-to-sections map exists for this reason.
10. **Never put a to-do list in the description.** Queries to run, dashboards to check, flags to verify: those are next-step actions. They belong in a comment (Step 8) when the user asks for one. Frame open questions in the description as named open questions, not as a checklist.

## Writing Style

These rules apply to everything this skill produces: work-item descriptions, summaries, preview text, comments, and any prose addressed to the user.

- **No em dashes or spaced hyphens as separators.** Restructure the sentence. Em dashes inside parenthetical asides are fine.
- **No LLM vocabulary.** Strike: delve, leverage, robust, seamlessly, comprehensive, nuanced, elevate, foster, paradigm, ecosystem, holistic, innovative, synergy, empower, facilitate.
- **Lead with the answer.** No opener phrases (`In this work item, we need to...`). The first sentence states what the work item is about.
- **No trailing summary on a short section.** If the section is three sentences, the third sentence is not a recap of the first two.
- **Prefer prose over bullets** when the content reads cleanly as sentences. Bullets are for genuinely list-shaped data.

If the user has the `prose-style` skill installed, defer to it after this skill produces the rewrite. The rules above are the floor.
