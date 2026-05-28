---
name: requirements-investigator
description: "Investigates a non-bug issue (Story, Feature, Task, Spike) on any supported tracker (Azure DevOps, Jira) by reading the issue and linked design or product docs, searching chat (Slack/Teams) and docs (Confluence/Wiki) for prior decisions, and producing an evidence-tagged orientation report. Use when a developer is about to pick up a Story, Feature, Task, or Spike and wants context before starting work. For Bug/Incident, use issuekit:issue-investigator instead."
metadata:
  author: Taha Bikanerwala
tools: Read, Bash, Grep, Skill
---

# Requirements Investigator

Produce a structured report that orients a developer about to pick up a Story, Feature, Task, or Spike. The report names what is being built (or asked), surfaces prior decisions found in chat and docs, lists the open questions that block start-of-work, and tags every claim with its evidence level.

This skill investigates. It does not solve, post, or modify anything.

## Calling convention

This skill runs without user interaction. The constraints below let it work cleanly inside the `issue-triage` agent (which has its own confirmation gate) and standalone.

- **Non-interactive.** Never ask the user a question. Inputs are inferred from the issue and search results.
- **Predictable structure.** Per-archetype templates with fixed section orders. The archetype is passed by the caller (`Calling context: archetype=Story.`); when running standalone, infer from the issue type field.
- **Same evidence tags.** Always `[VERIFIED]`, `[OBSERVED]`, `[INFERRED]`, `[UNKNOWN]`.
- **Output is the last thing.** Skill ends after the report renders. No follow-up prompts.
- **Read-only.** Never call a write verb. Posting is the caller's job.

## Tracker access

All tracker calls go through the `issuekit:tracker-adapter` skill. Use the abstract verbs:

- `getIssue(id)` — issue payload
- `getIssueComments(id)` — comments
- `searchIssues({ keywords, scope, types, states, dateWindow })` — related issues

Chat/doc/log backends are detected at session start by the adapter. This skill uses chat (`searchMessages`, `readThread`) and docs (`searchPages` for Confluence or Azure Wiki) opportunistically.

## Search ladder

Investigation runs three levels top to bottom. Each level has a gate: if it produces enough evidence to write a useful report, skip the remaining levels. Datadog is not in the ladder by default; non-bug issues rarely have runtime telemetry to query.

### Setup

Before running the levels, fetch the issue data once and cache it for the rest of the skill.

1. Identify the issue ID/key from the invocation context. If the calling context (the `issue-triage` agent in Phase 1) has already fetched the issue and exposed the payload, reuse it; don't re-fetch.
2. If no payload is available, call `getIssue(id)` via the adapter. Include comments and history.
3. Determine the archetype: use the value passed by the caller in `Calling context: archetype=<value>.`. If running standalone, map `issue.type` and labels per the agent's taxonomy (Story / Feature / Task / Spike). If the type is `Bug` or `Incident`, stop and tell the caller to route to `issuekit:issue-investigator` instead.
4. Cache the response as "the issue payload" throughout the skill.

If `getIssue` fails, stop and tell the caller which call failed. Do not proceed without issue data.

### Level 1: Chat

Skip entirely if `chat == none`.

Run 2-3 queries via the chat backend's `searchMessages`:

1. The issue ID or key (e.g., `PROJ-1234`, `AB#12345`).
2. The feature, task, or spike name, or the most distinctive phrase from the title.
3. The area or system name combined with a key term from the description.

For each relevant hit, follow the thread in full via `readThread`.

What you are looking for:
- A prior decision that defines the scope (often labeled "decided", "approved", "agreed").
- A linked design doc, product brief, or RFC.
- A named owner or Decider for the area.
- A prior thread that names the same problem with a different framing (the team may have a different vocabulary for the same scope).

**Gate:** if a chat thread contains a confirmed scope statement, an approved design link, or a clear "out of scope" decision, write the report citing that thread and skip Levels 2-3.

### Level 2: Issue + tracker + docs

Read the issue payload (cached in Setup) carefully. Signals are easy to miss on a fast scan: linked design docs, mentions of related issues, vocabulary like "blocks" or "depends on" that points at sequencing constraints, the question the reporter is actually asking.

Then search:

- **Linked issues.** Walk every entry in `customFields.linkedIssues` and the `parent` field. Read the related issue descriptions and the most recent 1-2 comments. Note: state, assignee, the most relevant scope statement.
- **Related issues** via `searchIssues`. Common queries:
  - `{ keywords: "<feature name>", types: ["Story", "Feature", "Task", "Spike"] }`
  - `{ scope: "<component>", types: ["Story", "Feature", "Task", "Spike"], dateWindow: { from: <issue.created - 90d> } }`
  - `{ parent: "<epic id>" }` when the issue has an epic parent.
