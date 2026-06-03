---
name: draft-with-me
description: "Draft a blog section-by-section from the author's brief, brain dump, and live conversation. Triggers: 'draft with me', 'start drafting', 'draft the blog', 'help me turn this into a draft', 'write the post section by section'. Drafts strictly from material the author provided — never invents claims, opinions, stories, or sources. Each section presented for accept / reject / rewrite / skip / I'll-write-this-one. On pasted images, asks whether they're for the blog and where, then captures them into drafts/<slug>/images/ and inserts markdown references."
---

# Draft With Me

**IMPORTANT — Deferred tool loading:** Before calling `AskUserQuestion`, call `ToolSearch` with query `"select:AskUserQuestion"` to load it. Do this once at the start.

The author's core — their thinking, opinions, stories, scars — lives in the brain dump and the brief. This skill renders that core as prose, one section at a time, with the author in the driver's seat for every sentence that gets kept.

## The golden rule: never invent

The author provided the material. This skill arranges and renders it. It does not:

- Add claims the author didn't make
- Add opinions the author didn't express
- Add stories, quotes, numbers, or sources that aren't in their input
- Smooth over a section by confabulating filler that "sounds right"

If a section in the outline doesn't have enough supporting material, **stop and ask**. Never paper over a gap.

## Inputs

The skill reads, in order of priority:

1. `drafts/<slug>/brief.md` — thesis, audience, takeaway, tone, brain dump (required)
2. `drafts/<slug>/outline.md` — narrative arc (optional; skill improvises if missing)
3. `drafts/<slug>/angle.md` — sharpened unique angle (optional)
4. `drafts/<slug>/draft.md` — existing draft to resume (optional)
5. The live conversation — anything the author says while drafting

If no `<slug>` is passed, list the folders under `drafts/` and ask the author which post this is for.

If `brief.md` doesn't exist, stop and say: _"No brief found. Start with the `blog-brief` skill (say 'start a new blog' or 'I have a brain dump'), or run `/blog-writer:write-blog` to orchestrate from the top."_ Do not try to infer a brief.

## Handling missing outline

If `outline.md` doesn't exist, offer the author a choice via `AskUserQuestion`:

- **Build a deeper outline first** (say 'outline this') — activates the `outline` skill; recommended for longer posts
- **Propose a quick section structure now** — skill reads the brief and brain dump and suggests 3–6 sections with 1-line purposes; author accepts or edits, then drafting begins
- **I'll give you the sections** — author types the section list

If the author chooses the quick structure, propose sections derived from what's in the brain dump, not a template. Do not force a "problem → solution → conclusion" arc if the material doesn't support it.

## The drafting loop

For each section in the outline (or agreed section list):

### 1. Gather material for this section

Before drafting, scan the brain dump + brief + conversation for material relevant to this section's purpose. Explicitly list to the author what material was found:

> "For the section _Why most TDD advice is backwards_, I found these bits in your brain dump:
> - the story about the 6-month ticket backlog
> - the observation about feedback latency as the real bottleneck
> - your quote _'the tests were never the point'_
>
> Drafting from these. Want to add anything else before I write it?"

This gives the author a moment to add a scar, a quote, a data point, or to reshuffle.

**Hard gate:** If the scan returns nothing — or only abstract fragments with no concrete claim, story, or specific — do NOT proceed to step 2. Jump to _When material runs out_ below. Invented filler is worse than a paused loop.

### 2. Draft the section

Write the section in the chosen tone. Draft strictly from the listed material. Keep prose consistent with the tone's voice signals recorded in `brief.md`.

Length follows the material, not a template. A section with three strong points is three paragraphs. A section with one tight observation is one paragraph.

### 3. Present for accept / reject / rewrite / skip / I'll-write-this-one

Show the drafted section. Then `AskUserQuestion`:

- **Accept** — write it to `draft.md` as-is, move on
- **Accept with edits** — author types specific changes; apply them then write
- **Rewrite** — author says what's off (too punchy, too long, missed a point); redraft and present again
- **Skip** — leave this section for later
- **I'll write this one** — author writes the section themselves; skill pastes it in verbatim and moves on

Iterate on rewrite up to 3 rounds. If the author isn't happy after 3, ask what's really wrong — usually the material is thin, the outline is wrong, or the tone doesn't fit. Surface that honestly instead of trying a 4th rewrite.

### 4. Write to draft.md

Once accepted, write or append the section to `drafts/<slug>/draft.md`. Maintain this structure:

