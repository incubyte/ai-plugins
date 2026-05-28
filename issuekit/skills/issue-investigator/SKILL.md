---
name: issue-investigator
description: "Investigates a Bug or Incident on any supported tracker (Azure DevOps, Jira) by searching chat (Slack/Teams), the issue and related issues, docs (Confluence/Wiki), Datadog, and the codebase, then writes an evidence-tagged report in the bug-archetype template. Use when a Bug or Incident needs an investigation report before triage decisions are made. For Feature, User Story, Task, or Spike, use `requirements-investigator` (lives in the issue-triage plugin)."
metadata:
  author: Taha Bikanerwala
tools: Read, Bash, Grep, Skill, AskUserQuestion
---

# Issue Investigator

Produce a structured report that orients an engineer for a tracker Bug or Incident. The report names what is broken, ranks 2-3 hypotheses, lists concrete next-step queries, and tags every claim with its evidence level.

**Scope:** Bug and Incident archetypes only. For Feature, User Story, Task, or Spike, the calling agent uses `requirements-investigator` instead.

This skill investigates. It does not solve, post, or modify anything.

## Calling convention

This skill runs without user interaction. The constraints below let it work cleanly inside the `issue-triage` and `incident-postmortem` agents (which own their own confirmation gates) and standalone.

- **Non-interactive.** Never ask the user a question. Inputs are inferred from the issue and search results.
- **Predictable structure.** Same six section headers every run, in the same order, with one allowed reorder for production incidents (see Adaptation Rules).
- **Same evidence tags.** Always `[VERIFIED]`, `[OBSERVED]`, `[INFERRED]`, `[UNKNOWN]`.
- **Output is the last thing.** Skill ends after the report renders. No follow-up prompts.
- **Read-only.** Never call a write verb (`addComment`, `transition`, `updateFields`, etc.). Posting is the caller's job.

## Tracker access

All tracker calls go through the `issuekit:tracker-adapter` skill. Use the abstract verbs:

- `getIssue(id)` — issue payload, body in markdown
- `getIssueComments(id)` — comment thread
- `searchIssues({ keywords, scope, types, states, dateWindow })` — related issues
- `linkedPullRequests(id)` — PRs that reference this issue

Do not name vendor-specific MCP tools (`wit_get_work_item`, `getJiraIssue`, etc.) in the skill body. The adapter resolves them.

## Search Ladder

Investigation runs four levels top to bottom. Each level has a gate: if it produces enough evidence to write a useful report, skip the remaining levels.

### Setup

Before running the levels, fetch the issue once and cache it for the rest of the skill.

1. Identify the issue ID from the invocation context (e.g., `12345`, `PROJ-1234`, or extracted from a pasted URL). If the calling agent has already fetched the issue and exposed the payload, reuse that payload; do not re-fetch.
2. If no payload is available, call `getIssue(id)`. The returned `Issue` shape is normalized regardless of tracker.
3. Cache the response as "the issue payload" throughout the skill — reference `title`, `body`, `created`, `relations` (the `Issue.parent`, `Issue.customFields.linkedIssues` or similar), `reporter`, etc.

If `getIssue` fails, stop and tell the caller which call failed. Do not proceed without issue data.

### Level 1: Chat (Slack / Teams)

Skip this level entirely if `chat == none`. The detection result is set by the adapter at session start.

Run 2-3 queries via the chat backend's `searchMessages` (Slack: `slack_search_public_and_private`; Teams: `teams_search_messages`):

1. The issue ID or key (e.g., `12345`, `AB#12345`, `PROJ-1234`).
2. The most distinctive symptom or error message.
3. The customer or area name combined with a key term.

For each relevant hit, follow the thread in full via `readThread` (Slack: `slack_read_thread`; Teams: `teams_read_thread`).

What you are looking for:
- An engineer who already identified the root cause.
- A workaround that was shared.
- A specific service, config setting, or deploy named as the culprit.
- Links to relevant pull requests, commits, or related issues.

**Gate:** if a thread contains a confirmed root cause or workaround, write the report citing that thread and skip Levels 2-4.

