---
name: blog-brief
description: "Start a new blog post from a topic + brain dump. Triggers: 'start a blog', 'blog brief', 'new blog post', 'I have a brain dump', 'help me shape this into a blog', 'turn this into a post'. Ingests the brain dump, sharpens thesis/audience/takeaway one question at a time, suggests 2–3 tone candidates with sample opening lines derived from the author's own voice, auto-generates a slug, and writes drafts/<slug>/brief.md. Entry point of the blog-writer flow."
---

# Blog Brief

**IMPORTANT — Deferred tool loading:** Before calling `AskUserQuestion`, call `ToolSearch` with query `"select:AskUserQuestion"` to load it. AskUserQuestion is deferred and fails without loading. Do this once at the start.

The author arrives with a topic and a brain dump. The brain dump is not a blog — it's scattered thinking, bullet points, rants, or a voice memo transcribed. Turn scattered thinking into a brief the rest of the blog-writer flow can rely on: a sharpened thesis, an explicit audience, a one-line reader takeaway, and a tone the author confirms.

## Why this matters

Most blog posts fail at the brief, not at the prose. If the author doesn't know what they're arguing, who they're arguing it to, and what the reader should walk away with, no amount of editing saves the post. The brief isn't bureaucracy — it's the tuning fork every downstream skill rings against. Tone gets checked here because voice signals are strongest in the raw brain dump, before prose smooths them over.

## Inputs

The skill accepts any of:

- A path to a markdown/text file with the brain dump
- Inline text pasted into the conversation
- No input — ask the author for one

Do not proceed without a brain dump. If the author has only a topic ("I want to write about TDD"), ask them to brain-dump for 5–10 minutes and come back. A bare topic is not enough material to derive tone or thesis candidates from.

## The flow

### 1. Read the brain dump

Read the file or treat the pasted text as the brain dump. Before asking anything, skim for:

- **Thesis candidates**: one-sentence claims the dump seems to be arguing
- **Audience signals**: who the author is talking to (peers, juniors, skeptics, a specific role)
- **Voice signals**: opinionated? reflective? punchy? academic? irreverent? warm?
- **Scars and stories**: concrete experiences the author references
- **What's missing**: places where thinking is hand-wavy or contradicts itself

Hold the analysis before asking anything. The sharpening questions below must be *informed* by the brain dump, not generic.

### 2. Sharpen thesis, audience, takeaway — one question at a time

Ask exactly one `AskUserQuestion` per message. Multiple questions let authors cherry-pick the easy one.

**Thesis question.** From the brain dump, surface 2–3 candidate theses (each a single sentence, each a *claim* — not a topic). Example:

> "I see three possible theses in your dump. Which is the one you actually want to argue?
> 1. TDD is about feedback design, not testing
> 2. Teams that skip TDD pay in review latency, not bug count
> 3. TDD without refactoring is theatre"

The "something else" option is always available. If the author picks none, ask them to type their own thesis in one sentence.

**Audience question.** Offer 2–3 concrete audiences derived from voice signals. Not "developers" — more specific: "senior ICs who've tried and rejected TDD" vs "team leads who want to adopt it but their team resists" vs "bootcamp grads who've never tried it." The audience decides what the reader already knows, what they'll find novel, and what objections the post must answer.

**Reader takeaway question.** One sentence: "After reading this, the reader will ___." Offer 2–3 derived from thesis + audience. The takeaway is not a summary of the post; it's the shift in the reader's head.

### 3. Suggest tone from the brain dump's own voice

Tone is first-class in this plugin. Do not pick a tone in the abstract — derive candidates from the author's own voice in the brain dump, then offer 2–3 with **concrete sample opening lines** written *in* that tone from *their* material.

Useful tone dimensions to mix and match:

- **Punchy** — short sentences, strong verbs, few hedges
- **Reflective** — longer sentences, internal monologue, uncertainty named
- **Contrarian** — takes a swing at received wisdom
- **Warm / personable** — "I" and "we", lived stories, talking-to-a-friend register
- **Rigorous** — claims + evidence, tradeoffs named, source-or-strike
- **Irreverent** — jokes, asides, deliberate informality
- **Quiet authority** — spare, confident, understated; no persuasion games

Example of how to present tone candidates:

