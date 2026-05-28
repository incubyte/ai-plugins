# Jira — mentions

How the reserved `@[userRef]` token in markdown bodies projects to Jira's mention syntax.

## Token shape

In canonical markdown, mentions appear as:

```
@[<userRef>]
```

where `<userRef>` is the opaque handle returned by `resolveUser({ email })` or `resolveUser({ name })`. Internally on the Jira side, the handle is `{ accountId, email, displayName }`.

## Two projection paths

The mention projection depends on the body format the adapter is writing.

### Comments (ADF path) — `addComment`

Comments are written as ADF (`contentFormat: "adf"`). Mentions become ADF mention nodes:

```json
{ "type": "mention", "attrs": { "id": "<accountId>" } }
```

The ADF converter (documented in `writes.md`) inserts the node inline at the mention's position in the text. Display name is automatically resolved by Jira from the accountId — do not embed it.

### Markdown body fields (description, summary's renderable fields)

`editJiraIssue` with `contentFormat: "markdown"` sends a markdown string. ADF mention nodes cannot appear in a markdown string. The wiki-markup form is the only one Jira's markdown converter recognizes:

```
[~accountid:<accountId>]
```

The adapter emits this in place of `@[userRef]`. Jira Cloud accepts this in description fields and renders an interactive mention chip.

## Why not markdown mentions everywhere

Comments via `contentFormat: "markdown"` accept `[~accountid:<id>]` syntactically, but the rendered output frequently fails to attach the mention metadata correctly on Jira Cloud — the user sees `@Name` text with no chip and no notification. ADF for comments avoids this. The markdown path is only used for fields where ADF isn't an option.

## Resolution failure fallback

If `resolveUser` returned a "resolved by name only" handle (no `accountId`):

- Emit the plain text `@<displayName>` instead.
- Surface a warning: `Could not resolve <name> to a Jira accountId; mention rendered as plain text.`

## Mention placement rules

- **Comments** (`addComment`): mentions trigger a notification. Use sparingly.
- **Description** (`updateFields(body: ...)`): mentions render but notification behavior varies by org settings. Do not rely on description mentions to page someone.
- **Summary** (`updateFields(title: ...)`): mentions are stripped. The adapter removes them before writing.
- **Labels**: mentions are not supported. Strip them.

## Multiple mentions

Multiple `@[userRef]` tokens in the same body are all converted independently. No deduplication.

## Round-trip from existing content

When `getIssue` reads a description that already contains Jira mentions:

- **ADF mention nodes** (`{ type: "mention", attrs: { id, text } }`): the adapter inverts them to `@[userRef]` if `resolveUser({ accountId })` succeeds; otherwise the plain text from `attrs.text` (or `@Name` if `text` is missing) and a one-line warning.
- **Wiki-markup mentions** (`[~accountid:<id>]`): same flow.
- **Plain `@Name` text with no metadata**: leave as plain text, no resolution attempt.
