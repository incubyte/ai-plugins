---
name: azure-requirements-investigator
description: "Investigates a non-bug Azure DevOps work item (User Story, Feature, Task, Spike) by reading the work item and linked design or product docs, searching Microsoft Teams and AzDO Wiki for prior decisions, and producing an evidence-tagged orientation report. Use when a developer is about to pick up a non-bug work item and wants context before starting work."
metadata:
  author: Taha Bikanerwala
tools: Read, Bash, Grep, wit_get_work_item, wit_query_by_wiql, wiki_search, teams_search_messages, teams_read_thread
---

# Azure Requirements Investigator

Produce a structured report that orients a developer about to pick up a User Story, Feature, Task, or Spike work item. The report names what is being built (or asked), surfaces prior decisions found in Microsoft Teams and AzDO Wiki, lists the open questions that block start-of-work, and tags every claim with its evidence level.

**Scope:** User Story, Feature, Task, Spike. The agent's Phase 0 routes any of these archetypes into this skill. Bug and Incident go to `azure-issue-investigator` instead.

This skill investigates. It does not solve, post, or modify anything.

## Calling Convention

This skill runs without user interaction. The constraints below let it work cleanly inside the `azure-issue-triage` agent (which has its own confirmation gate) and standalone.

- **Non-interactive.** Never ask the user a question. Inputs are inferred from the work item and search results.
- **Predictable structure.** Per-archetype templates with fixed section orders. The archetype is passed by the caller; when running standalone, infer it from the work-item-type field.
- **Same evidence tags.** Always `[VERIFIED]`, `[OBSERVED]`, `[INFERRED]`, `[UNKNOWN]`.
- **Output is the last thing.** Skill ends after the report renders. No follow-up prompts.
- **Read-only.** No `wit_update_work_item`, no `wit_add_work_item_comment`, no `teams_send_message`. Posting is the caller's job.

## Tool naming note

The frontmatter `tools` list uses short, unprefixed names (`wit_get_work_item`, `wit_query_by_wiql`, `wiki_search`, `teams_search_messages`). The actual tool prefix depends on which Azure DevOps MCP server and which Teams MCP server you have installed and how Claude Code mounts them. If the skill's tool calls fail because the prefix doesn't match, edit the frontmatter to add your prefix once. The skill body refers to tools by their short name throughout. If no Teams MCP is installed, Level 1 is silently skipped.

## Search Ladder

Investigation runs three levels top to bottom. Each level has a gate: if it produces enough evidence to write a useful report, skip the remaining levels. Datadog is not in the ladder by default; non-bug work items rarely have runtime telemetry to query, and adding it pulls in a tool the skill does not need for this archetype.

### Setup

Before running the levels, fetch the work item once and cache it for the rest of the skill.

1. Identify the work-item ID from the invocation context (e.g., `12345` from a pasted URL or a parameter passed by the caller). If the calling context (such as the `azure-issue-triage` agent) has already fetched the work item and exposed the payload, reuse that payload; don't fetch again.
2. If no payload is available, call `wit_get_work_item` with the ID and `expand: "all"`. Request these fields at minimum: `System.Title`, `System.Description`, `System.State`, `System.WorkItemType`, `System.Tags`, `System.AreaPath`, `System.IterationPath`, `System.AssignedTo`, `System.CreatedBy`, `System.CreatedDate`, `System.ChangedDate`, `System.Parent`, plus the `relations` array. Add the optional fields the caller cares about (`Microsoft.VSTS.Common.AcceptanceCriteria`, `Microsoft.VSTS.Scheduling.StoryPoints`) when known.
3. Determine the archetype: use the value passed by the caller. If running standalone, map `System.WorkItemType` using the table below. If the work-item type is `Bug`, or `Issue` / `Impediment` (which the agent routes as Incident), stop and tell the caller this skill does not handle those archetypes; route to `azure-issue-investigator` instead.

   | Work-item type (Agile / Scrum / CMMI) | Archetype | Report template |
   |---------------------------------------|-----------|-----------------|
   | User Story (Agile) / Product Backlog Item (Scrum) / Requirement (CMMI) | User Story | Feature template |
   | Feature / Epic | Feature (epic-level — note in Lead) | Feature template |
   | Task | Task | Task template |
   | Task tagged `spike`, or a custom `Spike` work-item type | Spike | Spike template |

4. Cache the response as "the work-item payload" throughout the skill.

If `wit_get_work_item` fails (auth error, work item not found, network), stop and tell the caller which call failed. Do not proceed without work-item data.

### Level 1: Teams

Skip entirely if no Teams MCP server is installed.

Run 2-3 queries via `teams_search_messages`:

1. The work-item ID (e.g., `12345` or `AB#12345`).
2. The feature, task, or spike name, or the most distinctive phrase from the title.
3. The area or system name combined with a key term from the description.

For each relevant hit, follow the thread in full with `teams_read_thread`.

What you are looking for:
- A prior decision that defines the scope (often labeled "decided", "approved", "agreed").
- A linked design doc, product brief, or RFC.
- A named owner or Decider for the area.
- A prior thread that names the same problem with a different framing (the team may have a different vocabulary for the same scope).

**Gate:** if a Teams thread contains a confirmed scope statement, an approved design link, or a clear "out of scope" decision, write the report citing that thread and skip Levels 2-3.

### Level 2: Work Item + AzDO + Wiki

Read the work-item payload (cached in Setup) carefully. Signals are easy to miss on a fast scan: linked design docs, mentions of related work items, vocabulary like "blocks" or "depends on" that points at sequencing constraints, the question the reporter is actually asking.

