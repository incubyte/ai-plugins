# Classification Guide

Read this when you reach Steps 3 and 4 of the workflow. The first half (information categories) belongs to Step 3. The second half (rewrite principles) belongs to Step 4.

## Information Categories (Step 3)

Catalog every distinct fact across the description, every comment, the changelog (when read), and any linked tickets. Each fact gets one category. The category drives where it lands in the template.

| Category | Examples |
|----------|----------|
| **Observed symptoms** | What users see: errors, missing data, broken UI, wrong totals, slow responses, blank screens |
| **Affected scope** | Customer names, tenant IDs, user IDs, environment (prod / staging / region), browser or device, the population of users hit |
| **Investigation artifacts** | Observability links, log snippets, DB queries, interaction IDs, channel IDs, API request and response samples, screenshots, video recordings |
| **Requirements and acceptance criteria** | Definition of done, feature constraints, success metrics, target user stories, design specs |
| **Decisions and rationale** | Choices made (in comments, threads, meetings) plus the reasoning behind them. Decisions buried in comment threads are the most-frequently-lost piece of context. Surface them. |
| **Unverified analysis** | Hypothesized causes, AI-generated suggestions, "I think it's X because..." reasoning, proposed fixes that nobody has tested |
| **Source-system metadata** | Support escalation tables, Zendesk/Salesforce ticket fields, intake forms, Applause exports, PagerDuty incident records |
| **Status updates from comments** | Progress notes, blockers, handoff context, "we paused this for a week", "Bob took it over". Summarize these into the description. Do NOT restate the ticket's current Jira status, assignee, or priority since those are visible in the UI. |

## Verified vs Unverified Flag

Every fact also carries one of two flags:

- **Verified.** Direct evidence supports it. A log entry shows the 500. A query result names the customer. A screenshot proves the UI is broken. The reporter said it.
- **Unverified.** Reasoning, hypothesis, or speculation. "The root cause is probably the token rotation" is unverified, even when the speaker sounds confident.

The flag determines section placement in Step 4. Unverified facts go into Working Hypotheses. Verified facts go into the section their content matches.

## Rewrite Principles (Step 4)

Apply these when you turn the inventory into prose.

| Principle | Detail |
|-----------|--------|
| **Symptoms over solutions** | Lead with what users experience or what needs to happen. Do not lead with a proposed fix, even when the proposed fix is in the original. |
| **Evidence over claims** | Logs, error strings, query results, and screenshots are evidence. Frame everything else as a working hypothesis. |
| **Decisions are first-class** | A decision made in a comment thread is invisible. Pull it into the description body with the rationale. |
| **Surface affected scope** | Pull customer names, tenant IDs, environments, and population-of-users-affected from comments into the description body, near the top. |
| **Preserve every artifact** | Customer IDs, log links, query results, error strings, screenshots, attachments, video links: every one survives. Reorganize. Do not delete. |
| **Prose over tables** | Write prose for one to three items. Use a table only when there are four or more rows with distinct columns that would be hard to scan as sentences. A two-row table is almost always worse than a sentence. |
| **Track dependencies** | When the ticket is blocked on or by external parties, name them in an Open Blockers section. One blocker is a sentence. Three or more is a table. |
| **Clean up the noise** | Remove abandoned exploratory queries, conversational framing ("I tried to look into this..."), duplicate separators, and stale "@channel any updates?" pings. |
| **Context over assumption** | A reader with no prior knowledge should be able to read the refined ticket and understand it without chasing external sources. Add the one sentence of background that makes the rest make sense. |
| **No fix prescription** | Strike `Immediate Fix Required`, `Recommended Fix`, `Longer-Term Recommendations`, and similar prescriptive sections. The team that owns the work decides the approach. |
| **No sidebar restate** | Status, priority, type, epic, assignee, reporter, labels, and components live in the Jira sidebar. Do not duplicate them in the body. The exception is comment-thread context, which is hidden behind a tab. |

## Common Patterns

These three patterns show up on almost every refinement.

### Pattern 1: A buried decision

The original description says nothing about ownership. Comment 4 says "Discussed in standup, Platform team will own the rollback plan." The refined description carries that into the Open Blockers section with the date the decision was made and the team named.

### Pattern 2: An unverified root cause stated as fact

The original description says "Root cause: stale auth token after deploy." There is no log entry or query result confirming this. The refined description moves this to Working Hypotheses, framed as: "The most likely cause based on the timeline is stale auth tokens after the 14:00 deploy. This has not been confirmed; verifying requires a log query against the auth service for that window."

### Pattern 3: Evidence trapped in a comment thread

Comment 7 contains a Datadog link with 200 lines of relevant errors. The refined description moves the link into Investigation Notes under Observability, names the time window the link covers, and summarizes the error pattern in one sentence.