### Level 2: Issue + tracker + docs

Read the issue payload (cached in Setup) carefully. Signals are easy to miss on a fast scan: error messages, timestamps, customer names, browser/device, the question the reporter is actually asking.

Then search:

- **Related issues** via `searchIssues`. Common queries:
  - `{ keywords: "<error string>", states: ["!Closed"], dateWindow: { from: <issue.created - 30d> } }`
  - `{ keywords: "<feature area>", states: ["!Closed"] }`
  - `{ scope: "<component or area>", types: ["Bug", "Incident"] }`
- **Linked issues.** Walk every entry in the issue's `customFields.linkedIssues` (or the equivalent `relations` array for AzDO, `issuelinks` for Jira — both surfaced via the adapter). Read the linked issue's title, state, and the most relevant scope statement.
- **Docs** via the resolved doc backend (Confluence: `searchConfluenceUsingCql`; Azure Wiki: `wiki_search` or `search_wiki`). Look for runbooks, architecture pages, known-issues pages, onboarding docs. Use the feature area, system name, or entity type as the search term. Skip if `doc == none`.

For each related issue, record: ID, title, state, assignee, the most relevant finding from description or comments.
For each doc page, record: URL and a 1-line summary.

**Gate:** if a runbook describes the exact scenario or a prior issue has the resolution, write the report pointing at that source. Skip Levels 3-4.

### Level 3: Datadog

Skip this level entirely if `log == none`.

Build queries from signals collected in Levels 1-2: error strings, service names, entity IDs, HTTP status codes.

Call `search_datadog_logs` with:
- `query`: e.g., `service:my-service status:error @http.status_code:500 @user_id:abc123`
- `from`: 7 days before the issue's `created` date, or the timeframe mentioned in the issue
- `to`: issue `created` date or now
- `limit`: 10-25

Build a Logs URL the engineer can click:
`https://app.datadoghq.com/logs?query=<url-encoded-query>&from_ts=<epoch_ms>&to_ts=<epoch_ms>`

**Suppression rule:** if Datadog returns any error (auth, 403/404, timeout, rate limit, empty results, or any non-success), treat Datadog as unavailable for this issue. Do not mention Datadog anywhere in the report. This rule overrides every other instruction that references Datadog data.

**Gate:** if Datadog returned usable results that identify a service, an error pattern, or a timeline gap, write the report incorporating those findings. Skip Level 4 unless an external source points specifically to a code-level cause.

### Level 4: Code

Enter only when Levels 1-3 turned up nothing useful, OR external sources point to a code-level cause that needs tracing.

1. **Error strings.** Use `Bash` (e.g., `grep -r 'pattern' path/`) or `Grep` to find error messages in the codebase. Identify which service owns the error.
2. **Endpoints or event handler names.** Search for route definitions or event handler names to confirm which service handles the affected flow.
3. **Observable signals.** Use `Read` to open source files near the relevant code; find logging and monitoring calls. For each call found, note the log message string and any structured tags so the "Where To Look" section can name them.
4. **Recent changes.** Run `git log --since="2 weeks ago" -- <path>` via `Bash` to find commits that correlate with the reported timeline.

Stop when you can name: which service is involved, what signals are observable, and 2-3 concrete observability queries. Do not trace full call chains unless the chain itself is the finding.

## Evidence Model

Every claim in the report carries one of four tags.

| Tag | Meaning |
|-----|---------|
| `[VERIFIED]` | Directly confirmed. Read in code, or a source explicitly states this. |
| `[OBSERVED]` | A pattern matches the reported behavior, but reaching the conclusion required a logical step. |
| `[INFERRED]` | Logical deduction from available information. Not directly observed. |
| `[UNKNOWN]` | Cannot determine from available sources. Requires runtime data. |

If the finished report has more `[INFERRED]` than `[VERIFIED]` findings, the search was insufficient. Go back and search more before writing.

Every `[UNKNOWN]` becomes a "Where To Look" item: name the runtime check that would resolve it.

