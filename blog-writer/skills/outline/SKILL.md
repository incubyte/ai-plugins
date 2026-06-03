---
name: outline
description: "Turn brief + angle into a narrative arc — section order, section purposes, and where the author's material lands. Triggers: 'outline this', 'structure the post', 'build the outline', 'what sections', 'outline my blog', 'help me structure this'. Proposes 3–6 sections derived from the brain dump, thesis, and tone; iterates with the author until the arc feels right; writes drafts/<slug>/outline.md. Drafting runs on this outline but can also proceed without it if the author prefers."
---

# Outline

**IMPORTANT — Deferred tool loading:** Before calling `AskUserQuestion`, call `ToolSearch` with query `"select:AskUserQuestion"` to load it. Do this once at the start.

An outline isn't a table of contents. It's a decision about what the reader feels at each point in the post — tension at the opening, recognition by the middle, resolution at the close. Get that shape right and the prose almost writes itself.

## Why this matters

Most drafts fail at the arc, not at the sentences. A punchy paragraph in the wrong section is invisible; a decent paragraph in the right section lands. The outline is where the author decides the shape before investing prose effort.

## Inputs

- `drafts/<slug>/brief.md` — required. Thesis, audience, tone, brain dump.
- `drafts/<slug>/angle.md` — optional but preferred. If present, the outline shapes around the angle rather than the bare thesis.

If no `<slug>` passed, list `drafts/*/` and ask. If `brief.md` missing, stop and say: _"No brief found. Start with the `blog-brief` skill (say 'start a new blog') or run `/blog-writer:write-blog` to orchestrate from the top."_

## Arc shapes by tone and angle

Don't default to "problem → solution → conclusion." The right arc depends on what the post is doing.

- **Scar-driven angle** → _Moment of pain → what I thought I knew → what I learned → what it means for you_
- **Reversal angle** → _What I used to believe → the thing that changed my mind → what I believe now → how to tell when you're where old-me was_
- **Contrarian thesis, warm tone** → _The received wisdom + why it sounds right → the case it misses → the alternative → when the received wisdom is still right_
- **Contrarian thesis, punchy tone** → _The claim, stated hard → the argument, tight → the concession (honest about tradeoffs) → the takeaway_
- **Reflective essay** → _Opening question → exploration (multiple angles, no neat resolution) → the provisional answer → why it's worth holding even though incomplete_
- **How-we-did-it post** → _The problem we faced → the thing we tried → what happened → what we'd do differently_
- **Survey / overview** → _Why this topic now → the landscape → the distinctions that matter → what to do next_

These are starting templates, not recipes. Read the brief and angle, then pick the template closest to the material and modify freely. Do not force a template onto material that resists it.

## The flow

### 1. Read everything, state your read

Read `brief.md`. Read `angle.md` if it exists. Then, in one short paragraph, state what you heard:

> "The post is a reversal-angle piece about TDD. Tone is reflective-with-teeth. The strongest material you have: the three-day outage, the quote _'the tests were never the point'_, and the conversation with your 2017 teammate who got it first. The thesis claims TDD is about feedback design. The audience is senior ICs who've tried and rejected TDD."

Stating the read out loud serves two purposes: it confirms you understood (the author can correct you now), and it anchors the outline in specifics rather than abstract templates.

### 2. Propose a section structure

Propose 3–6 sections. For each section, include:

- A **working heading** (not final — drafting might rename it)
- A **one-line purpose** — what this section does for the reader
- A **material pointer** — what concrete pieces from brain dump / angle feed into it

Example proposal:

> **Proposed arc (reversal shape, 4 sections):**
>
> 1. **"I hated TDD for ten years"** — _Purpose: set the reversal hook; earn reader trust with specifics._
>    Material: the 2014 team that abandoned TDD after 3 sprints; your quote about "the tests were never the point".
>
> 2. **"What the dogma got right, and what it missed"** — _Purpose: honor the critique; establish you understand the pushback._
>    Material: the pushback list from your brain dump; the common failure modes of bad TDD.
>
> 3. **"The three-day outage"** — _Purpose: the moment of reversal; this is the narrative core._
>    Material: the outage story you told during find-the-angle.
>
> 4. **"What I think TDD actually is now"** — _Purpose: deliver the thesis and a concrete mental model for the reader._
>    Material: the feedback-design frame; your teammate's 2017 reframe.
>
> Works, adjust, or want a different shape?

Do not propose a section that has no material pointer. If you can't name what goes in it, that's a sign the section is a filler, not a section.

### 3. Iterate via `AskUserQuestion`

Present via `AskUserQuestion` with options:

- **Works as-is** — write outline.md and finish
- **Adjust specific sections** — author names which and what to change
- **Reshape entirely** — return to step 2 with a different arc template
- **Mine more material first** — if material is thin, suggest returning to the brain dump or running `find-the-angle`

If the author chooses "adjust," ask one follow-up: what changes. Then re-propose and repeat. Cap at 3 iterations — if the third round doesn't land, the problem is usually in brief or angle, not outline. Surface that:

> "We've circled three versions of the arc and none is sticking. I suspect the thesis or the angle isn't quite right yet. Want to revisit the brief before we outline further?"

### 4. Check section weight

Before writing the outline, sanity-check:

- **Is one section doing all the work?** If section 3 has 80% of the material and the others are thin, the post is actually about section 3 and needs re-sectioning around it.
- **Does the arc earn the takeaway?** Readers don't accept conclusions they haven't been walked to. If the final section asserts the thesis but the arc doesn't set it up, fix the arc, not the conclusion.
- **Is the opening load-bearing?** The first section decides whether the reader stays. Vague openings ("In this post, I'll discuss...") are instant bounces.

Flag any issues before writing the file. The author can accept the flag and fix later in drafting, or fix now.

### 5. Write outline.md

```markdown
---
slug: <from brief>
outline_confirmed: <YYYY-MM-DD from `date +%Y-%m-%d`>
arc_shape: <which template was closest, or 'custom'>
---

# Outline: <working title or thesis>

## Arc

<One or two sentences describing the shape of the post in plain language.>

## Sections

### 1. <heading>
**Purpose:** <one line>
**Material:** <specific pieces from brain dump / angle>
**Target length:** <short / medium / long — relative to the post overall>

### 2. <heading>
...

### 3. <heading>
...

## Pre-draft notes

- <any section weight flags>
- <any hooks the author explicitly wants>
- <anything the author said "don't forget to mention" during outlining>
```

Target length labels ("short / medium / long") are informal — they're cues for `draft-with-me` about relative section weight, not a word-count contract.

## Hand off

> "Outline written to `drafts/<slug>/outline.md`. Next:
> - **Draft the post** (say 'draft with me' or 'start drafting') — activates the `draft-with-me` skill.
>
> Or resume with `/blog-writer:write-blog <slug>`."

## Rules

- **Every section needs a material pointer.** No filler sections.
- **Don't default to problem → solution → conclusion.** Match arc to angle and tone.
- **3 iterations max.** Deeper circling means the brief/angle is off.
- **State your read first.** Anchor the outline in specifics, not templates.
- **Flag before writing.** Section-weight issues surface before the file is committed.
