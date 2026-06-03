---
name: title-lab
description: "Generate title + dek for a nearly finished blog post (Substack target). Triggers: 'title lab', 'title this post', 'help me find a title', 'what should I call this', 'substack title', 'title and subtitle'. Produces 5–8 title candidates across strategies (direct, curiosity-gap, contrarian, question, and optionally numbered or metaphor) with explicit tradeoffs for each, plus a matching dek. Author picks; chosen title + dek are written to the draft's frontmatter AND injected into the body — the H1 working title is replaced and the dek is added as an italic line directly beneath so both appear in the draft when reviewing."
---

# Title Lab

**IMPORTANT — Deferred tool loading:** Before calling `AskUserQuestion`, call `ToolSearch` with query `"select:AskUserQuestion"` to load it. Do this once at the start.

A title is the one piece of the post most readers ever see. On Substack, it does double duty: it sells the click on the feed, and it earns the read once the reader lands. This skill generates 5–8 candidates across distinct strategies so the author can feel the tradeoffs — clickable vs accurate, broad vs niche, curiosity vs directness — before choosing.

## Why this matters

Most authors produce two kinds of bad titles: the safe descriptive one that nobody clicks ("Thoughts on TDD"), or the over-engineered clickbait that readers resent ("The SHOCKING Truth About TDD"). The job of this skill is to put genuinely different strategies side by side, each labeled with what it's trading away.

## Inputs

1. `drafts/<slug>/brief.md` — thesis, audience, tone (required)
2. `drafts/<slug>/draft.md` — the full draft (required)

If `<slug>` isn't passed, list `drafts/*/` and ask which post. If either file is missing, stop and point to the skill that produces it.

## The six strategies

Generate at least one candidate from each of the first four strategies; the last two are optional and only used when the post genuinely supports them.

### 1. Direct / descriptive

Says plainly what the post is about. Low CTR ceiling, high trust. Good for experienced-reader audiences who click on substance, not hooks.

Example shapes:
- _"Why TDD is about feedback design, not testing"_
- _"Notes on the real cost of skipping code review"_
- _"How we cut deploy time from 40 minutes to 4"_

### 2. Curiosity-gap

Opens a question the reader can only close by clicking. Dangerous — if the post doesn't *actually* close the gap, the reader feels cheated. Only use when the thesis is genuinely non-obvious.

Example shapes:
- _"What I got wrong about TDD for ten years"_
- _"The metric that told us our deploy pipeline was broken"_
- _"We stopped doing code reviews. Here's what happened."_

### 3. Contrarian

Directly contradicts received wisdom. High engagement from people who disagree; risks eye-rolls if the take isn't earned.

Example shapes:
- _"TDD is not about tests"_
- _"Code reviews don't improve quality"_
- _"Most 'best practices' are just old defaults"_

### 4. Question

Frames the post as an answer. Works well when the reader genuinely asks this question; feels weak if they don't.

Example shapes:
- _"Does TDD actually speed teams up?"_
- _"What does a good deploy pipeline look like?"_
- _"Why is code review so slow?"_

### 5. Numbered (optional)

Works for posts that are actually list-structured. Avoid forcing a list frame onto a narrative post.

Example shapes:
- _"Three things TDD is not"_
- _"The five stages of caring about code review"_

### 6. Metaphor (optional)

Uses a vivid image. Memorable when it lands; forced when it doesn't. Only use if a metaphor is already present in the draft.

Example shapes:
- _"TDD is a tuning fork, not a compliance gate"_
- _"The deploy pipeline is the nervous system"_

## The flow

### 1. Read the draft and the brief; extract candidate phrases

Skim the full draft for memorable phrasing — 2–3 lines the author wrote that could serve as, or inform, a title. These are candidate **sources**, not a separate strategy. Author-written phrasing is often the strongest material because it's already in the author's voice.

Re-read the thesis and tone. Titles must match the tone of the post. A reflective post with a "SHOCKING TRUTH" headline feels like fraud.

**Length constraints** (apply to every candidate):

- Title: aim for ~40–60 characters; hard cap at 70. Substack truncates longer titles in the feed.
- Dek: aim for ~15–25 words; hard cap at 35. Longer deks also truncate.

### 2. Generate 5–8 candidates across strategies

Produce them as a labeled list with each candidate's **tradeoff** explicit. Tradeoff language should be honest:

- _"High CTR but sets up a big promise the post must pay off"_
- _"Lower CTR on feed, higher trust once clicked"_
- _"Great for readers who already disagree with you; might alienate fence-sitters"_
- _"Only lands if reader knows the context — fine for niche audience"_

Example output shape:

