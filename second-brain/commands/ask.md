---
description: Query the wiki. Searches relevant pages, synthesizes an answer with [[citations]] and Obsidian deep links to sources.
argument-hint: <your question>
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash(basename:*)", "Bash(wc:*)", "Bash(date:*)", "Bash(pwd:*)", "Bash(open:*)", "Bash(mkdir:*)", "Bash(base64:*)", "Bash(file:*)", "AskUserQuestion"]
---

You are answering questions using a personal wiki as your knowledge base. The wiki lives in `wiki/` and contains concept pages, entity pages, and source summaries — all interlinked with `[[wikilinks]]`.

## On Startup

1. If `$ARGUMENTS` is empty, ask: "What would you like to know?"
2. Check that `wiki/` exists and has content. If not: "The wiki is empty. Run `/second-brain:ingest` first to process your clippings."
3. Determine the Obsidian vault name — it's the name of the parent directory that contains `wiki/`. Use Bash: `basename "$(pwd)"`. Store this for building deep links.

## Answering a Question

Use your judgment to find relevant information. You have full access to the wiki — read whatever you need. Some approaches:

- **Start with the index.** Read `wiki/index.md` to see what pages exist and find relevant ones by title/description.
- **Search by keyword.** Use Grep to find pages mentioning key terms from the question.
- **Follow the links.** Once you find a relevant page, follow its `[[wikilinks]]` to related pages. The wiki's cross-references are its superpower — use them.
- **Check summaries.** If the question is about a specific source, go straight to `wiki/summaries/`.
- **Read broadly if needed.** For synthesis questions ("how does X relate to Y?"), you may need to read several pages.

**Track every page you read and use in your answer.** You need this for the sources section.

## Response Format

### Answer

Answer the question directly in prose. Cite inline with `[[wikilinks]]` where relevant.

Flag uncertainty: if the wiki doesn't cover something, say what's missing and suggest what to add to `clippings/`.

Surface connections: if answering revealed a cross-cutting pattern, call it out.

### Sources

After the answer, print a **Sources** section. For every wiki page that contributed to the answer, list it with an Obsidian deep link.

**Obsidian deep link format:**
```
obsidian://open?vault={vault_name}&file={path}
```

Where:
- `{vault_name}` is the parent directory name (from startup step 3)
- `{path}` is the file path relative to the vault root, URL-encoded (spaces become `%20`, slashes become `%2F`), WITHOUT the `.md` extension

**Example sources section:**

```markdown
---

### Sources

| Page | Link |
|------|------|
| [[concepts/event-sourcing]] | [Open in Obsidian](obsidian://open?vault=kb&file=wiki%2Fconcepts%2Fevent-sourcing) |
| [[entities/postgresql]] | [Open in Obsidian](obsidian://open?vault=kb&file=wiki%2Fentities%2Fpostgresql) |
| [[summaries/distributed-systems-article]] | [Open in Obsidian](obsidian://open?vault=kb&file=wiki%2Fsummaries%2Fdistributed-systems-article) |
```

If the answer also traces back to original clippings (via summary page frontmatter `source_file`), include those too:

```markdown
| Source: Distributed Systems Article | [Open in Obsidian](obsidian://open?vault=kb&file=clippings%2Fdistributed-systems-article) |
```

**URL encoding rules:** Replace spaces with `%20`, slashes with `%2F`. Drop the `.md` extension. Keep hyphens, lowercase letters, and numbers as-is.

## After the Answer

Once the answer and sources are presented, offer two follow-up options via AskUserQuestion:

"What would you like to do with this?"

Options:
- "Create a presentation (Recommended)" — Proceed to the Presentation Flow below
- "Save as a wiki page" — Write to `wiki/concepts/[topic].md` with proper frontmatter, wikilinks, and source references. Update `wiki/index.md` and add cross-references to cited pages. Only offer this if the answer contains novel synthesis.
- "I'm done" — Done.

---

## Presentation Flow

### Step 1: Audience

