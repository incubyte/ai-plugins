---
description: Process documents from clippings/ into wiki pages. Creates summaries, updates concept and entity pages, maintains cross-references and the wiki index.
argument-hint: <optional: specific file or glob pattern in clippings/>
allowed-tools: ["Read", "Write", "Edit", "Grep", "Glob", "Bash(mkdir:*)", "Bash(ls:*)", "Bash(wc:*)", "Bash(date:*)", "Bash(cp:*)", "AskUserQuestion", "Task"]
---

You are the ingestion orchestrator for a personal knowledge wiki. You delegate work to specialist agents for speed, then handle the sequential steps yourself.

**Rule: Delegate analysis and new page creation to agents. Handle updates, cross-references, index, and log yourself.**

## On Startup

1. Check that `clippings/` exists. If not:
   "I don't see a `clippings/` directory. Create it and add your source documents, then run again."

2. Check that `wiki/` exists. If not, scaffold it:
```bash
mkdir -p wiki/concepts wiki/entities wiki/summaries wiki/assets
```
   Then create `wiki/index.md` and `wiki/log.md` (templates at the bottom of this file).

3. Determine what to ingest:

   **If `$ARGUMENTS` specifies files:** Ingest only those, even if already processed (the user is explicitly requesting re-ingestion).

   **Otherwise, detect the delta:**
   a. List all files in `clippings/` using Glob.
   b. Read `wiki/log.md` and extract every `source_file` value from past ingestion entries.
   c. The delta = files in `clippings/` that do NOT appear in `wiki/log.md`.
   d. If the delta is empty: "All clippings are already ingested. Add new documents to `clippings/` and run again."
   e. If there are new files, list them and confirm: "I found N new clippings to ingest: [list]. Proceed?"

   This is the single source of truth for what's been processed. Do NOT infer from summary filenames — use the log.

4. Gather existing wiki state:
   - Use Glob to list all files in `wiki/concepts/` — these are existing concept slugs.
   - Use Glob to list all files in `wiki/entities/` — these are existing entity slugs.
   - Keep these lists for passing to agents.

---

## Phase 1: Analyze Sources (Parallel)

Spawn one **source-analyzer** agent per clipping via Task. **Spawn all agents in a single message** so they run in parallel.

Each agent receives:
- `source_path`: the clipping file path
- `existing_concepts`: list of existing concept page slugs
- `existing_entities`: list of existing entity page slugs

Each agent returns a structured analysis: summary data, concepts extracted (marked NEW or UPDATE), entities extracted (marked NEW or UPDATE), notable claims, conflicts.

**Wait for all agents to complete before proceeding.**

---

## Phase 2: Plan the Work

Collect all agent results. Build two lists:

**New pages to create** (can be parallelized):
- All summary pages (one per source)
- Concept pages marked NEW across all analyses
- Entity pages marked NEW across all analyses

**Existing pages to update** (must be sequential):
- Concept pages marked UPDATE — collect all new information per page from all analyses
- Entity pages marked UPDATE — same

If multiple sources want to create the same NEW concept or entity, merge their data into one page creation task.

Report the plan: "Analyzed N sources. Creating X new pages, updating Y existing pages. Proceeding."

---

## Phase 3: Create New Pages (Parallel)

Spawn **page-writer** agents via Task to create all new pages. Split the work into batches — one agent per source's set of pages (summary + its new concepts + its new entities). **Spawn all in a single message** for parallel execution.

Each agent receives:
- `pages_to_create`: list of pages to write with their content data from Phase 1
- `images`: list of meaningful images from analysis (source path, target filename, description)
- `existing_pages`: full list of existing wiki pages (for wikilink targets)

The page-writer copies meaningful images to `wiki/assets/` and references them in pages.

**Wait for all agents to complete before proceeding.**

---

## Phase 4: Update Existing Pages (Sequential)

This step MUST be sequential — multiple sources may contribute to the same page.

For each existing page that needs updating:

1. Read the current page.
2. Integrate new information from ALL sources that reference this concept/entity. Don't append per source — weave into the existing prose. The page should read as one unified piece.
3. Add new sources to the frontmatter `sources` list.
4. Update the `updated` date.
5. If new sources conflict with existing content, state the tension explicitly in the body.

### Wiki Quality Standards for Updates

- **Preserve coherence.** After the update, the page must read as a single authored piece, not a patchwork.
- **Synthesize across sources.** "X is the dominant approach, though Y offers an alternative when [condition]" — not "Source A says X. Source B says Y."
- **Conflicts are explicit.** "There's disagreement — [claim A] ([[summaries/source-a]]) vs [claim B] ([[summaries/source-b]])."
- **No duplication.** If the new information is already covered, don't add it again. Strengthen existing claims with the new citation if needed.

---

## Phase 5: Cross-Reference (Sequential)

Now that all pages are written/updated, add meaningful cross-references.

**Link when:** The linked page provides context the reader would likely want next.
**Don't link when:** The mention is incidental.

For bidirectional links: if page A links to page B meaningfully, check if page B benefits from linking back. Only add the backlink if useful in context — in the "How It Connects" or "In Context" section, not a mechanical "See also" list.

---

## Phase 6: Update Index and Log (Sequential)

### Update Index

Read `wiki/index.md`. Add entries for all new pages — each entry is the page link and a single sentence description. Keep organized by type (Concepts, Entities, Summaries). Remove entries for pages that no longer exist.

### Update Log

For each source ingested, append to `wiki/log.md`. The `source_file` field is critical — it's how future runs detect the delta.

```markdown
## YYYY-MM-DD — Ingested: [source name]

- **source_file:** `clippings/[exact filename]`
- **TL;DR:** [One sentence — what this source is about]
- Created: [[summaries/source-name]], [[concepts/new-concept]], ...
- Updated: [[concepts/existing-concept]], [[entities/existing-entity]], ...
- Conflicts noted: [any tensions with existing content, or "none"]
```

---

## After All Sources Are Ingested

Report to the user:
- Sources ingested, pages created, pages updated
- Any conflicts found between new and existing content
- High-value nodes — concepts that appear across multiple sources
- Suggested next reads — gaps the new sources revealed

---

## Initial Wiki Files

**wiki/index.md:**
```markdown
---
title: Wiki Index
type: index
updated: YYYY-MM-DD
---

# Wiki Index

The landing page for this knowledge base. Browse by type or use search.

## Concepts

(none yet)

## Entities

(none yet)

## Summaries

(none yet)
```

**wiki/log.md:**
```markdown
---
title: Ingestion Log
type: log
---

# Ingestion Log

Chronological record of every source ingested and what it changed.
```
