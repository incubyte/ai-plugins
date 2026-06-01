# Gathering Guide

Read this when you reach Step 1 of the workflow. Skip it on earlier steps.

## What to fetch

Pull every artifact in parallel where the adapter allows it. The fetch is the foundation; underfetching is the most common cause of a refined issue that loses information.

1. **Issue fields and description.** Call `getIssue(id)` via `issuekit:tracker-adapter`. The adapter returns the normalized `Issue` shape with body in markdown regardless of source format. Fields the adapter populates include:

   ```
   id, url, title, body, type, state, severity, assignee, reporter,
   created, updated, resolved, labels, parent, customFields, raw
   ```

2. **Comments.** Call `getIssueComments(id)`. Comments are where decisions, status updates, customer back-channels, and investigation artifacts go to die. Pulling the description without the comments is the single most common failure mode of an issue refiner.

3. **History.** Call `getIssueHistory(id)` only when the current description looks empty, templated, or sparser than the comments suggest it should be. Earlier description versions and state-change events often hold detail that was lost during a careless edit. Jira's `getIssueHistory` returns an empty array today; AzDO returns full revision data. Both are handled the same way.

4. **Linked issues.** Walk every entry in `customFields.linkedIssues` (or the equivalent populated by the adapter from AzDO's `relations` or Jira's `issuelinks`). For each linked issue, capture: id, link type (`Duplicate`, `Relates`, `Blocks`, `is blocked by`, `Hierarchy`), title, and state. A linked issue sometimes carries the scope or the workaround that the current issue only hints at.

If the calling context (the `issue-triage` agent in Phase 3 prep) already passed in a fetched payload, reuse it. Don't re-fetch.

## Fetch for context, not for output

Most of the fields above exist so you can understand the issue. They do not belong in the refined description. The tracker UI shows them in the sidebar and header already, and restating them is redundant noise.

| Field | Where it appears in the tracker UI |
|-------|----------------------------------|
| `state` / `status` | Header pill |
| `type` | Header icon and label |
| `severity` / `priority` | Sidebar |
| `parent` | Breadcrumb and sidebar |
| `assignee` | Sidebar |
| `reporter` | Sidebar |
| `labels` / `tags` | Sidebar |
| `customFields.components` | Sidebar |
| AzDO area path / iteration path | Sidebar |

The single exception is **comments**. Comment content is hidden behind a separate tab in the tracker UI and easily missed by anyone not following the issue in real time. Surfacing comment-thread decisions, investigation findings, and meaningful status changes into the description body is the primary value of this skill.

## Completeness gate

Do not advance to Step 2 (archetype classification) until you have:

- [ ] Read the full description.
- [ ] Read every comment.
- [ ] Read the history if Step 1 flagged it as worth checking.
- [ ] Walked every entry in `customFields.linkedIssues` and noted what each linked issue adds.

Skipping any of these is how facts get lost in the rewrite.

## Per-archetype priorities

The archetype determined in Step 2 changes which artifacts matter most. Use this table as a hint when the issue is dense and you need to prioritize what to read carefully.

| Archetype | What to surface first |
|-----------|------------------------|
| **Bug** | Error strings (verbatim), reproduction steps, affected users and environments, observability links, customer IDs |
| **Incident** | Timeline (start, detection, mitigation, resolution), blast radius, affected tenants, communication log |
| **Story** | Acceptance criteria, design docs and product briefs, stakeholder decisions, UX requirements, parent epic context |
| **Feature** | Strategic intent, parent program, stories under it, success metrics, scope boundaries |
| **Task** | Definition of done, why-now context, dependencies on other work, migration steps, rollback plan |
| **Spike** | Open questions, exploration boundaries, constraints, preliminary findings or benchmarks |

## Content-loss check

The adapter reads the description from the vendor's storage format (AzDO HTML or Jira ADF) and presents a markdown view. Markdown does not have a representation for several vendor-specific features. Those features are silently dropped on the round trip when the rewrite is converted back to the vendor format and saved. There is no error. There is no warning. The content just disappears.

Skim the original description and the comments for these features before you rewrite. Make a note of any you find. The decision to warn the user about content loss happens at preview time (the agent's Phase 3 gate).

| Feature | Frequency on real issues |
|-------------|----------------------------|
| Smart Links / URL cards | Very common (both vendors) |
| `@mentions` of users | Very common |
| Info / Warning / Error panels with content (Jira) | Common |
| Color-tinted callouts (`<div style="background-color: ...">` on AzDO) | Moderate |
| Status lozenges (`In Progress`, `Done`) | Common (Jira) |
| Expand / collapse sections with content | Common (Jira) |
| Task lists with checked items | Common (Jira) |
| Embedded media, attached images, video | Common |
| Tables with merged or color-tinted cells | Moderate |
| Date pickers | Moderate (Jira) |
| Multi-column layouts | Moderate |

Warn the user only when a loss would be **substantive**. Substantive means the user could lose meaningful information or workflow affordances: a panel containing real instructions, a task list whose checked state matters, an expand section hiding actual content, an embedded video or screenshot, a colored table that conveys data through its color. Cosmetic-only losses (a smart-link card becoming a plain URL) do not need a warning.

When you do warn, keep it to one sentence as an entry in the `warnings` array the skill returns. The body itself stays focused on the rewritten content.

The adapter does its best to preserve mentions: `@[userRef]` round-trips cleanly if `resolveUser` succeeds for both directions. Otherwise the mention degrades to plain text and the adapter surfaces a one-line warning.
