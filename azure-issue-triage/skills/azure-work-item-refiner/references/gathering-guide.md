# Gathering Guide

Read this when you reach Step 1 of the workflow. Skip it on earlier steps.

## What to Fetch

Pull every artifact in parallel where the MCP allows it. The fetch is the foundation; underfetching is the most common cause of a refined work item that loses information.

1. **Work-item fields and description.** Call `wit_get_work_item` with `expand: "all"` (or the equivalent flag the MCP tool exposes) so you get fields, relations, and links in one round trip. The fields you actually need:

   ```
   System.Title, System.Description, System.State, System.Reason,
   System.WorkItemType, Microsoft.VSTS.Common.Priority,
   Microsoft.VSTS.Common.Severity, System.Tags, System.AreaPath,
   System.IterationPath, System.AssignedTo, System.CreatedBy,
   System.CreatedDate, System.ChangedDate, System.Parent,
   Microsoft.VSTS.Common.AcceptanceCriteria
   ```

   The description comes back as HTML. Treat it as HTML in your inventory; convert to a markdown view internally if that helps you reason about content (the rewrite is authored as markdown and then converted back to HTML at write time, per `references/azure-html-formatting.md`).

2. **Comments (Discussion).** Fetch the full comment thread via the MCP's comment endpoint (commonly `wit_get_work_item_comments` or accessible through `expand: "all"`). Comments are where decisions, status updates, customer back-channels, and investigation artifacts go to die. Pulling the description without the comments is the single most common failure mode of a work-item refiner.

3. **Revision history.** Fetch only when the current description looks empty, templated, or sparser than the comments suggest it should be. AzDO retains every revision; earlier description versions often hold detail that was lost during a careless edit. The MCP tool varies (`wit_get_work_item_revisions` or similar); skip when not needed.

4. **Linked work items.** Walk every entry in the work item's `relations` array from step 1. For each link, capture: ID, link type (`System.LinkTypes.Related`, `System.LinkTypes.Hierarchy-Forward` for child, `System.LinkTypes.Hierarchy-Reverse` for parent, `System.LinkTypes.Duplicate-Forward`, `System.LinkTypes.Dependency-*`), the target work item's title, and its state. A linked work item sometimes carries the scope or the workaround that the current work item only hints at.

If the calling context (the `azure-issue-triage` agent in Phase 5) already passed in a fetched payload, reuse it. Do not refetch.

## Fetch for Context, Not for Output

Most of the fields above exist so you can understand the work item. They do not belong in the refined description. The AzDO UI shows them in the sidebar and header already, and restating them is redundant noise.

| Field | Where it appears in the AzDO UI |
|-------|----------------------------------|
| `System.State` | Header pill |
| `System.WorkItemType` | Header icon and label |
| `Microsoft.VSTS.Common.Priority` | Sidebar |
| `Microsoft.VSTS.Common.Severity` | Sidebar (Bug only by default) |
| `System.Parent` | Breadcrumb and sidebar |
| `System.AssignedTo` | Sidebar |
| `System.CreatedBy` | Sidebar |
| `System.Tags` | Header chip strip |
| `System.AreaPath`, `System.IterationPath` | Sidebar |

The single exception is **Discussion comments**. Comment content is hidden behind a separate tab in the AzDO UI and easily missed by anyone not following the work item in real time. Surfacing comment-thread decisions, investigation findings, and meaningful state changes into the description body is the primary value of this skill.

## Completeness Gate

Do not advance to Step 2 (archetype classification) until you have:

- [ ] Read the full description.
- [ ] Read every Discussion comment.
- [ ] Read the revision history if Step 1 flagged it as worth checking.
- [ ] Walked every entry in `relations` and noted what each linked work item adds.

Skipping any of these is how facts get lost in the rewrite.

## Per-Archetype Priorities

The archetype determined in Step 2 changes which artifacts matter most. Use this table as a hint when the work item is dense and you need to prioritize what to read carefully.

| Archetype | What to surface first |
|-----------|------------------------|
| **Bug** | Error strings (verbatim), reproduction steps, affected users and environments, observability links, customer IDs |
| **Feature** | Acceptance criteria, design docs and product briefs, stakeholder decisions, UX requirements, parent epic context |
| **Task** | Definition of done, why-now context, dependencies on other work, migration steps, rollback plan |
| **Incident** | Timeline (start, detection, mitigation, resolution), blast radius, affected tenants, communication log |
| **Spike** | Open questions, exploration boundaries, constraints, preliminary findings or benchmarks |

## HTML Content-Loss Check

The work item's description and comments are HTML. The rewrite is authored as markdown and converted back to HTML at write time. Most HTML round-trips cleanly, but a few constructs can lose meaning.

Skim the original description and the comments for HTML-only features before you rewrite. Make a note of any you find. The decision to warn the user about content loss happens at preview time (Step 7).

| HTML construct | Frequency on real work items |
|----------------|------------------------------|
| `@mentions` rendered as `<a data-vss-mention="...">` | Very common |
| Inline images and attachments (`<img>`) | Common |
| Color-tinted callouts (`<div style="background-color: ...">`) | Moderate |
| Embedded videos / media iframes | Rare on AzDO; common on migrated content |
| Custom HTML used for layout (`<table>` for visual columns) | Rare |
| In-line `<script>` or `<style>` blocks | Rare; already stripped on display |

Warn the user only when a loss would be **substantive**. Substantive means the user could lose meaningful information or workflow affordances: a callout containing real instructions, an embedded video that demonstrates a workflow, a colored table that conveys data through its color. Cosmetic-only losses (a thumbnail becoming a plain link, a mention chip becoming `@User Name` plain text) do not need a warning.

When you do warn, keep it to one sentence outside the preview. The preview itself stays focused on the rewritten work-item content.