Then search:

- **Linked work items.** Walk every entry in the `relations` array and the `System.Parent` field. Read the related work-item titles and the most recent 1-2 comments. Note: state, assignee, the most relevant scope statement.
- **Related work items** via `wit_query_by_wiql`. Common patterns:
  - `SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.TeamProject] = '<project>' AND [System.Description] CONTAINS '<feature name>' ORDER BY [System.CreatedDate] DESC`
  - `SELECT [System.Id], [System.Title], [System.State] FROM WorkItems WHERE [System.TeamProject] = '<project>' AND [System.AreaPath] UNDER '<area>' AND [System.WorkItemType] IN ('User Story', 'Product Backlog Item', 'Task', 'Feature') ORDER BY [System.CreatedDate] DESC`
  - When the work item has a parent epic or feature: `SELECT [System.Id], [System.Title] FROM WorkItemLinks WHERE Source.[System.Id] = <parent-id> AND [System.Links.LinkType] = 'System.LinkTypes.Hierarchy-Forward' MODE (Recursive)`.
- **AzDO Wiki** via `wiki_search`. Search for product briefs, design docs, ADRs, RFCs, runbooks for the area. Use the feature area, system name, or product theme as the search term.

For each related work item, record: ID, title, state, assignee, the most relevant scope or AC finding.
For each Wiki page, record: URL and a 1-line summary of what it contains.

**Gate:** if a product brief or design doc explicitly states the scope and acceptance criteria for this work, write the report citing that source. Skip Level 3 unless the work item also references existing code that needs orientation.

### Level 3: Code

Enter only when Levels 1-2 turned up nothing useful, OR the work item explicitly references existing code that needs context to size or scope the work.

1. **Affected service or module.** When the work item names a service, module, or file path, use `Bash` (e.g., `git ls-files | grep -i 'pattern'`) or `Grep` to locate it in the repository. Note the relative path.
2. **Existing patterns.** When the work item references "the same way we do X for Y", use `Grep` to find the X pattern and `Read` the existing implementation. Record the path and a 1-line summary of the pattern.
3. **Recent changes.** Run `git log --since="2 months ago" -- <path>` via `Bash` to find commits in the affected area. The recent change list informs the "Where To Look" section.

Stop when you can name: which area of the code is involved, what existing patterns to follow, and 1-3 specific files or directories the developer should open first. Do not trace full call chains; this is orientation, not implementation.

## Evidence Model

Every claim in the report carries one of four tags.

| Tag | Meaning |
|-----|---------|
| `[VERIFIED]` | Directly confirmed. Read in code or in an authoritative source (design doc, ADR, work-item description) that explicitly states this. |
| `[OBSERVED]` | A pattern matches the reported scope, but reaching the conclusion required a logical step. |
| `[INFERRED]` | Logical deduction from available information. Not directly observed. |
| `[UNKNOWN]` | Cannot determine from available sources. Requires asking a person or reading docs that were not found. |

If the finished report has more `[INFERRED]` than `[VERIFIED]` findings, the search was insufficient. Go back and search more before writing.

Every `[UNKNOWN]` becomes either an "Open Questions" item (when the unknown blocks start of work and a person can answer it) or a "Where To Look" item (when the unknown can be resolved by reading or searching).

## Stop Condition

Investigation is **done** when all three are true:

1. The Lead names what the work item asks for in one or two sentences, with the strongest evidence inline.
2. At least one source has been consulted at every search level the investigation reached. (If Level 1 closed via its gate, Levels 2-3 do not need sources. If Level 1 was skipped because no Teams MCP is installed, that is not a source gap.)
3. There are concrete next-step queries, file paths, or doc links in "Where To Look".

If any one is missing, keep investigating.

## Report Template

The template differs by archetype. Read `references/report-template.md` when you reach the report-writing step. Pick the matching template based on the archetype determined in Setup.

Section orders and definitions live in `references/report-template.md`. The three templates share five concepts: a one-line Lead, a context section (Background or Why Now or Question to Answer), a scope-or-knowledge section, an unknowns section, and a Where To Look section.

## Adaptation Rules

These rules adjust section emphasis without changing the section list.

- **Found at Level 1 (Teams):** the context section leads with the Teams source and links the thread. Other context sections may be 1 line.
- **Found at Level 2 (design doc or product brief):** the context section leads with the doc URL and quotes the most relevant sentence. Same brevity allowed elsewhere.
- **Required Level 3 (code):** the Where To Look section includes code references as `path/to/file.ext` (no line numbers; this is orientation, not pinpointing). When the existing pattern is the finding, name the file in the context section.
- **Vague work item (almost no signal):** the Open Questions / Open Blockers section grows to name what the developer would need from the reporter or product owner before starting. Do not pad with prescriptive suggestions; only name genuine unknowns.

## Writing Rules

These apply to all text in the report.

- No em dashes or spaced hyphens as separators. Em dashes inside parenthetical asides are fine.
- No LLM vocabulary: delve, leverage, robust, seamlessly, comprehensive, nuanced, elevate, foster, paradigm, ecosystem, holistic, innovative, synergy, empower, facilitate.
- Lead with the answer. No opener phrases.
- No trailing summaries on short sections.
- Prose over bullet lists when the content flows naturally as sentences.
- Never present unverified scope as confirmed acceptance criteria.
- Quote design docs and product briefs directly (single sentence) when paraphrasing risks losing meaning.
