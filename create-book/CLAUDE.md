# Create Book

A plugin that analyzes source code and produces a comprehensive technical book — the kind a senior engineer would buy to deeply understand a system.

## What it does

`/create-book:create-book <source-dir>` runs a 7-phase workflow:

1. **Exploration** — Parallel agents analyze each major subsystem
2. **Audience & Positioning** — Define the core thesis
3. **Structure** — Organize into parts and chapters, get approval
4. **Writing** — Narrative prose with pseudocode and mermaid diagrams
5. **Editorial Review** — Review agents evaluate quality and consistency
6. **Revision** — Apply all feedback in one pass
7. **Source Code Audit** — Ensure no verbatim code, only patterns

## Output

- `book/docs/` — Markdown chapters
- `book/web/` — Astro website with dark/light mode, mermaid diagram zoom, chapter navigation