Use AskUserQuestion. Recommend the most likely audience based on the content — if the answer is technical, recommend engineers; if it's strategic, recommend leadership.

"Who are you presenting this to?"

Options (tailor to the answer's content):
- "[Most likely audience] (Recommended)" — e.g., "Engineering team", "Leadership / stakeholders", "Client / external audience"
- "[Second likely audience]"
- "[Third option]"

### Step 2: Length

Use AskUserQuestion:

"How long should the presentation be?"

Options:
- "5 minutes / 5-7 slides (Recommended)" — Tight and focused
- "10 minutes / 10-12 slides" — Room for depth
- "Lightning talk / 3 slides" — Elevator pitch

### Step 3: Generate the Presentation

Create a single, standalone HTML file. Save to `presentations/[topic-slug].html`. Create the `presentations/` directory if it doesn't exist.

```bash
mkdir -p presentations
```

The HTML must be **fully self-contained** — no external CSS, JS, font, or image dependencies. Everything inline. It should look polished when opened in a browser.

**Design principles:**
- Clean, modern slide deck aesthetic
- One idea per slide — no walls of text
- Large readable type (min 24px for body, 36px+ for headings)
- High contrast — dark text on light background or light text on dark
- Subtle accent color derived from the content's theme
- Smooth slide transitions via keyboard (arrow keys) or click
- Slide counter ("3 / 7") in the corner
- Sources slide at the end with Obsidian deep links

**Slide structure:**
1. **Title slide** — Topic, one-line subtitle, date
2. **Context slide** — Why this matters, framed for the audience
3-N. **Content slides** — One key point per slide. Use short phrases, not paragraphs. Add a supporting detail or example beneath the headline. Use diagrams (inline SVG) where a visual beats text. When a claim or concept originates from a source with a web URL, make the relevant text a clickable hyperlink to the original — don't add a separate citation, just make the existing words the link. For example: `<a href="https://...">Event sourcing eliminates the impedance mismatch</a>` instead of adding "[1]" footnotes.
N+1. **Takeaways slide** — 2-3 bullet points, what to remember
N+2. **Sources slide** — Wiki pages and clippings used, with Obsidian deep links

**Images in slides:**

Before generating the HTML, scan the wiki pages used in the answer for image references (`![alt](../assets/filename)`). For each image:

1. Determine the MIME type:
```bash
file --mime-type -b wiki/assets/[filename]
```

2. Encode as base64:
```bash
base64 -i wiki/assets/[filename]
```

3. Embed in the HTML as a data URI:
```html
<img src="data:[mime-type];base64,[encoded-data]" alt="[description]" />
```

Place images on the slide where they illustrate the point being made. Size them appropriately — max-width 80% of the slide, centered. If an image is the main point of a slide, make it large. If it's supporting, keep it smaller alongside the text.

Only include images that add value to the presentation. Skip images that don't make sense without the full wiki page context.

**Inline source links on content slides:**

Before generating slides, read the summary pages cited in the answer. Extract `source_url` from their YAML frontmatter. Build a map of summary slug -> web URL.

On content slides, when a claim or phrase traces back to a source that has a web URL, make that text a clickable `<a href="...">` link. Don't add footnotes or citation numbers — the link IS the citation. The reader clicks the phrase to see the original source.

Style inline links subtly — same color as body text with a dotted underline, so they don't dominate the slide but are clearly clickable. On hover, show the full URL in the browser status bar.

If a source has no web URL (local-only clipping), don't link it — the Obsidian deep links on the Sources slide cover those.

**The HTML must include:**
- Inline CSS in a `<style>` block
- Inline JS for keyboard navigation (left/right arrows, click to advance)
- All slides as `<section>` elements, shown/hidden via JS
- All images as base64 data URIs (no external file references)
- Inline `<a>` links to original web sources on content slides
- Print-friendly: `@media print` styles that show all slides

### Step 4: Open the Presentation

```bash
open presentations/[topic-slug].html
```

Tell the user: "Presentation saved to `presentations/[topic-slug].html` and opened in your browser. Use arrow keys to navigate."
