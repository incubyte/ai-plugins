---
name: incident-timeline-builder
description: "Reconstructs a chronological event timeline for an Azure DevOps incident from gathered evidence: Microsoft Teams thread snippets, AzDO work-item revisions, Datadog log entries, and Azure Repos pull-request merges. Each timeline entry carries a UTC timestamp, a one-sentence description, a source citation, and an evidence tag. Use when the azure-incident-postmortem agent reaches Phase 2, or when a developer wants to manually reconstruct what happened during an incident from a known set of source materials."
metadata:
  author: Taha Bikanerwala
tools: Read
---

# Incident Timeline Builder

Take a bundle of evidence collected during an incident's investigation phase and produce a chronological timeline that a postmortem can be built on. Every event in the timeline carries a UTC timestamp, a short description, a source citation, and an evidence tag. Events without a verifiable timestamp are flagged `[UNKNOWN]` rather than guessed.

This skill investigates nothing on its own. The caller (the `azure-incident-postmortem` agent in Phase 2, or a user invoking the skill directly) hands the skill a structured payload of pre-gathered evidence; the skill organizes it.

## Calling Convention

The skill runs without user interaction. It produces a single chronological timeline as its only output.

- **Non-interactive.** Never ask the user a question. Inputs are inferred from the payload the caller provides.
- **Predictable structure.** The output is always a markdown table with the columns shown in the "Output Format" section below, ordered ascending by timestamp.
- **Same evidence tags as the rest of the marketplace.** `[VERIFIED]`, `[OBSERVED]`, `[INFERRED]`, `[UNKNOWN]`.
- **Read-only.** No `wit_update_work_item`, no `teams_send_message`, no file writes. Posting and saving are the caller's job.
- **Output is the last thing.** Skill ends after the timeline renders. No follow-up prompts.

## Input Payload Shape

The caller passes a JSON-or-prose payload describing the incident and four pools of evidence:

```
{
  "incident": {
    "id": "12345",
    "url": "https://dev.azure.com/<org>/<project>/_workitems/edit/12345",
    "title": "Payment processing outage for US properties",
    "created_at": "2026-04-29T14:32:00Z",
    "resolved_at": "2026-04-29T16:08:00Z",
    "severity": "1 - Critical"
  },
  "teams_messages": [
    { "timestamp": "...", "author": "...", "channel": "...", "message_url": "...", "text": "..." }
  ],
  "azdo_work_items": [
    { "id": 12348, "url": "...", "title": "...", "state_change": "Active -> Resolved", "changed_at": "...", "changed_by": "..." }
  ],
  "datadog_logs": [
    { "timestamp": "...", "service": "...", "level": "error", "message": "...", "logs_url": "..." }
  ],
  "azure_repos_prs": [
    { "id": 999, "url": "...", "title": "...", "merged_at": "...", "merged_by": "...", "repo": "..." }
  ]
}
```

Any of `teams_messages`, `azdo_work_items`, `datadog_logs`, or `azure_repos_prs` may be empty (the corresponding source was not gathered or returned no results). The skill produces a timeline from whichever pools are populated and notes the empty pools in a brief preamble before the table.

## Workflow

The skill runs five ordered steps.

### Step 1: Validate the incident window

Compute the incident time window: from `incident.created_at` to `incident.resolved_at` (or `now()` when the incident is unresolved). This is the in-scope window. Events outside the window should still appear in the timeline if the caller passed them in (the caller has already filtered for relevance), but flag them with `(out-of-window)` in the description so the postmortem author can decide whether to keep them.

If `incident.created_at` is missing or unparseable, halt and tell the caller. The skill cannot order events without a baseline.

### Step 2: Normalize timestamps

Convert every event's timestamp to UTC ISO-8601 form (`YYYY-MM-DDTHH:MM:SSZ`). Tolerate input variations: epoch milliseconds, AzDO's `2026-04-29T14:32:18.123Z` form, Datadog's `2026-04-29T14:32:18.123456Z`, Teams' `2026-04-29T14:32:18.000+00:00`. When a timestamp is ambiguous (e.g., a Datadog log with millisecond precision but no timezone marker — defaults to UTC by the MCP), keep the event but tag it `[OBSERVED]` instead of `[VERIFIED]` because the timestamp's precision matters for the postmortem.