## Stop Condition

Investigation is **done** when all three are true:

1. There are 2-3 ranked hypotheses, most-likely first. **Exception:** if the Level 1 or Level 2 gate fired with a confirmed root cause, a single hypothesis is sufficient.
2. At least one source has been consulted at every search level the investigation reached. (If a level was skipped because its backend was unavailable, that is not a source gap.)
3. There are concrete next-step queries or files in "Where To Look".

If any one is missing, keep investigating.

## Report Template

Every report has all six sections. If a section has nothing meaningful to say, write a 1-line note ("Not applicable for this issue") rather than skip the section.

### 1. Lead

1-2 sentences. Name what is broken and your single best hypothesis. Inline evidence tag. Do not restate the issue title.

Example:

> Sessions for tenant `MapleTower` started failing at the join step yesterday after deploy `2026-04-29T18:00Z`; the new SSO middleware is the most likely cause `[OBSERVED]`.

### 2. Scope & State

Who is affected (one user, a segment, or all). Whether investigation is complete or needs runtime verification. Stale-issue flag if the issue has been quiet for more than 2 weeks while the bug may already be fixed.

### 3. Domain Context

2-4 sentences. Define vendor names, internal acronyms, or product terminology a new team member would not know. Skip with "Not applicable" if the affected area is obvious from the title.

### 4. What Happened

2-4 sentences. Plain language. Include the exact error message and when the issue started if known.

### 5. What We Found

Narrative prose with evidence tags inline. Cover:

- Which service or component owns the behavior.
- 2-3 hypotheses ranked by likelihood, each with its evidence trail.
- Recent changes (deploys, PRs, config) that correlate with the timeline.
- Related prior issues and what they say.

No tables in this section. No code snippets unless the snippet itself is the finding (then keep it short).

### 6. Where To Look

2-5 tool-by-tool items. Each item:

- Names the tool (code search, chat search, admin URL, Sentry, Datadog, etc.). The list reflects tools the engineer should use after reading the report, not tools this skill itself queried.
- Gives the exact ready-to-paste query, URL, or file path.
- Says in one phrase what a hit or miss tells you.
- Datadog items appear here only if Datadog returned usable results during Level 3. The Level 3 suppression rule overrides this whenever Datadog was unavailable.

Example:

> - **Code search:** `grep -r 'SSO_TOKEN_EXPIRED' services/auth/` to find the error string in source. A hit identifies the service that owns the failure mode; a miss means the error originates outside the auth service.

## Adaptation Rules

These rules adjust section order or content emphasis. All six sections still appear every run.

- **Found at Level 1 (chat):** Section 5 leads with the chat source and links the thread. Sections 3, 4 may be 1 line each.
- **Found at Level 2 (runbook or prior issue):** Section 5 leads with the source. Same brevity allowed elsewhere.
- **Required Levels 3-4 (code/logs):** Section 5 includes code references inline as `path/to/file.ext:line`. No long code snippets unless the snippet is the finding.
- **Production incident (live impact):** Reorder. Put Section 6 ("Where To Look") immediately after Section 1 ("Lead"). Sections 2-5 follow. Engineers reading this need next actions before context.
- **Vague issue (almost no signal):** Section 5 describes what was searched and what is unknown. Section 6 ends with a single `Where To Look` item naming the specific information the reporter could provide, phrased as a concrete question for the owning team to use if they choose to contact the reporter. The skill itself never contacts the reporter.

## Writing Rules

These apply to all text in the report.

- No em dashes or spaced hyphens as separators. Em dashes inside parenthetical asides are fine.
- No LLM vocabulary: delve, leverage, robust, seamlessly, comprehensive, nuanced, elevate, foster, paradigm, ecosystem, holistic, innovative, synergy, empower, facilitate.
- Lead with the answer. No opener phrases.
- No trailing summaries on short sections.
- Prose over bullet lists when the content flows naturally as sentences.
- Never present unverified analysis as a confirmed root cause.

For deeper guidance, the calling agent may invoke `issuekit:prose-style` on the finished report.
