---
name: postmortem-writer
description: "Generates a full incident postmortem markdown document from a cached timeline (built by incident-timeline-builder) and the source materials gathered during investigation. Uses a Google-SRE-style blameless template by default. Produces the postmortem as plain markdown text for the caller to render or save; the skill itself never writes to disk or posts anywhere. Use when the azure-incident-postmortem agent reaches Phase 4, or when a user has a structured timeline and wants the full document."
metadata:
  author: Taha Bikanerwala
tools: Read
---

# Postmortem Writer

Take a cached timeline (already built by `incident-timeline-builder`) and the original source materials, and produce the full postmortem document as a single block of markdown. The output uses the Google-SRE-style blameless template by default; future plugin releases may add other templates, but v0.1.0 ships only this one.

This skill writes prose. It does not gather evidence (the agent does that in Phase 1), reconstruct the timeline (`incident-timeline-builder` does that in Phase 2), or render the output to the user (the agent does that in Phase 5). Its job is the document.

## Calling Convention

The skill runs without user interaction. It produces a single markdown document as its only output.

- **Non-interactive.** Never ask the user a question. Inputs are inferred from the payload the caller provides.
- **Predictable structure.** The output always carries every section in the template (in the order documented in `references/postmortem-template.md`). Sections with no source data collapse into a one-line placeholder rather than disappearing — the structure is intentional even when data is sparse.
- **Same evidence tags as the rest of the marketplace.** `[VERIFIED]`, `[OBSERVED]`, `[INFERRED]`, `[UNKNOWN]`. The skill applies these inline where claims are made (especially in Root Cause and Contributing Factors).
- **Read-only.** No file writes, no posting. The agent in Phase 4 consumes the markdown and runs `prose-style` on it before Phase 5 renders it.
- **Output is the last thing.** Skill ends after the markdown renders. No follow-up prompts.

## Setup

**Read `references/postmortem-template.md` before generating.** It is the canonical section catalog: header structure, what belongs in each section, when to emit a placeholder vs. omit a section, and the section-by-section writing rules.

Do not start writing until the reference is loaded.

## Input Payload Shape

The caller passes a payload describing the incident, the cached timeline (a markdown table from `incident-timeline-builder`), and the source materials in their original (un-summarized) form so the writer can quote directly:

```
{
  "incident": {
    "id": "12345",
    "url": "...",
    "title": "...",
    "created_at": "2026-04-29T14:32:00Z",
    "resolved_at": "2026-04-29T16:08:00Z",
    "severity": "1 - Critical",
    "reporter": "@alice",
    "responders": ["@bob", "@carol"],
    "customer_impact_summary": "All US-region property managers could not process rent payments for 96 minutes."
  },
  "timeline_markdown": "| Time (UTC) | Event | Source | Tag |\n| ... |",
  "source_materials": {
    "teams_messages": [...],
    "azdo_work_items": [...],
    "datadog_logs": [...],
    "azure_repos_prs": [...]
  },
  "config": {
    "postmortem_template": "google-sre",
    "include_action_items": true,
    "include_timeline_evidence_links": true
  }
}
```

The `incident` block fields beyond `id`, `url`, and `title` are optional. The skill fills missing fields with `[UNKNOWN]` placeholders rather than guessing. `customer_impact_summary` in particular is often a synthesis the agent provides; when absent, the skill assembles a draft from the timeline's first user-visible event and tags it `[INFERRED]`.

## Workflow

The skill runs four ordered steps.

### Step 1: Read the template reference

Load `references/postmortem-template.md`. The reference is the source of truth for section headings (verbatim), section order, per-section content rules, and placeholder text for empty sections.

### Step 2: Build the header

Render the YAML-style header block at the top of the document with these fields (in this order):

```
# Incident Postmortem: {title} ({YYYY-MM-DD})

**Status:** Draft
**Author:** {author display name or "Unknown"}
**Severity:** {severity}
**Duration:** {created_at} to {resolved_at} ({duration in minutes or hours})
**Detection:** {how the incident was detected — derived from the first non-deploy event in the timeline, or [UNKNOWN] when not derivable}
**Customer impact:** {customer_impact_summary, or a one-line synthesis from the timeline}
```