> "Your dump leans opinionated but has moments of actual doubt, which is interesting. Three tones that could work:
>
> **A. Punchy contrarian** — _'Most teams don't skip TDD because they're lazy. They skip it because their feedback loop already works.'_
>
> **B. Reflective with teeth** — _'I've argued against TDD, and I've argued for it. Both times I was partly wrong. Here's what I think I know now.'_
>
> **C. Warm and specific** — _'The last time a teammate said "we don't have time for TDD," I agreed with them. Then we shipped three bugs in a week.'_"

Ask via `AskUserQuestion`. Let the author pick, adjust, or say none-of-the-above and describe their own tone.

### 4. Auto-generate the slug

Derive the slug from the thesis using kebab-case. Rules:

- Lowercase, hyphen-separated
- Strip stopwords (a, the, is, and, or, of, to, for, etc.) where it doesn't change meaning
- 3–6 words max, aim for the core claim
- No trailing date or numbering

Examples:
- Thesis: "TDD is about feedback design, not testing" → `tdd-is-feedback-design`
- Thesis: "Teams that skip TDD pay in review latency, not bug count" → `tdd-skippers-pay-in-review-latency`

Confirm the slug with one line: _"I'll use slug `tdd-is-feedback-design` for the folder. OK, or want to change it?"_ — then proceed unless they object.

### 5. Create the folder and write brief.md

Create the folder under the current working directory. Determine the cwd with bash `pwd` — do not assume the repo root.

**Check for slug collision first.** If `drafts/<slug>/` already exists (check with `ls drafts/ 2>/dev/null | grep -w <slug>` or `test -d drafts/<slug>`), append `-2`. If that also exists, `-3`, and so on. Confirm the final slug with the author before proceeding if it was modified.

Then:

```bash
mkdir -p drafts/<final-slug>/images
```

(Pre-create the `images/` subdirectory now so `draft-with-me` can drop images in without an extra step later.)

Determine today's date with bash `date +%Y-%m-%d` — do not guess the date. Use that ISO value (`YYYY-MM-DD`) in the `created` field below.

Then write `drafts/<slug>/brief.md` with this exact structure:

```markdown
---
slug: <slug>
thesis: <one-sentence thesis the author confirmed>
audience: <specific audience the author confirmed>
takeaway: <one sentence the reader should walk away with>
tone: <chosen tone label + 1-sentence description>
created: <YYYY-MM-DD from `date +%Y-%m-%d`>
---

# Brief: <thesis>

## Audience
<audience + 1–2 sentences on what they already know / care about / will object to>

## Reader takeaway
<the takeaway sentence + 1–2 sentences on why it matters to that audience>

## Tone
<tone name>

Sample opening line in this tone:
> <the sample line the author liked>

Voice notes (what to preserve):
- <signal 1 from the brain dump>
- <signal 2 from the brain dump>

## Original brain dump

<paste the entire brain dump verbatim — this is source of truth for draft-with-me>
```

The brain dump is preserved in full because `draft-with-me` will mine it for material. Do not summarize or clean it up. Authors often won't revisit a brain dump mid-draft; the brief carries it forward.

### 6. Hand off

End with a short summary and the suggested next steps:

> "Brief written to `drafts/<slug>/brief.md`. Three common next moves:
>
> - **Sharpen the angle** (say 'find the angle' or 'sharpen my angle') — recommended for essay-style or meta-technical posts; activates the `find-the-angle` skill.
> - **Structure the arc** (say 'outline this' or 'build the outline') — activates the `outline` skill; skips angle.
> - **Start drafting** (say 'draft with me' or 'start drafting') — activates the `draft-with-me` skill; handles missing angle/outline gracefully.
>
> Or run the orchestrator at any time: `/blog-writer:write-blog <slug>` — walks the full flow with pauses at each handoff."

## Rules

- **One question at a time.** Always via `AskUserQuestion`.
- **Derive, don't invent.** Every thesis, audience, and tone candidate must come from signals in the brain dump. If the dump is too thin to derive from, say so and ask for more.
- **Never write the brief without explicit confirmation** of thesis, audience, takeaway, and tone. Defaults are suggestions, not decisions.
- **Preserve the brain dump verbatim** in `brief.md`. The downstream skills rely on it.
- **Do not draft the post here.** This skill produces a brief, nothing more. Drafting is `draft-with-me`.

## When the brain dump is too thin

Signs: fewer than ~150 words; no concrete examples, stories, or specifics; only abstract claims. In that case, do not proceed. Say:

> "The brain dump is a bit light to derive tone and thesis candidates from confidently. Want to take 10 minutes, expand it with stories, scars, numbers, or specific moments, then come back? I'll wait."

Better to delay than to force the brief to invent material that isn't there.