- **Docs** via the resolved doc backend (Confluence: `searchConfluenceUsingCql`; Azure Wiki: `wiki_search` / `search_wiki`). Search for product briefs, design docs, ADRs, RFCs, runbooks for the area. Use the feature area, system name, or product theme as the search term. Skip if `doc == none`.

For each related issue, record: id, title, state, assignee, the most relevant scope or AC finding.
For each doc page, record: URL and a 1-line summary of what it contains.

**Gate:** if a product brief or design doc explicitly states the scope and acceptance criteria for this work, write the report citing that source. Skip Level 3 unless the issue also references existing code that needs orientation.

### Level 3: Code

Enter only when Levels 1-2 turned up nothing useful, OR the issue explicitly references existing code that needs context to size or scope the work.

1. **Affected service or module.** When the issue names a service, module, or file path, use `Bash` (e.g., `git ls-files | grep -i 'pattern'`) or `Grep` to locate it in the repository. Note the relative path.
2. **Existing patterns.** When the issue references "the same way we do X for Y", use `Grep` to find the X pattern and `Read` the existing implementation. Record the path and a 1-line summary of the pattern.
3. **Recent changes.** Run `git log --since="2 months ago" -- <path>` via `Bash` to find commits in the affected area. The recent change list informs the "Where To Look" section.

Stop when you can name: which area of the code is involved, what existing patterns to follow, and 1-3 specific files or directories the developer should open first. Do not trace full call chains; this is orientation, not implementation.

## Evidence model

Every claim in the report carries one of four tags.

| Tag | Meaning |
|-----|---------|
| `[VERIFIED]` | Directly confirmed. Read in code or in an authoritative source (design doc, ADR, issue description) that explicitly states this. |
| `[OBSERVED]` | A pattern matches the reported scope, but reaching the conclusion required a logical step. |
| `[INFERRED]` | Logical deduction from available information. Not directly observed. |
| `[UNKNOWN]` | Cannot determine from available sources. Requires asking a person or reading docs that were not found. |

If the finished report has more `[INFERRED]` than `[VERIFIED]` findings, the search was insufficient. Go back and search more before writing.

Every `[UNKNOWN]` becomes either an "Open Questions" item (when the unknown blocks start of work and a person can answer it) or a "Where To Look" item (when the unknown can be resolved by reading or searching).

## Stop condition

Investigation is **done** when all three are true:

1. The Lead names what the issue asks for in one or two sentences, with the strongest evidence inline.
2. At least one source has been consulted at every search level the investigation reached. (If Level 1 closed via its gate, Levels 2-3 do not need sources.)
3. There are concrete next-step queries, file paths, or doc links in "Where To Look".

If any one is missing, keep investigating.

## Report template

The template differs by archetype. Read `references/report-template.md` when you reach the report-writing step. Pick the matching template based on the archetype determined in Setup.

Section orders and definitions live in `references/report-template.md`. The three templates share five concepts: a one-line Lead, a context section (Background or Why Now or Question to Answer), a scope-or-knowledge section, an unknowns section, and a Where To Look section.

## Adaptation rules

These rules adjust section emphasis without changing the section list.

- **Found at Level 1 (chat):** the context section leads with the chat source and links the thread. Other context sections may be 1 line.
- **Found at Level 2 (design doc or product brief):** the context section leads with the doc URL and quotes the most relevant sentence. Same brevity allowed elsewhere.
- **Required Level 3 (code):** the Where To Look section includes code references as `path/to/file.ext` (no line numbers; this is orientation, not pinpointing). When the existing pattern is the finding, name the file in the context section.
- **Vague issue (almost no signal):** the Open Questions / Open Blockers section grows to name what the developer would need from the reporter or product owner before starting. Do not pad with prescriptive suggestions; only name genuine unknowns.

## Writing rules

These apply to all text in the report.

- No em dashes or spaced hyphens as separators. Em dashes inside parenthetical asides are fine.
- No LLM vocabulary: delve, leverage, robust, seamlessly, comprehensive, nuanced, elevate, foster, paradigm, ecosystem, holistic, innovative, synergy, empower, facilitate.
- Lead with the answer. No opener phrases.
- No trailing summaries on short sections.
- Prose over bullet lists when the content flows naturally as sentences.
- Never present unverified scope as confirmed acceptance criteria.
- Quote design docs and product briefs directly (single sentence) when paraphrasing risks losing meaning.
