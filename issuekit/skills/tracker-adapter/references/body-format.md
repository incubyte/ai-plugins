# Body format — canonical markdown subset

Verb-plugins author every issue body, comment, and field-update body in **markdown**. The adapter converts to the vendor's storage format (AzDO HTML or Jira-flavored markdown / ADF) at write time.

This file is the canonical subset. Per-adapter quirks live in `adapters/<tracker>/body-format.md`.

## Supported subset

| Construct | Markdown source |
|---|---|
| Paragraph | one or more lines separated by a blank line |
| Heading | `## Heading` (levels 1–6 allowed; prefer `##` as the highest level inside a body so the issue title remains the visible H1) |
| Bold | `**bold**` |
| Italic | `*italic*` or `_italic_` |
| Inline code | `` `code` `` |
| Fenced code block | triple-backtick with optional language tag |
| Bullet list | `- item` |
| Numbered list | `1. item` |
| Link | `[text](url)` (schemes `http`, `https`, `mailto`, and tracker-relative paths only) |
| Blockquote | `> quoted` (one level only; nested blockquotes render inconsistently across vendors) |
| Horizontal rule | `---` |
| Mention (reserved token) | `@[userRef]` where `userRef` is the value returned by `resolveUser` |

## Out of subset

Anything not in the table above. Common cases:

- Tables — AzDO renders them but Jira's MCP markdown→ADF converter is inconsistent. If a verb-plugin really needs a table, format the data as a bullet list of `field: value` lines.
- Strikethrough — `~~text~~` works on Jira but not AzDO. Avoid.
- Nested blockquotes — inconsistent everywhere.
- Inline images — supported by both vendors but only when the image URL is an attachment on the same issue. Out of scope for v1.0.0.
- Interactive checkboxes (`- [ ]`) — render as escaped bracket text on Jira; render as the literal characters on AzDO. Use bullet lists with explicit "(not done)" / "(done)" markers if checkbox semantics are needed.
- HTML tags inside the markdown — escaped to literal text by both vendors' converters.

When out-of-subset content appears, the adapter renders it literally and surfaces a single warning at the end of the run:

> Body contained out-of-subset markdown constructs: <list>. Rendered as literal text.

## Mention token

The `@[userRef]` token is the only vendor-portable way to mention a user. `userRef` is the opaque handle returned by `resolveUser`. The adapter projects it:

- **Azure DevOps:** to `<a href="#" data-vss-mention="version:2.0,<unique-name>">@Display Name</a>`.
- **Jira:** to a Jira mention. For comments via `addCommentToJiraIssue` with `contentFormat: "adf"`, the adapter constructs an ADF `mention` node (`{ type: "mention", attrs: { id: "<accountId>" } }`). For markdown body fields, the adapter emits the `[~accountid:<accountId>]` wiki-markup form — Jira accepts it in body fields even on Cloud.

Mentions in `updateFields(body: ...)` and in `addComment(body: ...)` both work. Mentions inside `updateFields(title: ...)` are silently stripped — most trackers do not allow mentions in the title.

## Newlines

Markdown source must contain real newlines (`\n`). The JSON transport wraps them as the escape sequence `\n`; that is JSON encoding, not content. Do not embed the two-character literal `\n` in the source — Jira renders it verbatim and AzDO renders nothing useful either.

## Content-loss warnings

When the adapter reads an existing body and round-trips it through markdown, vendor-specific features that have no markdown equivalent are stripped. The adapter surfaces a single warning per run when something **substantive** is lost:

- AzDO: color-tinted callouts (`<div style="...">`), inline videos, layout tables.
- Jira: Smart Links, info/warning/error panels, status lozenges, expand/collapse sections, task lists, embedded media.

Smart-link cards becoming plain URLs are cosmetic and not surfaced. Lost mentions are surfaced (assignment intent matters). Lost callouts are surfaced when the callout text contained real instructions.

## Author-time checklist

Before passing a body to a write verb:

- [ ] Headings use `##` as the highest level.
- [ ] Lists use `-` or `1.` consistently within a block.
- [ ] Links use a supported scheme.
- [ ] Mentions use `@[userRef]`, not raw names.
- [ ] No HTML, no wiki markup, no `~~strikethrough~~`, no nested blockquotes.
- [ ] Real newlines, not literal `\n`.