> **Candidates:**
>
> 1. **Direct** — _"Why TDD is about feedback design"_
>    Tradeoff: accurate to the thesis; low-curiosity opening, relies on niche audience.
>
> 2. **Curiosity-gap** — _"What I got wrong about TDD for ten years"_
>    Tradeoff: strong hook; the post must actually own a wrong belief.
>
> 3. **Contrarian** — _"TDD is not about tests"_
>    Tradeoff: sharp, memorable; earns readers, alienates ones who want nuance in the title.
>
> 4. **Question** — _"What is TDD actually for?"_
>    Tradeoff: useful framing; weak as a feed hook compared to the contrarian.
>
> 5. **Direct (variant)** — _"The real point of TDD"_
>    Tradeoff: cleaner, shorter; vague unless subtitle carries weight.
>
> 6. **Direct (author's line)** — _"The tests were never the point"_
>    Source: pulled from paragraph 3 of the draft. Tradeoff: authentic voice; leans quiet — strength depends on whether the reader is already curious.

### 3. Generate a matching dek for each

The dek (subtitle) on Substack is as important as the title. It either:

- **Expands** the title (direct title + dek adds the who/why/stakes)
- **Contrasts** the title (curiosity title + dek hints at the payoff without spoiling)
- **Grounds** the title (metaphor title + dek says what it means literally)

Generate a dek for each candidate, labeled with its strategy.

Example:

> 1. **Direct — _"Why TDD is about feedback design"_**
>    Dek: _"Most teams treat TDD as a testing practice. Treat it as a feedback system instead, and the whole workflow changes."_

Keep deks under ~25 words. Substack truncates long ones in the feed.

### 4. Strength check — the title must pull at least as much weight as the dek

Before presenting candidates, apply a strength check to each title/dek pair:

**Ask yourself:** if a reader saw only the title in the Substack feed — no dek, no body — would they click? And: is the title doing at least as much work as the dek, or is the dek carrying the pair?

**Fail signals:**
- The dek has a concrete number, a contrast, or a claim; the title has only a phrase or metaphor.
- The title is a metaphor lifted from the post body, but the dek articulates the actual thesis. (A metaphor title needs the body to unpack it; the feed doesn't give you a body.)
- The title is a noun phrase; the dek has a verb. Dek is active, title is inert.
- The title is generic enough that ten other posts in the space could have it; the dek is specifically-yours.

**For each failing pair, do one of:**
- **Regenerate the title** with the dek's concreteness or verb injected. Keep the dek as-is.
- **Flip them.** The dek is the title; write a new dek that expands or contrasts. Often the cleanest fix.
- **Drop the candidate.** If no version is savable, remove it from the list; don't pad the count.

**Example of a fail and a fix:**

> ❌ Title: _"Bigger Engine, Same Road"_ (metaphor from body — inert in feed)
> Dek: _"AI promised 10x. DX measured 10%. The gap is the shape of your delivery system."_ (concrete numbers, specific claim)
>
> ✅ Flipped / rewritten title: _"AI promised 10x. We measured 10%."_ (concrete, active, curiosity-gap)
> New dek: _"The distance from thought to shipped result is the bottleneck. AI shortens the wrong leg."_

After the check, you should have 5–8 candidates where **no dek does more heavy lifting than its title**. If a specific pair still has a stronger dek after regeneration, present it to the author explicitly: _"This pair's dek is doing more work than its title — worth flipping them, or using the dek as-is and I'll regenerate only the title?"_

### 5. Present and let the author choose

Via `AskUserQuestion`:

- One option per title (with dek shown)
- "Pick one and tweak the wording"
- "None — I'll write my own"
- "Generate more in strategy X"

If the author picks "generate more", produce 3 new candidates in the specified strategy only, with fresh tradeoffs — and apply the strength check from step 4 to each.

### 6. Write to draft frontmatter AND the body

Once the author confirms title + dek, make **two edits** to `drafts/<slug>/draft.md`:

**Edit A — frontmatter.** Set `title` and `dek` fields:

```yaml
---
slug: <slug>
title: <chosen title>
dek: <chosen dek>
thesis: <existing>
tone: <existing>
...
---
```

Do not modify other frontmatter fields.

**Edit B — body.** Replace the H1 working title with the confirmed title, and add the dek on the line immediately beneath as an italic line. Shape:

```markdown
# <chosen title>

*<chosen dek>*

<rest of the draft, untouched>
```

Without the body update, the author reads a draft whose visible headline still says the placeholder — the dek exists only in frontmatter, invisible during review. Substack paste works either way (title/dek are separate fields there), but the in-editor reading experience needs them visible together.

Use `Edit` for each change separately so the match strings stay unambiguous.

Confirm with a single line:

> "Title set: _<chosen title>_. Dek: _<chosen dek>_. Both written to frontmatter and shown beneath the H1 in the body. Draft is ready to paste into Substack (title and subtitle map to Substack's separate fields).
>
> - **Generate cover image prompts** (say 'cover image') — activates the `cover-image` skill.
>
> Or resume with `/blog-writer:write-blog <slug>` / `/blog-writer:write <slug>`."

## Rules

- **Match the tone from the brief.** A title that breaks tone is a worse title regardless of CTR.
- **Tradeoffs must be honest.** Not every title is "strong". Say what each one gives up.
- **Pull from the draft when possible.** The author's own best line is often a better title than anything generated.
- **No title weaker than its dek.** The title is what the reader sees in the feed. If the dek is doing more work, either rewrite the title to match, flip them, or drop the candidate.
- **Cap at 8 candidates.** More becomes noise. If the author wants different options, generate 3 more in a specific strategy, not 8 more across all.
- **Dek is mandatory on Substack.** Never propose a title without a matching dek.

## When no title feels right

If the author rejects all candidates, the problem is usually one of these:

- **Thesis is drifting** — what the draft argues is no longer what the brief said. Reconfirm thesis before generating more titles.
- **Tone mismatch** — candidates are all in a tone the author doesn't want. Ask which tone feels wrong and regenerate.
- **Audience mismatch** — titles target the wrong reader. Reconfirm audience from the brief.

Surface the likely cause rather than generating a 12th candidate.
