# Azure DevOps HTML Formatting Reference

Read this when you reach Step 5 (Apply the Template). Skip it on earlier steps.

Azure DevOps stores work-item description (`System.Description`) and discussion comments as **HTML**. The API does not perform markdown-to-HTML conversion: whatever you write into `System.Description` is rendered as-is. Convert the markdown rewrite to a safe HTML subset before calling `wit_update_work_item` or `wit_add_work_item_comment`.

## API Format Rule

`wit_update_work_item` accepts a JSON Patch document. The operation that writes the description looks like this (literal HTML inside the `value` field):

```json
[
  { "op": "add", "path": "/fields/System.Title",       "value": "VMS: Visitor notifications not sending for scheduled visits" },
  { "op": "add", "path": "/fields/System.Description", "value": "<h2>Summary</h2><p>Visitor notifications stop sending...</p>" }
]
```

The HTML string must be syntactically valid. AzDO will accept malformed HTML up to a point but the rendered output is unpredictable. Run any unfamiliar tags through the safe-subset table below before emitting.

For comments, `wit_add_work_item_comment` takes an HTML string in its `text` parameter (the field is sometimes named `comment` or `body` depending on the MCP tool's input shape; check the tool schema). Comments support the same safe-subset HTML.

## Markdown-to-HTML Conversion

When the rewrite produces markdown (the natural authoring format), translate to HTML using this mapping. The skill emits HTML; the markdown form shown is the upstream representation, not what gets sent.

| Markdown | HTML | Notes |
|----------|------|-------|
| `# Heading 1` | `<h1>Heading 1</h1>` | AzDO renders all heading levels. Prefer `<h2>` as the highest level inside a description body so the work-item title remains the visual H1. |
| `## Heading 2` | `<h2>Heading 2</h2>` | |
| `### Heading 3` | `<h3>Heading 3</h3>` | |
| `**bold**` | `<strong>bold</strong>` | |
| `*italic*` | `<em>italic</em>` | |
| `` `code` `` | `<code>code</code>` | |
| Fenced code block (```` ```sql ... ``` ````) | `<pre><code class="language-sql">...</code></pre>` | AzDO does not syntax-highlight by language tag; the class attribute is preserved but ignored visually. |
| `- item` (bullet list) | `<ul><li>item</li></ul>` | |
| `1. item` (numbered list) | `<ol><li>item</li></ol>` | |
| `[text](url)` | `<a href="url">text</a>` | URL must be `http://`, `https://`, `mailto:`, or a relative work-item link. Unsupported schemes are stripped. |
| `> quote` | `<blockquote>quote</blockquote>` | |
| `---` (horizontal rule) | `<hr/>` | |
| Tables | `<table>...</table>` with `<thead>`, `<tbody>`, `<tr>`, `<th>`, `<td>` | Plain HTML table. AzDO renders cleanly. |
| Inline image `![alt](url)` | `<img src="url" alt="alt"/>` | URL must be either an attachment URL on the same work item or an absolute https URL. Hot-linking arbitrary external images works but may break later. |

Inline newlines inside a paragraph are not preserved; use `<br/>` if a line break inside a paragraph is intentional, or split into separate `<p>` blocks.

## Safe HTML Subset

These tags are confirmed safe for `System.Description` and discussion comments. Use them freely.

| Tag | Purpose |
|-----|---------|
| `<h1>` through `<h6>` | Section headings. Prefer `<h2>` as the top heading inside a description. |
| `<p>` | Paragraph wrap. Use one `<p>` per logical paragraph. |
| `<strong>`, `<em>`, `<u>`, `<s>` | Inline emphasis. `<u>` and `<s>` are uncommon; use sparingly. |
| `<code>`, `<pre>` | Inline and block code. Combine for code blocks: `<pre><code>...</code></pre>`. |
| `<ul>`, `<ol>`, `<li>` | Bullet and numbered lists. Nest by placing a child `<ul>`/`<ol>` inside an `<li>`. |
| `<a href="...">` | Hyperlinks. URL schemes restricted to `http`, `https`, `mailto`, and relative work-item paths. |
| `<blockquote>` | Block quotes. Avoid nesting; AzDO does not always render nested blockquotes consistently. |
| `<hr/>` | Horizontal rule. |
| `<br/>` | Forced line break. Prefer separate `<p>` blocks for paragraph breaks. |
| `<table>`, `<thead>`, `<tbody>`, `<tr>`, `<th>`, `<td>` | Tables. AzDO does not enforce a header row, but using `<thead>` improves screen-reader rendering. |
| `<img src="..." alt="..."/>` | Inline images. Source restricted to attachment URLs or absolute https. |

## Forbidden

These tags either get sanitized away, render as literal text, or break the API call. Avoid them.

| Pattern | Why it fails |
|---------|---------------|
| `<script>`, `<iframe>`, `<object>`, `<embed>`, `<form>` | Stripped by AzDO's HTML sanitizer. The patch may also be rejected outright. |
| Inline event handlers (`onclick`, `onerror`, etc.) | Stripped. Treat as forbidden. |
| `style` attributes carrying scripts (`expression(...)`, `javascript:` URLs) | Stripped or rejected. Use plain CSS class names if any styling is needed; AzDO ignores most inline `style` rules. |
| `<details>`, `<summary>` | Render inconsistently. Some org-level templates strip them. Avoid for portability. |
| Raw markdown characters in `System.Description` | Rendered verbatim. The user sees `# Summary` instead of an H1 heading. Convert markdown to HTML before writing. |
| Smart quotes (`"`, `"`, `'`, `'`) and em dashes inside HTML | Render fine but are AI-style tells; the writing-style rule applies regardless of format. |
| Wiki markup (Confluence-style `{panel}`, `{code}`, MediaWiki `==Heading==`) | AzDO does not parse it. Renders as literal text. |

## HTML Content-Loss Warning

The fetched description is HTML. When you read it, certain HTML constructs are awkward to round-trip through a markdown rewrite:

| Construct | Frequency | What happens on the round trip |
|-----------|-----------|-------------------------------|
| Inline images (`<img src="...attachment-url..."/>`) | Common | The image URL survives as a markdown image, then re-converts to `<img>` on write. Safe in practice. |
| `@mentions` of users (rendered as `<a href="..." data-vss-mention="...">@User Name</a>`) | Common | Markdown does not represent the mention metadata. The plain @ + name remains visible; the link to the user profile is lost. Warn the user when a mention carries assignment intent. |
| Color-tinted callouts (`<div style="background-color: ...">`) | Moderate | The color is lost (style attributes are stripped on most templates). Surface the callout text in a regular paragraph or blockquote. |
| Embedded videos and media | Rare on AzDO; more common when migrated from other systems | Often appear as a thumbnail link. Markdown preserves the link, the inline preview is lost. |
| Multi-column layouts (custom HTML using nested `<table>` for layout) | Rare | Restructure as flat sections. Layout tables convey nothing useful in a refined description. |
| Existing `<script>` or `<style>` blocks | Rare | Already stripped on display; safe to drop entirely. |

Warn the user only when the loss is **substantive** (a callout containing real instructions, a video that demonstrates a workflow, a colored table that conveys data through color). Keep that warning to one sentence outside the preview. A thumbnail becoming a plain link is cosmetic.
