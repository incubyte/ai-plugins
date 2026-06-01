# Refined Issue Description Template

Read this when you reach Step 5 (Apply the Template). The template is a menu, not a form. Pick the sections the archetype calls for. Skip the rest. Never include an empty header.

Write each section as readable prose where the prose flows naturally. Use a list or table only when the data really is list- or table-shaped.

## Archetype-to-sections map

The first column lists every section the template defines. The next six columns indicate whether each section appears for a given archetype.

| Section | Bug | Incident | Story | Feature | Task | Spike |
|---------|:---:|:--------:|:-----:|:-------:|:----:|:-----:|
| Summary | always | always | always | always | always | always |
| Context and Background | if present | if present | always | always | always | always |
| Impact | if present | always | if present | if present | skip | skip |
| Affected Scope | if present | always | if present | if present | skip | skip |
| Reproduction, Expected, Actual | always | if present | skip | skip | skip | skip |
| Requirements and Acceptance Criteria | skip | skip | always | always | always | skip |
| Questions to Answer | skip | skip | skip | skip | skip | always |
| Findings | skip | skip | skip | skip | skip | if present |
| Investigation Notes | if present | if present | skip | skip | skip | if present |
| Working Hypotheses | if present | if present | skip | skip | skip | skip |
| Root Cause | if present | if present | skip | skip | skip | skip |
| Workaround | if present | if present | skip | skip | skip | skip |
| Solutions | if present | if present | skip | skip | if present | skip |
| Open Blockers | if present | if present | if present | if present | if present | skip |
| Original Metadata | last resort | last resort | last resort | last resort | last resort | last resort |

**Key:** `always` includes regardless of content; `if present` includes only when the original issue has relevant material; `skip` never includes; `last resort` includes only when truly unclassifiable content has no other home.

---

## Section definitions

Each section below shows the heading, a one-paragraph description of what belongs there, and (where useful) a small structural template. The actual headings in the refined description should match exactly.

### Summary

One to three sentences. The anchor of the issue. A reader who only reads this section should know what the issue is about and roughly why it matters.

- **Bug:** lead with the symptom and who is affected. `Visitor notifications stop sending for scheduled visits at MapleTower properties starting 2026-04-29.` Do not lead with a proposed cause.
- **Incident:** lead with what is broken and the blast radius. `Payment processing is failing for all US-region properties since 14:32 UTC. Customers cannot pay rent or fees.`
- **Story:** lead with the user need or business goal. `Property managers need a bulk-invite flow so they can onboard residents in batches during move-in events.`
- **Feature:** lead with the strategic intent. `Build a unified onboarding suite that consolidates bulk invites, lease imports, and welcome emails into one flow.`
- **Task:** lead with what needs to happen and the why-now. `Migrate the Jest configuration from v28 to v30 so the upgrade unblocks the testing-library v15 bump scheduled for next quarter.`
- **Spike:** lead with the question or uncertainty. `Determine whether AWS Cognito or Auth0 better fits multi-tenant SAML requirements before the Q3 SSO project starts.`

### Context and Background

Why this issue exists. Prior decisions, related history, links to product briefs, design docs, runbooks, related issues, or chat threads. Especially important on Stories/Features (link the brief and design doc) and Tasks (explain why-now). Skip this section when the Summary is already self-sufficient.

### Impact

Who is affected and how badly. Placed immediately after Summary because it controls how a triager prioritizes the issue.

- **Incident:** number of affected users or tenants, business impact (revenue, SLA, regulatory), timeline (when it started, when detected, current duration).
- **Bug:** user-facing consequences, scope of affected population, business or workflow implications.
- **Story / Feature:** the business or user impact of doing the work, plus the cost of not doing it.

### Affected Scope

Who or what is affected and how broadly. One to three items as prose; four or more as a table.

Prose example:

> Affects all Bread Financial members whose cohort has `offshore_support_enabled` set to `false`. Roughly 12,000 active accounts as of 2026-04-29.

Table example (four or more parties):

| Affected party | What they experience | Identifiers |
|----------------|----------------------|-------------|
| MapleTower residents | No visitor notifications | `tenant_id: mt-01`, `region: us-east-1` |
| ParkPlace residents | No visitor notifications | `tenant_id: pp-04`, `region: us-east-1` |

### Reproduction, Expected, Actual

Bug-only (and Incident when reproducible). Three top-level sections that always travel together. Use these exact headings, in this order, with no shared parent heading above them:

