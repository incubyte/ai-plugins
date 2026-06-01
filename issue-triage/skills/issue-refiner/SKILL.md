---
name: issue-refiner
description: "Restructures a poorly written tracker issue into a clear, self-contained document a stranger can open cold and act on. Works on any archetype (Bug, Incident, Story, Feature, Task, Spike) and any supported tracker (Azure DevOps, Jira). Returns the refined title and markdown body; the caller owns the write (issuekit:tracker-adapter projects markdown to the vendor's format)."
metadata:
  author: Taha Bikanerwala
tools: AskUserQuestion, Read
---

# Issue Refiner

Take a tracker issue that is hard to read and turn it into a document a stranger can open cold, in a year, and act on. Reorganize the content. Never delete it. Every fact in the original survives the rewrite, just placed somewhere it can be found.

This skill **does not write to the tracker**. It returns the refined title and markdown body as plain text. The caller (the `issue-triage` agent in Phase 3 prep, or a user invoking the skill directly with a manual write step) batches the write through the adapter's diff-and-confirm gate.

The skill writes **markdown only**. The `issuekit:tracker-adapter` body-format converter projects to AzDO HTML or Jira ADF at write time.

## Calling convention

The skill works two ways. When a user pastes an issue and asks to refine it, the skill fetches and refines, then returns. When the `issue-triage` agent calls in Phase 3 prep, the agent has already fetched the payload and the investigation report; skip the fetch step.

- **Read-only.** No write verb calls. The skill returns text; the caller writes.
- **One pass.** Inventory, classify, rewrite. No iterative back-and-forth with the user unless they paste a revision request.
- **Strict superset.** The refined output contains every fact from the original. Restructure, rewrite, re-tag — never truncate.
- **No solution prescription.** The skill structures information. It does not invent fixes, recommend roadmap, or editorialize on causes that are not in the input.

## Workflow

Six ordered steps. Steps 1, 4, and 5 require reading the corresponding reference file when you reach that step. Do not pre-load the references at the start of the run.

1. **Fetch** the issue (fields, comments, history when relevant, linked issues). Skip when the caller already provides the payload.
2. **Classify** the archetype (Bug / Incident / Story / Feature / Task / Spike). The archetype picks which sections appear in the refined description.
3. **Inventory** every distinct fact across description, comments, history, and linked issues. Tag each fact with its information category. (Reference: `references/classification-guide.md`.)
4. **Rewrite** the inventory into prose, applying the rewrite principles from the same reference.
5. **Apply the template** in `assets/template.md`, including only the sections the archetype calls for. (Reference also applies `issuekit:prose-style` rules to the output before returning.)
6. **Rewrite the title.** (Reference: `references/title-guide.md`.)

The skill returns:

```
{
  refined_title:   string,
  refined_body:    string (markdown),
  archetype:       "Bug" | "Incident" | "Story" | "Feature" | "Task" | "Spike",
  warnings:        string[]   // out-of-subset markdown, content-loss notes
}
```

---

### Step 1: Fetch the issue

Read [`references/gathering-guide.md`](references/gathering-guide.md) when you reach this step. It documents which fields to request, the round-trip content-loss check, and the completeness gate that blocks Step 2 until comments and history have been read.

When the caller (the `issue-triage` agent) has already fetched the issue and exposes the payload, reuse it. Don't re-fetch.

If a direct invocation: call `getIssue(id)` and `getIssueComments(id)` via `issuekit:tracker-adapter`. The adapter normalizes the body to markdown regardless of source format.

### Step 2: Classify the archetype

Use the table below. The archetype is the single most important variable in the rewrite because it picks which template sections appear in the final description.

| Archetype | Typical tracker types | What the content looks like |
|-----------|--------------------------|------------------------------|
| **Bug** | Bug, Defect | A user-visible symptom, an error, broken behavior, or unexpected output. May include reproduction steps. |
| **Incident** | Incident, Outage, Issue (AzDO Agile), Impediment (Scrum), anything tagged Sev-* | Production impact, blast radius, timeline, mitigation steps, post-mortem context. |
| **Story** | Story, User Story, Product Backlog Item (Scrum), Requirement (CMMI), Enhancement, New Feature | A user need or business goal, acceptance criteria, design specs, links to product briefs. |
| **Feature** | Feature | Epic-level feature initiative; multiple stories sit under it. |
| **Task** | Task, Sub-task, Chore, Tech Debt | Operational work: cleanup, configuration, migration, dependency upgrade, runbook execution. |
| **Spike** | Spike, Research, Investigation, Task with spike label | Open questions to resolve, exploration scope, proof-of-concept boundaries, preliminary findings. |

