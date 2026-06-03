---
name: cover-image
description: "Generate 2–3 distinct cover image prompts suitable for Midjourney, DALL-E, or ChatGPT — derived from the finished draft's metaphors, tone, and audience. Triggers: 'cover image', 'generate cover image prompt', 'image prompt', 'substack cover', 'make a prompt for the cover', 'cover art'. Each prompt specifies medium, composition, mood, palette, exclusions, and aspect ratio. Prints all candidates in chat (no file written, no forced selection) — author copies whichever they want and runs it in their image tool. Does NOT generate the image itself."
---

# Cover Image

**IMPORTANT — Deferred tool loading:** Before calling `AskUserQuestion`, call `ToolSearch` with query `"select:AskUserQuestion"` to load it. Do this once at the start.

A Substack cover image is the reader's first impression in the feed. A prompt that produces a good one is about explicit choices: subject, style, composition, mood, palette. Vague prompts produce vague images. This skill generates prompts the author actually likes before a single image is generated.

## Why this matters

Most authors run a one-shot prompt like "minimalist image about TDD" and get something generic. The difference between generic and striking is often one explicit choice — a specific medium, a specific palette, a specific metaphor from the post. This skill makes those choices explicit, so the image actually matches the post.

## Inputs

- `drafts/<slug>/brief.md` — for thesis, tone, audience
- `drafts/<slug>/draft.md` — for the actual content, phrasing, and metaphors the post uses

If no `<slug>` passed, list `drafts/*/`. If either file missing, stop and point to the skill that produces it.

## The flow

### 1. Read the finished draft, extract visual signals

Skim the full draft. Collect:

- **Metaphors the author uses** — "tuning fork", "nervous system", "crime scene", "feedback loop as a circuit" — these are prompt gold. If the author spent a paragraph on a metaphor, the cover should honor it.
- **Concrete objects mentioned** — things, not concepts. Pipes, circuits, staircases, bridges, mirrors. Concrete renders far better than abstract.
- **Tone-consistent mood words** — reflective, punchy, contrarian, quiet-authoritative. A reflective post gets a contemplative image, not a bold one.
- **Color signals** — any mention of color or season in the draft? (Usually none — inferred from tone.)

If the draft uses an anchoring metaphor, default the image to visualize *that metaphor*. Metaphor-grounded covers massively outperform stock-look "tech with neon accents" covers.

### 2. Propose 2 distinct prompts (not 8)

Two prompts with genuinely different strategies, not eight variations on the same idea. Each prompt specifies:

- **Subject** — what the image shows
- **Style / medium** — watercolor, pen-and-ink, editorial illustration, vintage poster, isometric line art, photograph, risograph, oil painting, collage — *specific*
- **Composition** — centered, rule-of-thirds, wide-shot, close-up, symmetry-broken, negative-space-heavy
- **Mood / lighting** — soft diffused, harsh afternoon, golden hour, overcast, dramatic single light
- **Palette** — 2–4 named colors (muted olive, faded terracotta, ink black, bone white — specific over "earth tones")
- **Thing to exclude** — what the image should NOT have (stock gears, clichéd hands-on-keyboard, AI-typical neon grids, faces)
- **Aspect ratio** — Substack covers render 3:2 landscape well (1456×816)

Example proposal:

> **Prompt A — metaphor-grounded, editorial illustration**
>
> _Editorial illustration of a single tuning fork resting on a cracked workbench, struck so that visible sound ripples spread outward through the grain of the wood. Pen-and-ink linework with watercolor wash. Centered composition with deep negative space above. Palette: ink black, muted ochre, bone white, a single thread of cadmium red in the ripples. Soft side lighting from the left. No gears, no keyboards, no neon. 3:2 landscape, 1456×816._
>
> _Why this works: honors the tuning-fork metaphor from section 4; the cracked bench signals the imperfect-team setting; the single red thread draws the eye to the ripple, mirroring the feedback-design thesis._
>
> **Prompt B — contrarian, risograph poster**
>
> _Risograph-style editorial poster of a staircase that starts going up and, halfway, inverts into going down — rendered in two-color risograph (deep navy + warm red) with visible paper texture and slight misregistration. Composition: staircase fills the vertical center; generous negative space framing. Mood: quietly subversive. No text on the image. 3:2 landscape, 1456×816._
>
> _Why this works: the tone is contrarian-with-restraint; staircases-that-invert is a visual echo of the reversal angle; risograph evokes 70s/80s quiet-rebellion aesthetics._

