# Report Template

Read this when you reach the report-writing step in `azure-requirements-investigator`. Skip on earlier steps.

The report template differs by archetype. Pick the matching template based on the archetype passed by the caller (the agent in Phase 1) or inferred from the work-item-type when running standalone (User Story / Product Backlog Item / Requirement -> Feature; Task -> Task; Spike custom type or Task tagged `spike` -> Spike).

Each template has a fixed section list and order. Do not omit a section heading. If a section has nothing meaningful to say, write a one-line note under the heading ("Not applicable for this work item" or "Nothing prior found"). The absence is itself signal, and keeping the heading lets a reader scan for the section even when it is empty.

## Feature Template

Six sections. The agent routes User Story, Feature, and Epic work items into this template. A standalone invocation against any of those archetypes uses the same shape.

### 1. Lead

1-2 sentences. Name what is being built and the single best summary of scope. Inline evidence tag. Do not restate the work-item title.

Example:

> Add a per-tenant rate limit for the bulk-export endpoint, default 100 requests per hour, configurable per tenant `[VERIFIED]` from the product brief at WI #1234.

### 2. Background

2-4 sentences. Why this work item exists. Prior decisions, related history, links to product briefs, design docs, runbooks, related work items. Pull this from the AzDO Wiki and the linked work items discovered in Level 2.

When the background is established in a Wiki brief or ADR, lead with the URL and quote the single most relevant sentence. Do not paraphrase across multiple decisions; name them separately.

### 3. Requirements Found

Concrete acceptance criteria, definition of done, success metrics, target user stories. Pull from the work item itself (including the `Microsoft.VSTS.Common.AcceptanceCriteria` field if populated), linked work items, and any Wiki spec the work item points to.

Format as a bulleted list when there are 3 or more items. Each bullet starts with the requirement, followed by the source citation in brackets. Tag explicit gaps as `[UNKNOWN]`.

Example:

> - Bulk export rate limit defaults to 100 req/hour per tenant `[VERIFIED]` (WI #1234 description, paragraph 2).
> - Override via `bulk_export_rate_limit` config field, integer in requests/hour, no upper bound `[OBSERVED]` (WI #1234 comment from @alice 2026-04-15).
> - Rate limit error response shape unspecified `[UNKNOWN]`.

### 4. Design Refs

Links to Figma boards, design docs, mockup reviews, ADRs. One bullet per link with a one-phrase summary of what's at the link. If nothing is linked, write "None found in work item or comments." A Feature work item with no design refs is itself a triage flag, worth naming.

### 5. Open Questions

Genuine unknowns that need an answer before development starts. Each question is specific (not "what's the scope?"). Tag the most likely answerer if discoverable from the work-item history or the Teams search.

Example:

> - What error response shape should the rate limit return? Likely answerer: @bob (named in WI #1234 thread). `[UNKNOWN]`
> - Does the rate limit apply to admin-impersonated requests? `[UNKNOWN]`

### 6. Where To Look

2-5 tool-by-tool items. Each item:

- Names the tool (code search, AzDO Wiki search, Teams search, work-item ID, design tool).
- Gives the exact ready-to-paste query, URL, or file path.
- Says in one phrase what a hit or miss tells you.

Examples:

> - **Code search:** `rg 'rate_limit' services/bulk_export/` to find existing rate-limit infrastructure. A hit identifies the pattern to follow; a miss means this is greenfield in the bulk-export service.
> - **Teams search:** "bulk export" in the platform channel to find the design discussion that led to WI #1234. A hit gives the rationale behind the 100 req/hour default.
> - **AzDO Wiki:** search `Bulk Export ADR` (full text) to find the architecture decision record. The ADR is the canonical scope source.

## Task Template

Five sections.

### 1. Lead

1-2 sentences. Name what needs to happen and the why-now. Inline evidence tag.

Example:

> Bump `pg` driver from 8.x to 9.x across the `payments` and `billing` services to unblock Postgres 16 upgrade `[VERIFIED]` from WI #2345.

### 2. Why Now

2-3 sentences. The trigger for the task: dependency upgrade unblocks something downstream, deprecation deadline, related migration, runbook execution, security advisory.

Pull from the work item and recent Teams discussions. When a deadline or dependency is the trigger, name it specifically with date or work-item reference.

### 3. Definition of Done Found

Concrete completion criteria. Pull from the work item and any linked checklist or runbook. Tag explicit gaps as `[UNKNOWN]`.

Format as a bulleted list. Each bullet is a single completion check, not a process step.

### 4. Risks

Anything in the affected code, config, or runbook that makes this task non-trivial. One bullet per risk. Examples:

- Shared config touched by other teams.
- Dependency with a known breaking change between minor versions.
- Infrastructure resource with downstream consumers (database, queue, shared library).
- The task touches a runbook step that has no documented rollback.

If no risks are found, write "No specific risks surfaced from search; standard care expected."

### 5. Where To Look

Same format as Feature template Section 6.

## Spike Template

Five sections. The agent routes any Task tagged `spike` (or a custom Spike work-item type) into this template.

### 1. Lead

1-2 sentences. Name the question being investigated and the time-box if known. Inline evidence tag.

Example:

> Spike: evaluate whether Cognito can support more than 100 IdPs per user pool. Time-boxed at 3 days `[VERIFIED]` from WI #3456.

### 2. Question to Answer

The specific decision or unknown the spike is meant to resolve. Quote it directly from the work item if the work item states it well; rewrite if vague. Multiple sub-questions are allowed if they are all in scope.

Example:

> Primary question: Does Cognito support more than 100 IdPs per user pool today? `[VERIFIED]` from WI #3456.
> Sub-questions: What is the practical performance impact of >100 IdPs? What are the migration paths if the limit is hard?

### 3. What's Already Known

Findings from any prior spike, design doc, related work item, or Teams thread that bear on the question. Tag each with evidence level. If nothing is known, write "Nothing prior found." (which is itself a useful signal: the spike is starting from scratch).

### 4. What's Unknown

The gaps that the spike needs to fill. One bullet per gap. Each phrased as a concrete check (`Does Cognito support more than 100 IdPs?`) rather than a vague topic (`scalability`).

When the team has access to a vendor representative or a person with prior context, name them on the relevant unknown.

### 5. Where To Look

Same format as Feature template Section 6. For Spikes, "Where To Look" frequently includes external research (vendor docs, RFCs, comparison articles, vendor support tickets) in addition to internal sources.

Example:

> - **Vendor docs:** AWS Cognito IdP service quotas page (https://docs.aws.amazon.com/cognito/latest/developerguide/limits.html) to confirm the documented limit.
> - **Vendor support:** check past AWS Support cases for IdP limit-raise requests; AWS often raises soft limits.
> - **Related code:** `rg 'IdentityProvider' services/auth/` to see how many IdPs are currently configured per pool in the existing codebase.

## Section Order

Sections appear in the order shown for each archetype. Never omit a section heading. When a section legitimately has nothing to say, keep the heading and write the brief placeholder line described at the top of this file. If the absence is itself important context (e.g., a Feature work item with no design refs), call it out in the Lead in addition to the placeholder line in the empty section.
