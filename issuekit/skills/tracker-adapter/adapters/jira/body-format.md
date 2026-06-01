# Jira — body format (markdown → ADF)

The Atlassian MCP server takes plain markdown for most descriptions and converts it to ADF (Atlassian Document Format) under the hood. This file documents which markdown features survive the conversion intact, which to use with caution, and which are forbidden because they break the call.

The canonical authoring format is markdown (see `issuekit/skills/tracker-adapter/references/body-format.md` for the cross-vendor subset). This adapter file documents Jira-specific behavior on top of that subset.

## API format rule

`editJiraIssue` and `createJiraIssue` both accept the description as a markdown **string**. Always pass markdown. Never pass an ADF JSON object: the server still tries to convert it as markdown, fails to parse the JSON, and returns `Failed to convert markdown to adf`.

The description content the markdown converter receives must contain real line breaks. Construct it like this:

```markdown
## Heading

Paragraph with **bold**.
```

When that string is sent through a JSON-encoded API request, the JSON encoder represents each real newline as the two-character sequence `\n` inside the wire payload. The JSON parser on the server side decodes those escapes back to real newlines before the markdown converter runs. That is fine and expected:

```json
{ "fields": { "description": "## Heading\n\nParagraph with **bold**." } }
```

The forbidden case (covered in the Forbidden table below) is when the description content itself contains a literal backslash followed by the letter `n` after JSON decoding. That shows up on the rendered ticket as the two characters `\n` instead of a line break.

When calling `editJiraIssue`, set `contentFormat: "markdown"` if the parameter is required by the MCP version in use. Some Jira custom fields (e.g., a "Bug Description" rich-text field) reject markdown and require raw ADF; that case is handled by a separate `editJiraIssue` call with `contentFormat: "adf"` and is documented in `writes.md`.

For **comments**, the adapter sends ADF directly (`contentFormat: "adf"`). Markdown comments produce broken mentions on Jira Cloud. See `writes.md` for the converter.

## Confirmed safe (description body, markdown path)

These features have been tested through the MCP markdown-to-ADF converter and survive the round trip cleanly. Use them freely.

| Feature | Markdown syntax | Notes |
|---------|------------------|-------|
| Headings | `##`, `###`, `####`, etc. | Levels 1 through 6 all render. Prefer `##` as the highest level in a body. |
| Bold | `**text**` | |
| Italic | `*text*` or `_text_` | |
| Inline code | `` `code` `` | |
| Fenced code blocks | Triple backticks with optional language tag (e.g. ` ```sql ` ... ` ``` `) | Language tags supported: `sql`, `json`, `python`, `bash`, `yaml`, and others. |
| Numbered lists | `1.`, `2.`, ... | |
| Bullet lists | `-` or `*` | |
| Links | `[text](url)` | |
| Blockquotes | `>` | One level only. |
| Horizontal rules | `---` | |
| Mentions | `@[userRef]` (canonical token) — see `mentions.md` for the projection | Adapter emits `[~accountid:<id>]` on the markdown path. Wiki-markup mention is the only form Jira Cloud's markdown→ADF converter handles reliably. |

## Likely safe (verify in preview)

Documented as supported in [Atlassian's markdown reference](https://support.atlassian.com/jira/docs/markdown-and-keyboard-shortcuts/) but less thoroughly battle-tested through the MCP converter. Out of the cross-vendor canonical subset; use only when intentional.

| Feature | Markdown syntax |
|---------|------------------|
| Tables | `| col | col |` with the header separator row |
| Strikethrough | `~~text~~` |
| Inline images | `![alt](url)` |
| Nested lists | Indent the child list by two spaces under its parent item |

## Confirmed broken

| Feature | Markdown syntax | What actually happens |
|---------|------------------|------------------------|
| Interactive checkboxes | `- [ ]`, `- [x]` | Render as escaped bracket text inside a bullet list. They are not interactive. Do not use. |

## Forbidden

These either crash the API or render as literal text on the ticket. Avoid them.

| Pattern | Why it fails |
|---------|---------------|
| Raw ADF JSON in a markdown-mode description field | Server tries to parse the JSON as markdown, fails, returns `Failed to convert markdown to adf`. |
| HTML tags (`<details>`, `<summary>`, `<br>`, `<sup>`, etc.) | Escaped to literal text. The angle brackets show up on the ticket. |
| Wiki markup other than `[~accountid:<id>]` mentions (`{code}`, `{panel}`, `h1.`, `||header||`) | Jira Cloud deprecated wiki markup. Renders as literal text. |
| Literal `\n` characters inside the description content (after JSON decoding) | Jira renders them as the two characters backslash-n, not a line break. Build the description with real newlines; the JSON `\n` escape sequence on the wire is a different layer and is handled by the JSON parser before this rule applies. |
| Nested blockquotes (`> > text`) | Inconsistent rendering; some render as a single quote, some as nested. Avoid. |

## ADF content-loss warning (read side)

The MCP converter reads the existing description as ADF and presents a markdown view of it. ADF features that have no markdown equivalent are silently stripped on the way back through. The API does not warn. The user does not see anything go wrong. The content just disappears.

Common features at risk on a typical refinement:

| ADF feature | Frequency |
|-------------|-----------|
| Smart Links (Jira/Confluence URL cards) | Very common |
| `@mentions` of users | Very common |
| Info / Warning / Error panels with content | Common |
| Status lozenges (`In Progress`, `Done`) | Common |
| Expand / collapse sections with content | Common |
| Task lists with checked items | Common |
| Embedded media, attached images, video | Common |
| Date pickers | Common |
| Tables with merged or color-tinted cells | Moderate |
| Multi-column layouts | Moderate |
| Jira issue macros (in Confluence) | Common in Confluence |

Warn the user only when the loss is **substantive** (a panel with real instructions, a task list whose checked state matters, an embedded video, a colored table that conveys data through color). Keep that warning to one sentence outside the preview. A smart-link card becoming a plain URL is cosmetic and does not need a warning.

The adapter does preserve mentions when possible: `@[userRef]` round-trips cleanly if `resolveUser` succeeds on the read side. Otherwise the mention degrades to plain text and the adapter surfaces a one-line warning.