Set `Status: Draft` always; the user changes it to `Approved` or `Reviewed` after the doc has been read by stakeholders.

### Step 3: Populate the body sections

Walk the section catalog in `references/postmortem-template.md` in order and emit each section. For each section, apply the per-section content rules from the reference:

- **Source-grounded sections** (Summary, Impact, Detection, Resolution): synthesize from the source materials and the timeline. Quote directly when a Teams message or work-item comment captures the moment well.
- **Evidence-tagged sections** (Root Cause, Contributing Factors): every claim carries `[VERIFIED]`, `[OBSERVED]`, `[INFERRED]`, or `[UNKNOWN]` inline. Never present unverified analysis as confirmed root cause.
- **Reflection sections** (What Went Well, What Went Wrong, Lessons Learned): synthesize patterns from the timeline. These are often the thinnest sections at draft time; add a one-line note where evidence is sparse.
- **Operational sections** (Timeline, Action Items, References): structured tables or lists. Drop in the cached `timeline_markdown` for Timeline; build References from the source materials' URLs.

### Step 4: Render the full markdown

Concatenate the header and the populated sections into a single markdown document. Add no preamble, no trailing summary, no commentary. The output is the document; the agent or user will render or save it.

When `config.include_action_items` is `false`, omit the Action Items section header entirely and adjust the section numbering in the table of contents (when one is present, which the v0.1.0 template doesn't ship by default).

When `config.include_timeline_evidence_links` is `false`, the Timeline section's table is rendered with an empty Source column. (The cached `timeline_markdown` already includes the source links; the skill must rewrite the table to drop the column when this flag is false. Use the table's column-count as the only signal that needs adjusting.)

## Anti-Patterns

These are hard rules. Each one prevents a failure mode that has been observed on real postmortem drafts.

1. **Never present unverified analysis as confirmed root cause.** Frame it as a working hypothesis in Contributing Factors, with `[INFERRED]` or `[OBSERVED]` tags. The Root Cause section is reserved for `[VERIFIED]` causes — anything else belongs lower.
2. **Never blame an individual.** The template is blameless: name actors when they took an action ("@bob reverted PR !4567 at 14:48"), but never frame an action as fault ("@bob's PR !4567 caused the outage" → "PR !4567 introduced the regression" — the actor's name moves out of the cause attribution).
3. **Never invent timeline events.** The Timeline section is the cached `timeline_markdown` verbatim. Do not add events the timeline-builder didn't produce.
4. **Never fabricate impact numbers.** When `customer_impact_summary` is missing and the timeline doesn't ground a count, write `[UNKNOWN]` or "scope not measured at incident time" rather than guess.
5. **Never weaken Root Cause with hedging.** "May have potentially contributed to" when the evidence supports "caused" defeats the document's purpose. Commit when the evidence supports it; downgrade to Contributing Factors when it doesn't.
6. **Never include action items as prescriptive recommendations from the agent.** The template ships an empty Action Items table for the user to fill in (with optional placeholder rows derived from "What Went Wrong"). The agent does not assign owners or target dates without explicit user input.
7. **Never mention an integration that returned no results.** If Datadog gathering came back empty, the Detection section says "Detection method: monitoring alert (specifics not gathered)" rather than "Datadog dashboards (no results found)."
8. **Never put references in the body.** External URLs go in the References section at the end; inline citations (in Timeline source links and Root Cause evidence quotes) are exceptions where the URL is part of the claim.

## Writing Style

These rules apply to everything this skill produces.

- No em dashes or spaced hyphens as separators. Restructure.
- No LLM vocabulary: delve, leverage, robust, seamlessly, comprehensive, nuanced, elevate, foster, paradigm, ecosystem, holistic, innovative, synergy, empower, facilitate.
- Lead with the answer. No opener phrases.
- No trailing summaries on short sections.
- Prose over bullet lists when the content flows naturally as sentences. The Lessons Learned section is prose; What Went Well and What Went Wrong are bullets (each item is a discrete observation).
- Quote source text directly with quotation marks when paraphrasing risks losing meaning.
- The agent runs `prose-style` on the final output (Phase 4); these rules are the floor.
