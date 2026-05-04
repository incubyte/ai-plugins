# Second Brain

A Claude Code plugin that builds a compounding personal wiki from raw documents. Inspired by [Karpathy's LLM Wiki pattern](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f).

Instead of retrieving raw documents on every query (RAG), Second Brain incrementally builds and maintains a structured wiki — cross-references are already there, contradictions are already flagged, and knowledge compounds with every source you add.

## How It Works

```
clippings/          ← Drop your source docs here (articles, notes, PDFs)
wiki/
  index.md          ← Browsable catalog of everything
  log.md            ← What was ingested and when
  concepts/         ← Ideas, patterns, techniques
  entities/         ← Tools, people, orgs, projects
  summaries/        ← One per source document
  assets/           ← Images from sources
presentations/      ← Generated slide decks
```

The wiki is Obsidian-compatible — all cross-references use `[[wikilinks]]`, pages have YAML frontmatter, and images are stored locally.

## Commands

### `/second-brain:ingest`

Processes new documents from `clippings/` into wiki pages.

```
/second-brain:ingest                    # Ingest all new clippings (delta only)
/second-brain:ingest clippings/foo.md   # Ingest a specific file
```

- Detects the delta via `wiki/log.md` — only processes new clippings
- Runs parallel agents for analysis and page creation
- Creates summaries, concept pages, and entity pages
- Updates existing pages when new sources add to a topic
- Copies meaningful images (diagrams, charts) to `wiki/assets/`
- Flags conflicts when sources disagree

### `/second-brain:ask`

Queries the wiki and synthesizes an answer with citations.

```
/second-brain:ask What is event sourcing and when should I use it?
```

- Searches the wiki using its judgment (index, grep, link-following)
- Answers with inline `[[wikilinks]]` citations
- Prints a Sources table with clickable Obsidian deep links
- Offers to save novel synthesis as a new wiki page
- Offers to generate a presentation from the answer

### `/second-brain:lint`

Health check for wiki quality.

```
/second-brain:lint
```

Finds: broken links, orphaned pages, one-way links, contradictions, stale content, thin pages, index gaps, knowledge gaps. Offers to auto-fix mechanical issues.

## Getting Started

1. Install the plugin:
   ```bash
   claude --plugin-dir /path/to/second-brain
   ```

2. Create a `clippings/` directory and add your source documents (markdown, text, HTML).

3. Run `/second-brain:ingest` to build the wiki.

4. Run `/second-brain:ask` to query your knowledge base.

5. Open the `wiki/` directory in Obsidian to browse visually.

## Presentations

When you ask a question, Second Brain can generate a standalone HTML slide deck from the answer. The presentation:

- Is a single self-contained HTML file (no external dependencies)
- Embeds images as base64 data URIs
- Has keyboard navigation (arrow keys)
- Includes a sources slide with Obsidian deep links
- Is tailored to your chosen audience and length

## Wiki Quality

Every page follows strict quality standards:

- **TL;DR first** — 1-2 sentences at the top of every page
- **One topic per page** — no stubs, no mega-pages
- **Synthesis over extraction** — weaves sources together, doesn't copy
- **Meaningful links** — only links that help the reader, not every mention
- **Evergreen content** — timely claims are dated, no "recently"
- **No duplication** — each fact lives in one canonical page
