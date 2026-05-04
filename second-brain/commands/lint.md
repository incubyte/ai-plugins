---
description: Health check the wiki. Finds contradictions, stale claims, orphaned pages, broken links, and suggests gaps to fill.
allowed-tools: ["Read", "Edit", "Grep", "Glob", "Bash(wc:*)", "Bash(date:*)", "AskUserQuestion", "Task"]
---

You are running a health check on a personal wiki in `wiki/`. Your job is to find problems and suggest improvements.

## On Startup

Check that `wiki/` exists and has pages beyond index.md and log.md. If empty: "The wiki is empty. Run `/second-brain:ingest` first."

## Health Checks

Run all checks, then present a unified report.

### 1. Broken Links

Use Grep to find all `[[wikilinks]]` across the wiki. For each link, verify the target page exists (Glob for matching files). Report any broken links with the page they appear on.

### 2. Orphaned Pages

Find pages that are not linked to from any other page (except index.md). These are isolated knowledge that should be connected or may indicate a gap in cross-referencing.

Use Glob to list all wiki pages, then Grep to check which ones are referenced by at least one other page.

### 3. One-Way Links

Find cases where page A links to page B, but page B doesn't link back to page A. Bidirectional linking is a wiki convention — flag missing backlinks.

### 4. Contradictions

Read pages that share tags or cover related topics. Look for claims that contradict each other. For example:
- Page A says "X uses approach Y"
- Page B says "X uses approach Z"

Flag these with the specific conflicting claims and the pages involved.

### 5. Stale Content

Check the `updated` date in frontmatter. Flag pages that haven't been updated in a long time relative to their sources. If new sources have been ingested that touch the same topic, the page may need updating.

### 6. Thin Pages

Find pages with very little content (fewer than 5 lines of body text). These may be stubs that need expansion or pages that should be merged into a related page.

### 7. Index Gaps

Compare pages that exist in `wiki/concepts/`, `wiki/entities/`, and `wiki/summaries/` against entries in `wiki/index.md`. Flag any pages missing from the index.

### 8. Knowledge Gaps

Based on the topics covered, suggest areas where adding new sources would strengthen the wiki. Look for:
- Concepts referenced but never explained
- Entities mentioned without their own page
- Topics where only one source provides information (single point of failure)

## Report Format

Present findings grouped by severity:

**Issues to Fix:**
- Broken links (list each with location)
- Index gaps (pages not in index.md)

**Improvements:**
- One-way links to make bidirectional (list each pair)
- Orphaned pages to connect
- Thin pages to expand or merge

**Observations:**
- Contradictions found (with specific claims)
- Stale pages that may need refreshing

**Suggested Next Steps:**
- Knowledge gaps to fill (with suggested source types)
- New questions to investigate

## After the Report

Ask: "Want me to fix the mechanical issues (broken links, index gaps, missing backlinks)?"

Options:
- "Yes, fix them (Recommended)" — Fix broken links (remove or correct), update index.md, add missing backlinks. Do NOT resolve contradictions automatically — those need human judgment.
- "No, just the report" — Done.
