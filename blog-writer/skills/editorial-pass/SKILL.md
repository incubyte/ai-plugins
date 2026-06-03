---
name: editorial-pass
description: "This skill should be used when the user has a draft and wants line-level craft polish — cutting hedging, fixing passive voice, breaking up throat-clearing, varying rhythm, tightening wordiness — while strictly preserving their chosen tone and voice. Triggers include: 'editorial pass', 'polish the draft', 'line edits', 'editorial review', 'tighten the prose', 'clean up the writing', 'proofread my draft'. Walks the draft section-by-section; proposes specific before/after edits; lets the user accept, reject, or modify each one. Never rewrites more than the author approves."
---

# Editorial Pass

**IMPORTANT — Deferred tool loading:** Before calling `AskUserQuestion`, call `ToolSearch` with query `"select:AskUserQuestion"` to load it. Do this once at the start.

A good editorial pass is not a rewrite. It's a patient walk through the prose, pointing at specific weaknesses, proposing a specific alternative, and letting the author decide. This skill does that, section by section.

## Why this matters

Most blog prose dies a death of a thousand small cuts: "just a bit", "kind of", "it could be argued that", passive constructions that hide the actor, throat-clearing intros that delay the idea, strings of similar-length sentences that flatten the rhythm. Each one is small. Together they make the post feel soft. An editorial pass finds them and offers tighter alternatives — but only the author can choose whether each change keeps their voice.

## Inputs

1. `drafts/<slug>/brief.md` — for the chosen tone, audience, and voice notes (required)
2. `drafts/<slug>/draft.md` — the draft to polish (required)

If no `<slug>` is passed, list `drafts/*/` and ask the author which post. If either file is missing, stop and point to the skill that produces it.

## The tone-preservation rule

Read the tone from `brief.md` **before proposing a single edit**. Every suggestion must preserve the tone. A "punchy contrarian" voice earns its short sentences — don't suggest adding hedges to soften it. A "reflective with teeth" voice earns its longer sentences — don't suggest chopping them into a staccato rhythm.

When in doubt about whether a change preserves tone, say so:

> "This change tightens it but it might nudge the tone toward punchy. You want that or want to keep the reflective register?"

## The pass

Walk the draft in section order. For each section:

### 1. Scan for targets

Read the section once and collect specific craft issues. Categories to hunt for:

**Hedging** — unearned qualifiers that weaken a claim the author actually believes.
- _"I think maybe TDD can sort of help with..."_ → _"TDD helps with..."_
- Keep hedges that are genuine (author is deliberately uncertain); cut hedges that are habit.

**Passive voice** — hides the actor.
- _"The tests were written after the code was shipped"_ → _"We shipped the code, then wrote the tests"_
- Keep passive when the actor is genuinely unknown or irrelevant.

**Throat-clearing** — intro phrases that delay the idea.
- _"In this section, I want to talk about..."_ → cut entirely
- _"It's worth noting that..."_ → if it's worth noting, note it
- _"At the end of the day..."_ → cut

**Flat rhythm** — 4+ sentences in a row of the same length.
- Break with a short one. Or a fragment. Like this.

**Weak verbs** — _is_, _was_, _has_, _does_ doing all the work.
- _"The refactor was successful"_ → _"The refactor shipped / held / freed us to..."_

**Wordiness** — paragraphs that say one thing twice.
- Cut the second version.

**Buried lede** — the most interesting sentence is in paragraph 3.
- Suggest moving it up.

**Empty adverbs** — _really, very, quite, actually, basically_.
- Usually cut.

**Compound conditional pileups** — _"when we are doing X in the context of Y such that Z..."_
- Split into two sentences.

### 2. Propose the edit — show before / after

For each target, present a specific edit. Never "this paragraph is a bit wordy." Instead:

> **Paragraph 2 — hedging stack:**
>
> Before:
> > _"I think TDD might help teams sort of get feedback faster, which could potentially improve code quality over time."_
>
> After:
> > _"TDD tightens feedback. Faster feedback shifts defects left."_
>
> Kept: the causal claim. Cut: four hedges, one empty modifier, one vague outcome.

The "Kept / Cut" line matters — it shows the author what was preserved vs removed, so they can judge whether voice survived.

### 3. Accept / reject / modify

After each proposed edit, `AskUserQuestion`:

- **Accept** — apply the edit via `Edit`
- **Accept with tweak** — author types a modified version; apply that
- **Reject** — leave it alone, move on
- **Skip section** — stop editing this section; move to next

Apply accepted edits immediately with the `Edit` tool so the draft stays current across long passes.

### 4. Batch small edits per section

For a section with many small issues (typos, single-word tightenings), batch them into one proposal rather than asking section-by-word. Example:

> **Paragraph 3 — five small tightenings:**
>
> 1. _"really important"_ → _"important"_
> 2. _"it is the case that"_ → _"[cut]"_
> 3. _"basically"_ → _"[cut]"_ (2 occurrences)
> 4. _"in order to"_ → _"to"_
>
> Accept all, or pick which ones?

This respects the author's attention. Reserve individual before/after framing for edits that actually change meaning or rhythm.

### 5. Move to next section

After one section is done (or skipped), move to the next. Do not loop back automatically — editorial passes get worse the more the author is re-asked about the same paragraph.

## What this skill does NOT do

- **No structural rewrites.** If a section is in the wrong place or the argument is broken, surface it as a note at the end, not as an edit. Structural problems belong to `outline` or a conversation, not to a line-level pass.
- **No fact-checking or claim challenging.** That's `knowledge-pass`.
- **No title work.** That's `title-lab`.
- **No multi-step rewrites of the same sentence.** If an edit is rejected, move on.

## When the whole section needs help

Sometimes a section is fundamentally off — wrong tone, buried point, broken argument. Do not propose 20 small edits to paper over it. Say:

> "This section isn't a line-edit problem. The point lands in paragraph 4 but the first three paragraphs wander. Want to restructure it, rewrite it from scratch, or leave it and come back?"

Give the author the choice.

## Finishing

After the last section:

1. Summarize changes: _"Accepted 23 edits across 6 sections. Rejected 9. Skipped 1 section."_
2. Surface any structural notes held back from the line pass
3. Suggest next step:

> "Line edits done. Suggested next:
> - **Challenge claims + research** (say 'knowledge pass') — activates the `knowledge-pass` skill.
> - **Title it** (say 'title lab') — activates the `title-lab` skill.
>
> Or resume with `/blog-writer:write-blog <slug>`."

## Rules summary

- **Tone first.** Read `brief.md` before proposing anything.
- **Show before / after + Kept / Cut.** No vague comments.
- **Accept / reject / modify per edit or per batch.** Author decides.
- **No structural rewrites.** Surface them as notes.
- **Apply edits immediately with `Edit`.** Don't let the file drift from what the author accepted.
- **Stop looping after one rejection.** Trust the author's ear.
