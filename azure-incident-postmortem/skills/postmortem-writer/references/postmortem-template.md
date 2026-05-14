# Postmortem Template (Google-SRE-style, blameless)

Read this when generating a postmortem in Step 3. The template defines every section's heading (verbatim), what belongs in it, when to emit a placeholder, and the per-section writing rules.

The template is **blameless**: it focuses on the system, not the people. Name actors when they took an action; never frame an action as fault. The point of the postmortem is to learn what to change about the system so the same incident does not happen again.

## Section Catalog

The catalog below is the full ordered list. Every postmortem includes every section; sections with no source data collapse into a one-line placeholder rather than disappearing. The skill emits sections in this exact order.

### Section 1: Header

The YAML-style block at the very top of the document. See the skill's Step 2 for the exact fields.

Status is always `Draft` when the skill emits the document; the user changes it to `Approved` or `Reviewed` after stakeholder review.

### Section 2: Summary

One to three sentences. The anchor of the document; a reader who reads only this section should know what happened, who was affected, and roughly why it matters.

Lead with what users experienced, not what the system did. "Property managers could not process rent payments for 96 minutes" comes before "the payments-api service threw connection-refused errors."

When the timeline grounds it, name the start time and duration in the Summary itself: "Payment processing was unavailable for US-region property managers from 14:32 UTC to 16:08 UTC (96 minutes)."

### Section 3: Impact

Four bulleted sub-points. Each is one line where the data exists; collapse to "[UNKNOWN]" when the source materials don't support it.

```
- **Customers affected:** {count or scope, e.g., "all US-region property managers — approximately 12,000 active accounts"}
- **Duration:** {start} to {end} UTC ({duration})
- **Symptoms:** {what users experienced, e.g., "payment processing returned 502 errors; the rent-pay flow was completely unavailable"}
- **Business impact:** {revenue, SLA, regulatory if relevant — be specific or write "[UNKNOWN]"}
```

When `customer_impact_summary` was passed in the payload, prefer its phrasing. When it was missing, synthesize from the timeline's earliest user-visible event and tag the Customers-affected line `[INFERRED]`.

### Section 4: Timeline (UTC)

Drop in the cached `timeline_markdown` from the payload verbatim. Add a one-line preamble: "All timestamps in UTC. Source links in the right column."

When `config.include_timeline_evidence_links` is `false`, drop the Source column.

### Section 5: Root Cause

Plain prose, evidence-tagged. Two to four sentences typically; longer when the cause has multiple steps that need to be named.

Every claim carries `[VERIFIED]`, `[OBSERVED]`, `[INFERRED]`, or `[UNKNOWN]` inline. The Root Cause section is reserved for `[VERIFIED]` causes — anything else belongs in Contributing Factors.

When the cause is still being verified (the team has a working hypothesis but no confirming evidence yet), write a one-line placeholder ("Root cause is still being verified at the time of this draft. See Contributing Factors for the leading hypothesis.") and put the analysis under Contributing Factors.

Example of well-formed Root Cause prose:

> A 14:00 UTC deploy to the auth-service shipped a token-rotation change (PR !4567) that did not pre-warm token caches `[VERIFIED]` (commit history). The first wave of post-deploy requests hit cold caches and timed out at the auth call, which cascaded to the payment service through its synchronous auth dependency `[VERIFIED]` (Datadog logs at `service:payments-api status:error` for the 14:32 to 14:42 window confirm the pattern; 47 connection-refused errors in 60 seconds). The cascade resolved when @bob reverted PR !4567 at 14:48 UTC `[VERIFIED]` (PR !4568).

### Section 6: Contributing Factors

A bulleted list of secondary causes — things that made the incident worse, made it harder to detect, or made the cause more likely to manifest in the first place. Every bullet is one observation, evidence-tagged.

Examples:
- **No automated rollback on deploy failure** `[VERIFIED]` — the auth-service deploy pipeline does not include a post-deploy health check that would trigger automatic rollback. The 14:48 revert was a manual action.
- **Synchronous auth dependency in the payment path** `[OBSERVED]` — the payment service blocks on the auth call rather than degrading gracefully when auth is slow or unavailable. This turned a single-service failure into a multi-service outage.
- **Token-cache pre-warming was deprecated in PR !3204** `[INFERRED]` — the original token-cache warming logic was removed three weeks before the incident as part of a refactor. The connection between that refactor and this incident is plausible but not proven; verifying requires reading the refactor's review thread.

When no contributing factors are surfaced from the source materials, write a one-line placeholder: "No additional contributing factors were identified during the response. Worth revisiting after the action items are addressed."

### Section 7: Detection

Two to four sentences. How was the incident detected, by whom, and how long after it started?

