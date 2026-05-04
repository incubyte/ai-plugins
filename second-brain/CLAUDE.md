# Second Brain

A personal knowledge base that builds a compounding wiki from raw documents. Unlike RAG (which retrieves raw docs on every query), the wiki is a persistent, compounding artifact — cross-references are already there, contradictions are already flagged.

## Directory Structure

```
clippings/          <- Raw source documents (immutable, never modified)
wiki/
  index.md          <- Landing page — catalog of all pages with descriptions
  log.md            <- Timeline of ingestions and changes
  concepts/         <- Explanation pages (ideas, patterns, techniques)
  entities/         <- Reference pages (tools, people, orgs, projects)
  summaries/        <- Source summaries (one per ingested document)
```

## Wiki Quality Principles

### Structure
- Clear hierarchy: index -> type (concepts/entities/summaries) -> page
- Page names are lowercase with hyphens: `event-sourcing.md`, `postgresql.md`
- Consistent templates per page type — every concept, entity, and summary follows the same shape

### Content
- One topic per page — split when a page tries to cover two distinct things
- Start with the answer — TL;DR at the top of every page
- Synthesize, don't extract — weave sources together into coherent prose
- Evergreen first — date anything timely ("as of YYYY-MM"), avoid "recently" or "latest"
- Each fact lives in exactly one canonical page — link, don't duplicate

### Discoverability
- `[[wikilinks]]` for all cross-references (Obsidian-compatible)
- Links should be meaningful — link when the target helps the reader, not for every mention
- Tags in frontmatter for multiple paths to the same page
- Index.md as the browsable entry point

### Maintenance
- `updated` date in every page's frontmatter
- Log.md tracks what changed and when
- No stub pages or "coming soon" placeholders — only create a page if you can write a TL;DR and at least two body paragraphs

## Page Frontmatter Schema

```yaml
---
title: Human-Readable Title
type: concept | entity | summary
sources:
  - "[[summaries/source-name]]"
created: YYYY-MM-DD
updated: YYYY-MM-DD
tags: [tag1, tag2]
---
```

## Commands

- `/second-brain:ingest` — Process documents from `clippings/` into wiki pages
- `/second-brain:ask` — Query the wiki, get synthesized answers with `[[citations]]`
- `/second-brain:lint` — Health check: contradictions, orphans, broken links, gaps

## Principles

- **Clippings are immutable.** Never modify source documents.
- **Wiki compounds.** Each ingestion deepens existing pages, not just adds new ones.
- **LLM handles bookkeeping.** Cross-references, index, conflict detection.
- **Humans curate sources and ask questions.**
