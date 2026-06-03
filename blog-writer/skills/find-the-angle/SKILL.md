---
name: find-the-angle
description: "Sharpen a generic thesis into the single angle only the author can write. Triggers: 'find the angle', 'sharpen my angle', 'my thesis is too generic', 'what's unique here', 'help me find an angle', 'what makes this mine'. Interrogates the author for scars, mistakes, contrarian beliefs, and lived-experience specifics that separate their take from every other post on the topic. Writes drafts/<slug>/angle.md. Usually runs between blog-brief and outline."
---

# Find the Angle

**IMPORTANT — Deferred tool loading:** Before calling `AskUserQuestion`, call `ToolSearch` with query `"select:AskUserQuestion"` to load it. Do this once at the start.

A thesis says what the post argues. An angle says why *this* author, with *this* experience, arguing *this* thesis is worth the reader's time. Most blog posts have a thesis. The good ones have an angle.

## Why this matters

The thesis "TDD is about feedback design" has been written a hundred times. The angle "_I hated TDD for ten years until a production outage forced me to see it as feedback design_" has been written by one person. Readers finish posts that have an angle; they bounce on posts that don't.

## Inputs

- `drafts/<slug>/brief.md` — required. Read thesis, audience, tone, and the original brain dump.

If no `<slug>` is passed, list `drafts/*/` and ask which post. If `brief.md` is missing, stop and say: _"No brief found for this post. Start with the `blog-brief` skill (say 'start a new blog' or 'I have a brain dump') or run `/blog-writer:write-blog` to orchestrate from the top."_

## The interrogation

One question at a time via `AskUserQuestion`. Every question is about the author, not the topic. The angle lives in *their* story.

The goal: surface material in 3–5 questions that no one else could have written. Stop sooner if the angle becomes obvious early.

### The four veins to mine

Each question targets one of these veins. Cycle through in roughly this order; skip a vein if it's already mined from the brain dump.

**Vein 1 — Scars.** What went wrong that shaped this belief?

> "Your brain dump hints at a past project where TDD failed. What specifically went wrong? Was it a bad test suite, team pushback, or something else? A concrete failure will carry this post more than any abstract argument."

**Vein 2 — Reversals.** What did you once believe that you no longer do (or vice versa)?

> "Was there a version of you — 3 years ago, 10 years ago — who held the opposite view? What made you switch?"

Reversal stories are disproportionately effective. They signal honesty and earn the reader's trust before any technical argument.

**Vein 3 — Contrarian beliefs.** What do you believe that your audience mostly doesn't?

> "If you said this thesis out loud to ten experienced developers, how many would push back? What's the pushback? Your angle lives in answering that pushback, not in ignoring it."

**Vein 4 — Specifics only you have.** What numbers, stories, quotes, or moments do you have that no one else does?

> "Do you have any specific numbers, quotes from real conversations, or moments you remember in detail? Those are the sentences that will stick. Generic claims dissolve."

### Reading the brain dump first

Before firing questions, scan the brain dump for vein signals:

- Any past-tense stories → **Scar / reversal vein is already warm**
- Any "I used to think" / "I was wrong" → **Reversal vein mined**
- Any specific numbers, dates, quotes → **Specifics vein mined**
- Only abstract claims, no stories → **All veins dry; ask scar questions first**

Tailor the first question to whichever vein already has some material. Don't ask "what went wrong" if the brain dump already tells a story of what went wrong — dig deeper into that story instead.

## When the author gets defensive or vague

Good interviewing means pushing past the first soft answer. If the author says "I don't really have a specific example" or hedges, try one of these:

- **Concrete time-bounding:** "When was the last time this mattered to you? Last project? Last year?"
- **Low-stakes permission:** "Even a small thing counts — a comment in a review, a conversation with a teammate, a failing test that surprised you."
- **Flip the frame:** "If you had to defend this thesis against your harshest critic, what would they say and how would you answer?"

If after two attempts the author genuinely has nothing — no story, no reversal, no specifics — surface it honestly:

> "I'm not finding the angle that's unique to you yet. Your brain dump is mostly claims, which are fine but common. Is there a story or a specific moment you could share? If not, the post might work as a survey rather than an argument — and that's a different shape."

This is not failure. Some posts genuinely are surveys. Let the author decide whether to switch shape or keep mining.

## Proposing angle candidates

After 3–5 questions (or sooner if a clear angle emerges), stop interrogating and propose 2–3 angle candidates. Each candidate is:

- A **single sentence** — if it needs two sentences, it's not sharp enough
- Grounded in **material the author gave you** — quote or reference their own words where possible
- **Author-specific** — a reader would recognize that only this author could have written it

Example:

> "Three angles I hear in what you've told me:
>
> 1. **Scar-driven** — _'I argued against TDD for a decade, until a three-day production outage I could have prevented with one test taught me what TDD is actually for.'_
>
> 2. **Reversal** — _'The version of me who called TDD dogmatic was right about the dogma and wrong about the practice. Here's the distinction I missed.'_
>
> 3. **Contrarian to the audience** — _'Most senior engineers I respect skip TDD. Here's why I think we're wrong — and why my younger self was right.'_
>
> Pick one, modify one, or we can mine further."

Ask via `AskUserQuestion`. If the author rejects all three, either go deeper on one vein or ask them to sketch the angle themselves in one sentence.

## Writing angle.md

Once the author confirms an angle:

```markdown
---
slug: <from brief>
angle_chosen: <YYYY-MM-DD from `date +%Y-%m-%d`>
---

# Angle: <one-sentence angle>

## Why this angle

<2-3 sentences on what makes it author-specific — reference the scar/reversal/specifics the author shared>

## Material to deploy

Concrete pieces surfaced during the interrogation that downstream skills should use:

- <specific story / number / quote surfaced during questioning>
- <another one>
- <another one>

## Angle guardrails

- What this post is NOT about: <1-2 items — deliberate out-of-scope from the interrogation>
- The thing to not apologize for: <author's strongest conviction, the thing the post should stand on>
```

This file becomes a reference for `outline` (which shapes the arc around the angle) and `draft-with-me` (which mines the "material to deploy" list for sections).

## Hand off

> "Angle written to `drafts/<slug>/angle.md`. Suggested next:
> - **Shape the arc** (say 'outline this' or 'build the outline') — activates the `outline` skill.
> - **Start drafting** (say 'draft with me') — activates the `draft-with-me` skill; skips the outline step.
>
> Or resume with `/blog-writer:write-blog <slug>`."

## Rules

- **One question at a time.** Via `AskUserQuestion`.
- **Every question targets a vein.** Never generic "tell me more."
- **Derive, don't invent.** Quote the author's words where possible.
- **Stop at 5 questions.** If no angle has emerged, surface the honest assessment.
- **An angle is one sentence.** Two sentences means it isn't sharp.
- **Skip the skill** if the brief already contains a visibly angle-shaped thesis (rare but possible). Say so and suggest going straight to `outline`.