Two or three is right. One doesn't give a meaningful choice; four+ becomes noise. Each candidate must feel genuinely distinct — different medium, different metaphor, or different mood — not three versions of the same idea.

### 3. Print all candidates in chat — do not write a file

Prompts are consumption artifacts. The author copies them into their image tool and they're done. Persisting them in the draft folder adds clutter for zero future benefit (no downstream skill reads them; resumable sessions don't need them). Print directly in the conversation and stop.

**Do NOT write `drafts/<slug>/cover-image-prompt.md`** — the old behavior. Do NOT ask the author to pick one. They copy what they want from the screen.

### 4. The chat output format

Print exactly this shape:

````markdown
## Cover image prompts

Paste any into your image tool. Running multiple is cheap — the tool's output will tell you which landed better than any amount of prompt-tuning here could.

### Prompt A — <short descriptor, e.g., "metaphor-grounded editorial illustration">

<full prompt text, one paragraph, ready to copy>

**Why:** <1–2 sentences: which metaphor or moment from the draft it honors, which tone choice drives the style, what it's deliberately NOT doing>

### Prompt B — <short descriptor>

<full prompt text>

**Why:** <1–2 sentences>

### Prompt C — <short descriptor>  *(optional — only if you have a genuinely third distinct direction)*

<full prompt text>

**Why:** <1–2 sentences>

---

**Tool-specific notes:**
- **Midjourney:** append `--ar 3:2 --v 6 --style raw` for editorial illustration; omit `--style raw` for painterly work.
- **DALL-E / ChatGPT:** say "wide landscape, 3:2 ratio" explicitly; the model sometimes drops aspect ratio.
- **Stable Diffusion:** add `masterpiece, detailed` plus a negative prompt covering the items in each prompt's "no" clause.

If none of these land after you try them, tell me what to shift (different medium, warmer palette, literal instead of metaphorical, quieter mood, etc.) and I'll generate a new set.
````

Then stop. No `AskUserQuestion`. No "pick one." Iteration is available on demand if the author wants a different direction, but it's not the default behavior.

### 5. On-demand iteration (only if the author asks)

If the author returns saying "these don't feel right," "try something different," or provides specific directional feedback, generate 2–3 NEW candidates in the requested direction and print them the same way. Same pattern — no forced pick, no file.

Keep going as long as the author asks, but never volunteer another round. The author's image tool, not this skill, is where convergence happens.

## Hand off

> "Copy whichever prompt you like above and run it in your image tool. If the generated images miss, come back and tell me what to shift (different medium, warmer palette, literal instead of metaphorical, etc.) and I'll generate a new set. Post is ready to publish."

## Rules

- **2–3 candidates, genuinely distinct.** Not three riffs on the same idea.
- **Every prompt is explicit.** Medium, composition, mood, palette, exclusions, aspect ratio — no hand-waving.
- **Honor the draft's metaphors first.** A post with a great metaphor gets an image of that metaphor.
- **Exclude AI clichés.** Always explicitly exclude: stock gears, hands-on-keyboard, neon grids, glowing orbs, generic "AI brain" imagery — unless the post is literally about those things.
- **Print, don't write.** Candidates go to the chat window, not to disk. The author copies what they want.
- **Never ask the author to pick one.** Present all candidates; let them try whichever they want in their image tool.
- **Iteration is on-demand, not default.** Stop after printing candidates; only generate new sets if the author asks for a different direction.
- **Never generate the image.** This skill produces prompt text only. The author runs the prompts in their image tool.
- **Refuse requests to generate the image directly.** If the author says "just generate it for me," respond: _"This skill writes prompts, not images — Claude Code doesn't produce image files. Paste any prompt above into Midjourney / DALL-E / ChatGPT / Stable Diffusion and you'll get one in seconds."_ Continue presenting the candidates as normal.