**When the issue type and the content disagree, trust the content.** An issue typed `Bug` whose body is acceptance criteria and a Figma link is a Story. An issue typed `Task` describing user-visible breakage is a Bug.

Hold the archetype as working context. Do not surface it in the output unless the user asks.

### Step 3: Inventory the information

Catalog every distinct fact found in the description, every comment, the history (when read), and any linked issues that add scope. Read [`references/classification-guide.md`](references/classification-guide.md) when you reach this step. It defines the information categories and the verified-vs-unverified flag every item carries.

### Step 4: Rewrite

Apply the rewrite principles from `references/classification-guide.md` (already loaded in Step 3). The principles cover symptoms-over-solutions, evidence-over-claims, prose-over-tables, and the rules for surfacing decisions buried in comment threads.

### Step 5: Apply the template

Structure the rewritten content using [`assets/template.md`](assets/template.md). Three rules are non-negotiable:

- **Pick sections by archetype.** The template ships with an archetype-to-sections map. Include only the sections that map says belong to the current archetype.
- **Skip empty sections.** A section header with no content under it is noise. Omit it.
- **Fold raw metadata into the body.** Source-system blocks (intake forms, support escalation tables, vendor exports) get their facts extracted and placed in the appropriate template section. Do not preserve the raw block verbatim.

### Step 6: Rewrite the title

Read [`references/title-guide.md`](references/title-guide.md) when you reach this step.

### Final cleanup

Before returning, invoke `issuekit:prose-style` on the refined body. The skill runs the writing-style rules (em dashes, LLM vocabulary, opener phrases, hedging). The refined body that comes back is what the skill returns to the caller.

## Markdown subset and reserved tokens

The body must conform to the canonical markdown subset in `issuekit/skills/tracker-adapter/references/body-format.md`. Headings, bold, italic, inline code, fenced code, bullet/numbered lists, links, blockquotes, horizontal rules, mentions via `@[userRef]`. Tables only when 4+ rows with distinct columns. No HTML, no wiki markup, no strikethrough, no interactive checkboxes.

Out-of-subset constructs in the input round-trip as literal text and trigger a one-line warning in the returned `warnings` array.

## Anti-patterns

1. **Never present unverified analysis as confirmed root cause.** Frame it as a working hypothesis in the Working Hypotheses section, in plain prose.
2. **Never inject solutions that aren't in the original.** If evidence points toward a fix, surface the evidence. Drop the solution.
3. **Never add roadmap or tech-debt suggestions.** An issue description is a record, not a forum for "we should also...".
4. **Never replace the description with less information.** The refined version is a strict superset of the original.
5. **Never lose investigation artifacts.** Customer IDs, log links, query results, error strings, attachment URLs, screenshot embeds, video links — every one survives.
6. **Never restate sidebar metadata.** Status, priority, issue type, parent, assignee, reporter, labels, components live in the tracker UI sidebar. Repeating them in the body adds noise. The exception is comment-thread context, which is hidden behind a tab and worth surfacing.
7. **Never use Bug sections on non-Bug archetypes.** Stories have no reproduction steps. Tasks have no expected/actual behavior. Spikes have no acceptance criteria. The archetype-to-sections map exists for this reason.
8. **Never put a to-do list in the description.** Queries to run, dashboards to check, flags to verify — those are next-step actions. They belong in a comment (which the agent posts in Phase 4 of triage).

## Writing style

These rules apply to everything this skill produces.

- No em dashes or spaced hyphens as separators. Restructure.
- No LLM vocabulary: delve, leverage, robust, seamlessly, comprehensive, nuanced, elevate, foster, paradigm, ecosystem, holistic, innovative, synergy, empower, facilitate.
- Lead with the answer. No opener phrases.
- No trailing summary on a short section.
- Prefer prose over bullets when the content reads cleanly as sentences.
- `issuekit:prose-style` runs on the refined body before return; these rules are the floor.