```
## Reproduction Steps
1. Step 1
2. Step 2
3. Step 3

## Expected Behavior
What should happen.

## Actual Behavior
What does happen. Include the exact error message verbatim, in a fenced code block when it has formatting.
```

The Section Order list below treats the trio as a single slot (position 5) because they only make sense as a unit, not because they share a parent heading.

When the bug is not reproducible on demand, replace the steps with: `Not reproducible on demand. The reporter saw it once at {timestamp}; subsequent attempts at {follow-up timestamps} did not reproduce.`

### Requirements and Acceptance Criteria

Stories, Features, and Tasks. Each criterion testable. For Tasks, frame as definition of done.

```
1. Bulk invite endpoint accepts up to 500 emails per request.
2. Returns 207 Multi-Status with per-email success or failure when any subset fails.
3. Audit log records the inviting user and timestamp.
4. Rate limit of 10 requests per minute per property.
```

### Questions to Answer

Spike-only. Each question must produce a definitive answer. Vague questions ("Is X better?") are split into specific ones ("Does X support feature Y under conditions Z?").

```
1. Does AWS Cognito support SAML federation for more than 100 identity providers?
2. What is the per-tenant configuration overhead for Cognito vs Auth0?
3. Does either provider expose a usable audit log for compliance reporting?
```

### Findings

Spike-only. Answers map one-to-one to the questions above, each with supporting evidence. Skip if the spike has not started.

### Investigation Notes

Artifacts from completed investigation. Include only when there is something concrete to record. Future investigation steps belong in a next-steps comment, not here.

The outer fence below uses four backticks so the inner code block (the captured stack trace) can stay as a plain three-backtick fence with no escaping. When you copy this into a refined issue, drop the outer fence entirely; it exists here only because the example wraps a sample section in this template document.

````
**Observability**
- [Datadog: 500s on /payments endpoint, 14:00 to 16:00 UTC](https://app.datadoghq.com/logs?query=...)

**Errors**

```
Stripe::APIConnectionError: Connection refused (errno: ECONNREFUSED)
  at lib/stripe/client.rb:88
```

**Relevant IDs**
- Tenant: `mt-01`
- Customer: `cus_O12abc34`
- Failing payment intent: `pi_3OabcDEF456`
````

### Working Hypotheses

Unverified analysis. Plain prose, no disclaimer block, no warning panel. Frame each hypothesis as the most likely cause based on available evidence, name the evidence, and name the runtime check that would confirm or rule it out.

> The most likely cause based on the timeline is the auth-token rotation that landed in the 14:00 deploy. The rotation logic does not pre-warm token caches, so the first wave of requests after deploy hits a token-fetch path that has not been load-tested. Confirming this requires a Datadog query against `service:auth status:error` for the 14:00 to 14:15 window.

Skip when there are no hypotheses or when the cause is verified (in which case use Root Cause).

### Root Cause

The cause is verified with evidence. Plain prose. Cite the evidence. If the cause is still being verified, use Working Hypotheses instead. Bugs and Incidents only.

### Workaround

Steps an affected user can take right now to mitigate. If there is no workaround, write `None.` Do not omit this section for an open Bug or Incident with a confirmed Root Cause; an empty workaround answer is itself useful information.

### Solutions

The permanent fix or resolution path. For resolved issues, what was done. For open issues, what a complete fix would look like, when known. Bugs, Tasks, and Incidents.

### Open Blockers

External parties or cross-team coordination required to close the issue. One to two as prose; three or more as a table.

| Blocker | Owner | Status |
|---------|-------|--------|
| Awaiting security review | Security team | Pending |
| Need new IAM role created | Platform team | In progress |

### Original Metadata

Last resort. Use only when the source issue carries genuinely unclassifiable content that has no home elsewhere (e.g., a scratch field from an intake form that does not map to any other section). Most refinements omit this section entirely. Source-system blocks (third-party support tools, escalation forms, vendor exports) get their facts extracted into the appropriate sections above; the raw block does not survive.

---

## Section order

When multiple sections appear, order them like this. Skipped sections close the gap.

1. Summary
2. Impact
3. Context and Background
4. Affected Scope
5. Reproduction, Expected, Actual
6. Requirements and Acceptance Criteria
7. Questions to Answer
8. Findings
9. Investigation Notes
10. Working Hypotheses
11. Root Cause
12. Workaround
13. Solutions
14. Open Blockers
15. Original Metadata

The first three positions stay rigid (Summary, Impact, Context) so a reader skimming the top of the issue sees what, who, and why in that order. Below that, the order matches investigation flow: scope, reproduction, requirements, then evidence and analysis, then resolution, then blockers.
