# Jira — write payloads

Jira writes flow through three tools:

- `editJiraIssue` — field updates, assignment, labels, link-by-field.
- `transitionJiraIssue` — state transitions (preceded by `getTransitionsForJiraIssue` to resolve the transition ID).
- `addCommentToJiraIssue` — comments (ADF format).
- `createIssueLink` — issue-to-issue link creation.

## `assign(id, userRef | null)`

```
editJiraIssue(issueIdOrKey: <id>, fields: { assignee: { accountId: "<id>" } })
```

To unassign:
```
editJiraIssue(issueIdOrKey: <id>, fields: { assignee: null })
```

`null` here is correct. Do not pass an empty object — Jira will reject it.

## `transition(id, abstractStateName)`

Two calls:

1. `getTransitionsForJiraIssue(issueIdOrKey: <id>)` → returns `transitions[]` with `{ id, name }`.
2. Find the entry where `transition.name == policy.states.<abstractStateName>`. If not found, fall back to a case-insensitive substring match. If still not found, lazy-prompt with the available transitions.
3. `transitionJiraIssue(issueIdOrKey: <id>, transitionId: "<id>")`.

The transition itself may move the issue through multiple states (Jira workflows can have hidden intermediate states). The adapter does not enforce any pre-conditions; the server validates.

## `updateFields(id, { title?, body?, severity?, dueDate?, sprint?, storyPoints?, customFields? })`

One `editJiraIssue` call with all supplied fields:

| Input field | Jira field | Value transform |
|---|---|---|
| `title` | `fields.summary` | as-is, plain text |
| `body` | `fields.description` | markdown; pass `contentFormat: "markdown"` |
| `severity` | depends on schema: `customfield_xxxxx` for "Severity" / "Severity Level" / "Bug Severity", or `fields.priority.name` as fallback | project `severity_label_map[<abstractTier>]`; for object-shaped fields use `{ value: "<label>" }` or `{ name: "<label>" }` per the schema |
| `dueDate` | `fields.duedate` | `yyyy-MM-dd` |
| `sprint` | `customfield_xxxxx` (sprint field; discover via `getJiraIssueTypeMetaWithFields`) | numeric sprint ID |
| `storyPoints` | `customfield_xxxxx` (story points field) | numeric |
| `customFields[<id-or-name>]` | as documented in the schema | as-is |

### Custom rich-text fields (e.g. "Bug Description")

These reject markdown and require raw ADF. Surface them as a **separate** `editJiraIssue` call with `contentFormat: "adf"` (or omit the parameter when the body is already an object). Construct the ADF from the markdown using the same converter the comment path uses.

## `addComment(id, body)`

Body is markdown. The adapter builds an ADF document:

```
addCommentToJiraIssue(
  issueIdOrKey: <id>,
  contentFormat: "adf",
  body: JSON.stringify({
    type: "doc",
    version: 1,
    content: [<adf-nodes>]
  })
)
```

### Markdown → ADF node map (the converter)

| Markdown | ADF node |
|---|---|
| Paragraph | `{ type: "paragraph", content: [<inline>] }` |
| Heading | `{ type: "heading", attrs: { level: <n> }, content: [<inline>] }` |
| Bullet list | `{ type: "bulletList", content: [<listItem>] }` |
| Numbered list | `{ type: "orderedList", content: [<listItem>] }` |
| List item | `{ type: "listItem", content: [{ type: "paragraph", content: [<inline>] }] }` |
| Bold | `{ type: "text", text: "...", marks: [{ type: "strong" }] }` |
| Italic | `{ type: "text", text: "...", marks: [{ type: "em" }] }` |
| Inline code | `{ type: "text", text: "...", marks: [{ type: "code" }] }` |
| Fenced code | `{ type: "codeBlock", attrs: { language: "<lang>" }, content: [{ type: "text", text: "..." }] }` |
| Link | `{ type: "text", text: "...", marks: [{ type: "link", attrs: { href: "<url>" } }] }` |
| Blockquote | `{ type: "blockquote", content: [<paragraph>] }` |
| Horizontal rule | `{ type: "rule" }` |
| Mention `@[userRef]` | `{ type: "mention", attrs: { id: "<accountId>" } }` |

### Why ADF and not markdown for comments

Pass `contentFormat: "markdown"` and mentions render as the wiki-markup form `[~accountid:XXXX]` — Jira no longer parses that on Cloud, so mentions render as literal bracket text. ADF is the only reliable comment path on Cloud.

## `addLabel(id, label)` / `removeLabel(id, label)`

```
editJiraIssue(
  issueIdOrKey: <id>,
  update: { labels: [{ add: "<label>" }] }
)
```

`{ remove: "<label>" }` for removeLabel. Multiple operations:

```
editJiraIssue(
  issueIdOrKey: <id>,
  update: { labels: [{ add: "triaged" }, { remove: "needs-triage" }] }
)
```

## `linkIssue(fromId, toId, kind)`

| `kind` | Tool | Args |
|---|---|---|
| `duplicate-forward` | `createIssueLink` | `link_type: "Duplicate"`, `inward_issue_key: <toId>`, `outward_issue_key: <fromId>` (Jira's "duplicates" direction) |
| `related` | `createIssueLink` | `link_type: "Relates"`, `inward_issue_key: <toId>`, `outward_issue_key: <fromId>` |
| `parent` | `editJiraIssue` | `fields: { parent: { key: <toId> } }` — parent is a field on Jira Cloud, not a link |

If the project does not have the `Duplicate` or `Relates` link type, list available types via the schema and lazy-prompt.

## `linkPullRequest(id, prUrl)`

No-op on Jira. Returns `{ linked: false, reason: "auto-link" }`. Jira auto-creates a development panel entry when a PR description, commit message, or branch name contains the issue key (`PROJ-123`). Make sure the PR author includes the key.

## Failure modes

- **400 with `errorMessages`:** field validation failed. Surface the message verbatim.
- **403 on edit:** the running user lacks Edit Issue permission. Surface the user's accountId.
- **404 on edit:** the issue ID is wrong. Confirm with `getIssue`.
- **`Failed to convert markdown to adf`:** body input was not markdown. Surface the converter's error and the offending body's first 200 characters.

Never retry a write call after a failure. Re-enter the diff-and-confirm gate.
