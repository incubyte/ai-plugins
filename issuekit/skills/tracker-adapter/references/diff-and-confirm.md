# Diff-and-confirm gate

Every write batch passes through this gate. The gate is always on. There is no `--dry-run` flag — declining at the gate is the dry run.

## Contract

The verb-plugin builds a list of intended writes. Each entry has the shape:

```
{
  verb:   "addComment" | "transition" | "updateFields" | "assign" | "addLabel" | "removeLabel" | "linkIssue" | "linkPullRequest",
  target: <IssueId>,
  before: <current value | null>,
  after:  <intended value>,
  notes?: <one-line clarification>
}
```

The skill renders the batch as a markdown table and calls `AskUserQuestion` once. On confirmation, it replays each tuple through the verb dispatcher in order. On decline, it returns without firing any write.

## Render format

```
## Pending writes (<n> changes on <issue-url>)

| # | Verb | Field / target | Before | After |
|---|------|----------------|--------|-------|
| 1 | updateFields | title | "Bug" | "VMS: Visitor notifications not sending for scheduled visits" |
| 2 | updateFields | body | (current description, abridged) | (new markdown body, abridged) |
| 3 | transition | state | "New" | "investigating" → "Active" (reason: Investigating) |
| 4 | assign | assignee | unassigned | <running user> |
| 5 | addComment | new comment | — | "Investigation underway. Findings: ..." |
| 6 | addLabel | tags | — | + triaged |
| 7 | linkIssue | related | — | → AB#12345 (Related) |
| 8 | linkPullRequest | PR link | — | https://dev.azure.com/org/proj/_git/repo/pullrequest/4567 |
```

Long bodies (`before` and `after` of `updateFields(body: ...)` or `addComment`) are abridged to:
- First 6 lines, then a `...` row, then the last 2 lines.
- A separate "Full diff" section appears below the table, rendered as a unified-diff block per multi-line field.

## Long-body diff block

```
### Full diff: updateFields(body)

````diff
--- before
+++ after
@@ ... @@
-<existing body line>
+<new body line>
````
```

Use a `diff`-language fenced code block. Show full context for any field whose `before` or `after` is more than 10 lines.

## Confirmation prompt

After rendering, call `AskUserQuestion` with:

- Question: `"Apply these <n> changes to <issue-url>?"`
- Options:
  - "Apply all" — fire every write in order
  - "Apply selected" — show the table with checkbox tokens and let the user remove specific entries; re-confirm
  - "Cancel" — return without writing

Do not call separate confirmation prompts per row. Batch confirmation is the whole point.

## Failure handling

On the first failed write:
- Stop the batch.
- Print `Wrote 1..k of n changes. Failed at #<k+1> (<verb>): <error>.`
- Do not attempt to roll back.
- Return control to the caller for the partial state.

The caller decides whether to retry or surface the failure to the user.

## Edge cases

- **Empty batch.** If the verb-plugin produces zero writes, do not show the gate. Print `No changes to apply.` and return.
- **Single-write batch.** Still render the table and ask. Consistency beats brevity.
- **Re-entry mid-flow.** If the verb-plugin needs to update a comment it just posted (e.g. to add a follow-up), that is a fresh batch. The gate runs again.

## What the gate guarantees

- No write verb fires before the gate confirms.
- No write verb fires on decline.
- The user sees, in one place, every change about to land. There is no hidden tail of writes after the table.

## What the gate does NOT do

- It does not validate the contents of the writes. The verb-plugin is responsible for not producing bad data (e.g., empty title, broken markdown).
- It does not check permission to write. The MCP returns an error if the user lacks access; the gate has nothing to verify in advance.
- It does not block reads. Reads chain freely.