Pull the first detection event from the timeline (typically a PagerDuty alert, a customer report in #incident-payments, or a Datadog monitor firing). State the detection method, the actor, and the time-to-detect.

Example:

> Detection at 14:35 UTC, three minutes after the cause manifested. PagerDuty fired against the `payments-api` SLO alert (95th-percentile latency exceeded 5 seconds). @alice acknowledged the page within 30 seconds and posted to `#incident-payments`.

When the source materials don't ground a detection event, write: "Detection method not gathered. The incident response thread starts at {timestamp of first Teams message in the timeline}, which suggests the team became aware around that time."

### Section 8: Resolution

Two to four sentences. What stopped the bleeding, who did it, when?

Pull the resolution event from the timeline. Name the action, the actor, and the time. State whether the action was a permanent fix or a temporary mitigation that needs follow-up.

Example:

> Resolution at 14:48 UTC, 16 minutes after detection. @bob merged PR !4568 reverting PR !4567. The token-rotation change is reverted to the pre-14:00 implementation; a permanent fix that ships the rotation safely (with cache pre-warming) is tracked in the Action Items section below.

### Section 9: What Went Well

A bulleted list. Each bullet is one observation about the response that worked. Keep these specific (not "we communicated well" but "the #incident-payments channel had every response action posted in real time within 30 seconds").

Three to five bullets is typical. Fewer when the incident was painful; more is suspicious (the document should be honest, not aspirational).

### Section 10: What Went Wrong

A bulleted list. Each bullet is one observation about the response that didn't work. Same specificity rule as What Went Well.

This section feeds the Action Items section: every "What Went Wrong" item should have at least one corresponding action item that addresses it.

### Section 11: Action Items

A markdown table. The skill emits an empty table with the column headers and a placeholder row asking the user to fill it in:

```
| Item | Owner | Target | Severity |
|------|-------|--------|----------|
| (Fill in after team review. Each "What Went Wrong" item should have at least one corresponding action.) | | | |
```

When the source materials surfaced action items explicitly (e.g., a Teams message saying "we need to add post-deploy health checks before next sprint"), populate the table with those rows pre-filled, leaving Owner and Target blank for the user to assign.

When `config.include_action_items` is `false`, omit this section's heading entirely.

### Section 12: Lessons Learned

Plain prose, three to six sentences. The synthesis: what this incident teaches the team about the system. Not a recap of Root Cause; not a list of action items. The lesson.

Example:

> The token-rotation refactor that landed three weeks ago removed cache pre-warming as part of a "simpler is better" cleanup. The cleanup was correct in isolation, but the system depended on the warming behavior in a way that was not documented. This incident is the third in 18 months where a refactor removed an undocumented load-bearing behavior. The pattern is worth naming: when a refactor removes a path, the test suite needs to assert the path's absence is safe under realistic load, not just functionally correct in unit tests.

### Section 13: References

A bulleted list of every external URL that grounds the document:

- **Incident work item:** {AzDO URL}
- **Response thread:** {Teams URL, when gathered}
- **Datadog dashboards:** {URL list, when gathered and not empty}
- **Related deploys:** {PR URLs from the timeline}
- **Related work items:** {AzDO URLs of related items surfaced during gathering}

Skip a sub-bullet entirely when no URL applies (e.g., when Teams gathering came back empty, omit the "Response thread" line rather than writing "[UNKNOWN]").

## Section Order

Sections appear in the order shown above (1-13). The skill emits this order regardless of which sections are sparse; section order is part of the document's contract with readers.

## Severity Mapping

When `incident.severity` is in the input payload, render it verbatim in the header. The Google-SRE convention uses Sev-1 / Sev-2 / Sev-3; AzDO's built-in severity field uses `1 - Critical` / `2 - High` / `3 - Medium` / `4 - Low`. The skill keeps whatever shape the payload uses.

When severity is missing from the payload, write `[UNKNOWN]` in the header and add a one-line prompt at the end of the Header block: "Severity not captured during the response. Recommend updating the work item before this postmortem is reviewed."

## Blameless Phrasing

The template is blameless. The skill's Step-3 generation must use phrasing that names actions, not actors-as-causes:

| Avoid | Use |
|-------|-----|
| "@alice's deploy broke the auth service" | "The 14:00 deploy (PR !4567) introduced the regression in the auth service" |
| "The on-call missed the alert for 12 minutes" | "Detection happened 12 minutes after the cause manifested; the SLO alert took {N} minutes to fire from the underlying signal" |
| "@bob caused a second outage when reverting" | "The revert at 14:48 caused a second blip; PR !4568 included a stale config that resurfaced briefly until the next deploy at 15:02" |

Names appear when they describe an action ("@bob reverted PR !4567 at 14:48"). Names do not appear in cause-attribution sentences.
