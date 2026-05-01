# Gathering Guide

Read this when you reach Step 1 of the workflow. Skip it on earlier steps.

## What to Fetch

Pull every artifact in parallel where the MCP allows it. The fetch is the foundation; underfetching is the most common cause of a refined ticket that loses information.

1. **Ticket fields and description.** Call `getJiraIssue` once with these fields:

   ```
   summary, description, status, issuetype, priority, labels,
   components, assignee, reporter, created, updated, parent, issuelinks
   ```

   Use `responseContentFormat: "markdown"` so the description comes back as markdown rather than ADF JSON. Markdown is the format `editJiraIssue` expects when writing the standard `description` field back. Some rich-text custom fields (notably a "Bug Description" field on Jira instances configured for it) require raw ADF instead and are written via a separate `editJiraIssue` call; see `references/jira-formatting.md` for that path.

2. **Comments.** Fetch the full comment thread. Comments are where decisions, status updates, customer back-channels, and investigation artifacts go to die. Pulling the description without the comments is the single most common failure mode of a ticket refiner.

3. **Changelog.** Fetch with `expand: "changelog"` only when the current description looks empty, templated, or sparser than the comments suggest it should be. Earlier description versions often hold detail that was lost during a careless edit.

4. **Linked tickets.** Walk every entry in `issuelinks` from step 1. For each linked ticket, capture: key, link type (`Duplicate`, `Relates`, `Blocks`, `is blocked by`), summary, and status. A linked ticket sometimes carries the scope or the workaround that the current ticket only hints at.

If the calling context (the `jira-issue-triage` agent in Phase 5) already passed in a fetched payload, reuse it. Do not refetch.

## Fetch for Context, Not for Output

Most of the fields above exist so you can understand the ticket. They do not belong in the refined description. Jira shows them in the sidebar and header already, and restating them is redundant noise.

| Field | Where it appears in the Jira UI |
|-------|----------------------------------|
| `status` | Header pill |
| `issuetype` | Header icon and label |
| `priority` | Sidebar |
| `parent` | Breadcrumb and sidebar |
| `assignee` | Sidebar |
| `reporter` | Sidebar |
| `labels` | Sidebar |
| `components` | Sidebar |

The single exception is **comments**. Comment content is hidden behind a separate tab in the Jira UI and easily missed by anyone not following the ticket in real time. Surfacing comment-thread decisions, investigation findings, and meaningful status changes into the description body is the primary value of this skill.

## Completeness Gate

Do not advance to Step 2 (archetype classification) until you have:

- [ ] Read the full description.
- [ ] Read every comment.
- [ ] Read the changelog if Step 1 flagged it as worth checking.
- [ ] Walked every link in `issuelinks` and noted what each linked ticket adds.

Skipping any of these is how facts get lost in the rewrite.

## Per-Archetype Priorities

The archetype determined in Step 2 changes which artifacts matter most. Use this table as a hint when the ticket is dense and you need to prioritize what to read carefully.

| Archetype | What to surface first |
|-----------|------------------------|
| **Bug** | Error strings (verbatim), reproduction steps, affected users and environments, observability links, customer IDs |
| **Feature** | Acceptance criteria, design docs and product briefs, stakeholder decisions, UX requirements, parent epic context |
| **Task** | Definition of done, why-now context, dependencies on other work, migration steps, rollback plan |
| **Incident** | Timeline (start, detection, mitigation, resolution), blast radius, affected tenants, communication log |
| **Spike** | Open questions, exploration boundaries, constraints, preliminary findings or benchmarks |

## ADF Content-Loss Check

The MCP server reads the description as ADF and converts it to markdown for you. Markdown does not have a representation for several ADF features. Those features are silently dropped on the round trip when the rewrite is converted back to ADF and saved. There is no error. There is no warning. The content just disappears.

Skim the original description and the comments for ADF-only features before you rewrite. Make a note of any you find. The decision to warn the user about content loss happens at preview time (Step 7).

| ADF feature | Frequency on real tickets |
|-------------|----------------------------|
| Smart Links (Jira/Confluence URL cards) | Very common |
| `@mentions` of users | Very common |
| Info / Warning / Error panels with content | Common |
| Status lozenges (`In Progress`, `Done`) | Common |
| Expand / collapse sections with content | Common |
| Task lists with checked items | Common |
| Embedded media, attached images, video | Common |
| Tables with merged or color-tinted cells | Moderate |
| Date pickers | Moderate |
| Multi-column layouts | Moderate |

Warn the user only when a loss would be **substantive**. Substantive means the user could lose meaningful information or workflow affordances: a panel containing real instructions, a task list whose checked state matters, an expand section hiding actual content, an embedded video or screenshot, a colored table that conveys data through its color. Cosmetic-only losses (a smart-link card becoming a plain URL) do not need a warning.

When you do warn, keep it to one sentence outside the preview. The preview itself stays focused on the rewritten ticket content.