```markdown
---
slug: <slug>
title: <leave blank until title-lab runs>
dek: <leave blank until title-lab runs>
thesis: <from brief>
tone: <from brief>
created: <ISO date from brief>
draft_started: <ISO date of first section drafted>
last_updated: <ISO date>
status: drafting
---

# <working title or first-line of thesis>

## <section heading>

<section prose>

## <section heading>

<section prose>

...
```

Use `Edit` to append or update specific sections so earlier-accepted sections don't get rewritten.

## Handling pasted images

Claude Code attaches pasted images to the conversation as multimodal content. The image data is visible in context, but **is not written to disk automatically**. To get an image into the post folder, the author must provide a filesystem path (either to where the image already lives, or by saving it into `drafts/<slug>/images/` themselves).

Not every pasted image is meant for the blog — sometimes the author pastes a screenshot for context while discussing a section. Always ask before placing.

When an image appears in the conversation:

### 1. Acknowledge and describe

State briefly what the image shows ("Looks like a screenshot of a CI pipeline with 3 failed stages"). This confirms to the author that the image was received and lets them correct if the description is off.

### 2. Ask if it's for the blog

`AskUserQuestion`:
- **Yes — put it in the post**
- **No — context only, skip it**

### 3. Ask where it goes

If yes, `AskUserQuestion` with options listing each current section heading plus "Top of the post (hero)" and "Somewhere else — I'll specify."

### 4. Get a filesystem path from the author

`AskUserQuestion` with two paths:

- **"I already have it saved, here's the path"** — author provides an absolute or relative path (e.g., `~/Downloads/pipeline.png` or `./pipeline.png`). Copy it into `drafts/<slug>/images/` with a descriptive kebab-case filename: `cp "<source-path>" "drafts/<slug>/images/<descriptive-name>.png"`. **Always double-quote both paths** — filenames with spaces or special characters will break an unquoted `cp`.
- **"I'll save it into the images folder myself"** — direct the author: _"Drag or save the image into `drafts/<slug>/images/` with a descriptive filename (e.g., `ci-pipeline-failed.png`), then tell me the filename."_ Verify the file exists with `ls drafts/<slug>/images/<filename>` before inserting the markdown reference.

Do not claim to have written the image bytes from the conversation to disk. The bytes only reach disk via the author's action.

### 5. Insert the markdown reference

At the chosen location inside the drafted section, with descriptive alt text derived from what the image shows:

```markdown
![Alt text describing what the image shows](images/descriptive-name.png)
```

Use `Edit` on `draft.md`. Confirm placement to the author with a one-liner before moving on.

## When material runs out

If a section needs material the author never provided, stop. Do not write plausible filler.

Say, specifically:

> "The outline has a section _'what actually fixed our deploy pipeline'_, but I don't have material for it in your brain dump or brief. Can you tell me the story, even in rough form? Or should we cut this section?"

Three recoveries to offer:

- **Fill the gap now** — author talks it through; skill treats that as new material and drafts
- **Reshape the section** — narrow the section to what material exists
- **Cut the section** — update the outline in memory and move on

## Stopping and resuming

Sessions end mid-draft. To resume:

1. Read `draft.md` — already-drafted sections are in there
2. Read `outline.md` (or last-known section list from `draft.md` headings)
3. Identify the next un-drafted or skipped section
4. Ask the author: "Picking up at section _X_. Ready?"

## Finishing

When every section is drafted (or explicitly skipped):

1. Update the `status` field in frontmatter from `drafting` to `drafted`
2. Offer next steps:

> "Draft is complete at `drafts/<slug>/draft.md`. Suggested next:
> - **Line-level polish** (say 'editorial pass' or 'polish the draft') — activates the `editorial-pass` skill.
> - **Challenge claims + research** (say 'knowledge pass' or 'challenge my claims') — activates the `knowledge-pass` skill.
> - **Title it** (say 'title lab' or 'help me find a title') — activates the `title-lab` skill.
>
> Or resume the orchestrator: `/blog-writer:write-blog <slug>`."

## Rules summary

- **Never invent.** Material must come from the author.
- **One section at a time.** Accept / reject / rewrite / skip / I'll-write-this-one on each.
- **Preserve tone.** Read the tone from `brief.md` and stay inside it.
- **Stop at gaps.** Ask for material; don't confabulate.
- **Ask before placing images.** Not every paste is for the blog.
- **Append, don't rewrite.** Use `Edit` to add sections without touching earlier-accepted ones.