Events with no timestamp at all (sometimes the case for Teams messages or work-item comments where the MCP didn't return one) get the placeholder `?? UTC` in the Time column and an `[UNKNOWN]` tag. They sort to the end of the timeline (after the last verified event) so they don't disrupt the chronological reading.

### Step 3: Build the event entries

For each evidence item across the four pools, build one timeline entry. Use the rules below per source.

**Teams messages.** Description: lead with the author and one-sentence paraphrase of the message. Source citation: the Teams message URL. Evidence tag: `[VERIFIED]` if the message is from a known incident response thread (the caller filtered for this); `[OBSERVED]` otherwise.

> Example: `14:35 UTC | @alice "PagerDuty alert just fired for the payments service" | [Teams thread](teams://...) | [VERIFIED]`

**AzDO work-item changes.** Description: the state transition (e.g., `New -> Active`, `Active -> Resolved`) plus the actor. Source citation: the work-item URL with a `?revisedDate=...` fragment when known. Evidence tag: `[VERIFIED]` (state changes are first-class data on AzDO work items).

> Example: `15:02 UTC | WI #12345 transitioned New -> Active by @bob | [WI #12345](...) | [VERIFIED]`

**Datadog log entries.** Description: the log level, the service, and a truncated message (max 100 characters; truncate with `…` mid-string when needed). Source citation: the Datadog logs URL filtered to the timestamp. Evidence tag: `[VERIFIED]` when the message includes a stack trace or specific error string; `[OBSERVED]` for plain INFO/WARN entries that match a pattern.

> Example: `14:32 UTC | ERROR `payments`: Stripe::APIConnectionError "Connection refused (errno: ECONNREFUSED)" | [Datadog](...) | [VERIFIED]`

**Azure Repos PR merges.** Description: lead with the PR title, the merger, and the repo. Source citation: the PR URL. Evidence tag: `[VERIFIED]` for the merge time itself; `[INFERRED]` when the entry represents a possible cause (the PR merged before the incident started and changed code in the failing path).

> Example: `13:58 UTC | PR !4567 "Refactor token rotation" merged by @alice into `auth-service` | [PR !4567](...) | [VERIFIED]`

### Step 4: Sort and dedupe

Sort the combined event list ascending by timestamp. Within the same timestamp (down to the second), sort by source priority: AzDO work-item state change > Azure Repos PR merge > Teams message > Datadog log. This ordering reflects "the team's record of what changed" first and "what was happening in the system" second.

Dedupe near-identical entries: when two Datadog log entries have the same service, level, and message-prefix within a 60-second window, collapse them into one entry with a count suffix (`(× 47 occurrences in the next 60 seconds)`). This prevents a noisy log channel from drowning out the real timeline.

### Step 5: Render the table

Output a markdown table with these exact columns (in this order):

| Time (UTC) | Event | Source | Tag |
|------------|-------|--------|-----|

Lead the output with a one-line preamble naming the in-scope window and any pools that came back empty:

> Timeline for incident `WI #12345` (`14:32 UTC` to `16:08 UTC`). Datadog returned no results; the timeline is built from Teams, AzDO, and Azure Repos only.

Append a one-line summary after the table when more than one event ran in parallel (same minute, different sources):

> Multiple sources captured events at `14:32 UTC`; the table preserves them in source-priority order.

When no evidence was passed in at all (every pool empty), output a single-row table with one row noting the empty input and the `[UNKNOWN]` tag, and a preamble explaining that the postmortem will need to be built from manual recall.

## Output Format

Always render as a single markdown table with the four columns shown above, no nesting, no extra structural elements, no JSON. The agent's Phase 4 (`postmortem-writer`) consumes the table directly into the postmortem's "Timeline (UTC)" section.

Examples of well-formed entries:

| Time (UTC) | Event | Source | Tag |
|------------|-------|--------|-----|
| 13:58 | PR !4567 "Refactor token rotation" merged by @alice into `auth-service` | [PR !4567](https://dev.azure.com/contoso/payments/_git/auth-service/pullrequest/4567) | [VERIFIED] |
| 14:32 | WI #12345 created by @oncall: "Payment processing outage for US properties" | [WI #12345](https://dev.azure.com/contoso/payments/_workitems/edit/12345) | [VERIFIED] |
| 14:32 | ERROR `payments-api`: Stripe::APIConnectionError "Connection refused (errno: ECONNREFUSED)" (× 47 occurrences in the next 60 seconds) | [Datadog](https://app.datadoghq.com/logs?query=service%3Apayments-api%20status%3Aerror&from_ts=...) | [VERIFIED] |
| 14:35 | @alice in `#incident-payments`: "PagerDuty alert just fired for the payments service" | [Teams thread](https://teams.microsoft.com/...) | [VERIFIED] |
| 14:42 | @bob in `#incident-payments`: "Reverting !4567 now" | [Teams thread](https://teams.microsoft.com/...) | [VERIFIED] |
| 14:48 | PR !4568 "Revert PR !4567" merged by @bob into `auth-service` | [PR !4568](https://dev.azure.com/contoso/payments/_git/auth-service/pullrequest/4568) | [VERIFIED] |
| 16:08 | WI #12345 transitioned Active -> Resolved by @bob | [WI #12345](https://dev.azure.com/contoso/payments/_workitems/edit/12345) | [VERIFIED] |

## Adaptation Rules

These adjust the output without changing the column layout.

- **Long incidents (more than 50 events):** the table is unwieldy. Truncate the output to the first 25 events and the last 10 events with a row in between reading `... (15 events omitted; see source links for full sequence) ...`. The truncated section preserves chronological order on both sides of the omission.
- **Sparse incidents (fewer than 5 events across all sources):** add a one-paragraph note after the table flagging that the timeline may be incomplete and suggesting which source pools could be re-gathered with broader queries.
- **Multi-day incidents:** events on different calendar dates use the form `YYYY-MM-DD HH:MM` instead of `HH:MM` so the day is unambiguous. Include a date-change row between days: `--- 2026-04-30 ---`.
- **Out-of-window events:** keep them in the table, sorted chronologically with the rest, but append `(out-of-window)` to the description.

## Writing Rules

These apply to all text the skill produces (descriptions and preamble lines).

- No em dashes or spaced hyphens as separators. Restructure.
- No LLM vocabulary: delve, leverage, robust, seamlessly, comprehensive, nuanced, elevate, foster, paradigm, ecosystem, holistic, innovative, synergy, empower, facilitate.
- Lead with the answer. No opener phrases.
- Quote source text directly when paraphrasing risks losing meaning. Use quotation marks; never inline-italicize a quote.
- Never present unverified analysis as a confirmed cause. The Tag column carries the certainty level; descriptions stay neutral on causation.
