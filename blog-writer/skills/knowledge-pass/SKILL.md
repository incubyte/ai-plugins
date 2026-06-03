---
name: knowledge-pass
description: "Challenge claims in the draft aggressively and proactively search the web for supporting studies, data, or prior art — then offer to weave findings into the post with citations. Triggers: 'knowledge pass', 'fact check', 'challenge my claims', 'find supporting evidence', 'rigorous review', 'verify my argument', 'research my claims'. Runs after the draft exists and before publish. Delegates web research to the blog-researcher agent so findings don't pollute the main conversation. Surfaces missing tradeoffs, hand-waving, oversimplifications, and claims that would benefit from evidence. Every insertion is accept/reject."
---

# Knowledge Pass

**IMPORTANT — Deferred tool loading:** Before calling `AskUserQuestion`, call `ToolSearch` with query `"select:AskUserQuestion"` to load it. Do this once at the start. (Web research is delegated to the blog-researcher agent; this skill does not call WebSearch/WebFetch directly.)

A draft with no rigor reads like an opinion column; a draft with rigor earns the reader's trust. This skill is the tough-editor pass: challenge claims, find evidence, name tradeoffs, refuse to paper over hand-waving.

## The posture

This skill is allowed — encouraged — to push hard. It treats every testable claim as something the reader might doubt. It asks "source or strike?" It names missing tradeoffs explicitly. But it's still the author's post: every change is proposed, every weaving of research is accept/reject. The skill does not edit the draft unilaterally.

## Why this matters

Most technical posts have two failure modes:
- **Unsupported strong claims** — "Studies show X" with no study; "Most teams Y" with no data.
- **Missing tradeoffs** — a solution presented as all upside; a practice praised without naming its failure modes.

Either one makes an experienced reader bail. Rigor is not footnotes; it's refusing to make a claim bigger than what you can defend.

## Inputs

- `drafts/<slug>/brief.md` — for thesis, audience, tone.
- `drafts/<slug>/draft.md` — required. The prose to pressure-test.

If no `<slug>` passed, list `drafts/*/`. If `brief.md` is missing, point to the `blog-brief` skill. If `draft.md` is missing, point to the `draft-with-me` skill (say 'draft with me'). Or direct the author to `/blog-writer:write-blog` for end-to-end orchestration.

## The pass

### 1. Scan for claim types

Read the draft once. Categorize claims into types:

**Type A — Factual assertions that cite or should cite.**
- "_Stripe's docs say..._" → citeable; check it
- "_Most companies do X..._" → unsupported; flag
- "_A 2019 study found..._" → citeable; verify

**Type B — Causal claims.**
- "_TDD reduces defect rate_" → what's the evidence? Every causal claim asks for one.

**Type C — Generalizations.**
- "_Senior engineers don't do Y_" → how do you know? Sample size? Selection bias?

**Type D — Hand-waving / jargon shortcuts.**
- "_X just works because of Y_" → does it? How?
- "_This is obviously Z_" → obvious to whom?

**Type E — Missing tradeoffs.**
- A solution section that lists no downsides.
- A practice advocated without naming when it fails.

**Type F — Missing context for the audience.**
- Something the audience won't recognize; the author assumed they would.

List every instance, grouped by type. Do not skip claims you suspect are true; the reader will still ask "source?"

### 2. Present the list; ask how hard to push

Before acting on the list, check with the author via `AskUserQuestion`:

> "Scanned the draft. Found [N] claims that could use evidence (Types A–C), [M] hand-waving spots (Type D), and [K] missing-tradeoff flags (Type E/F). How aggressive a pass do you want?
>
> - **Tough** — challenge every flagged item; search for evidence on each citeable claim. Expect ~30 min.
> - **Selective** — I show you the list, you pick which to challenge. Fast and focused.
> - **Just the structural flags** — skip claim-by-claim; only surface missing tradeoffs and missing context. Shortest."

This lets the author scope the pass. Default lean: selective.

### 3. For each claim the author wants challenged

Per claim:

**a. State the challenge.** Quote the specific sentence from the draft. Name the type. Ask what's behind it:

> "Draft says: _'TDD reduces defect rate significantly for teams with moderate complexity.'_
>
> This is a causal claim with a quantifier ('significantly'). Do you have a source for this, or is it from your own experience? If experience, is it one team or many?"

**b. If the author has a source,** help them integrate it (see step 4).

**c. If the author doesn't have a source and wants one,** delegate to the **blog-researcher** agent via the `Task` tool. Pass:

- The claim verbatim
- The draft's thesis and audience (from brief.md) — so the researcher knows what kind of source lands for this reader
- Whether the author wants: supporting sources, opposing sources, or both (to name tradeoffs honestly)

The researcher returns 2–3 sources with URL, title, 2–3 sentence finding, and stance. It does NOT modify the draft.

**d. If the claim can't be sourced and the author doesn't want to soften it,** surface the tradeoff honestly:

> "If we can't source this, the options are: soften to 'in my experience' (honest and fine), cut it (if it's not load-bearing), or leave it (reader may challenge it — that's a risk you own)."

Let the author choose. Don't moralize.

### 4. Weaving research into the draft

When the blog-researcher returns findings:

**a. Show the findings.** Summarize each source in 2–3 lines: _"Smith et al. 2019 found X in a controlled study of Y; supports the claim but with caveat Z."_

**b. Propose an integration.** Offer 1–2 concrete ways to weave the source in:
- Inline citation: _"A 2019 study of 150 teams (Smith et al.) found TDD adopters shipped 40% fewer post-deploy hotfixes."_
- Footnote / link at end of paragraph
- Rewriting the claim to be honest about the source's specific scope

**c. Accept/reject via `AskUserQuestion`.** Options: apply proposal A / apply proposal B / modify it / skip this one.

**d. If accepted,** use `Edit` on `draft.md` to apply the change. Do not accumulate a batch of edits and apply all at once — apply immediately so the file stays in sync with what the author agreed to.

### 5. Handling missing tradeoffs (Type E)

For each section that advocates without naming tradeoffs, propose a short concessive paragraph. Example:

> "Section 3 advocates TDD as feedback design. It doesn't name any failure modes. A short concession paragraph — _'This breaks down in contexts X and Y'_ — would earn the reader's trust. Here's a proposed version: [draft the paragraph from the author's brain dump / conversation only, not invented content]. Accept, reject, or modify?"

**Never invent a tradeoff the author didn't name.** If the author has no tradeoffs in mind, ask them what they'd be — then draft from their answer. This is the same no-invention rule as `draft-with-me`.

### 6. Handling missing context (Type F)

For each "audience won't know this" flag:

> "Paragraph 5 uses 'continuous compaction' without defining it. Audience is senior ICs; most know Kafka-style compaction, fewer know RocksDB-style. Want a one-sentence gloss, a hyperlink to a primer, or leave it?"

Short glosses are usually the right answer for a knowledgeable audience.

## What this skill does NOT do

- **No line editing.** That's `editorial-pass`.
- **No structural rewrites.** Surface structural issues as a note at the end if the draft's argument is broken, but don't restructure here.
- **No tone reshaping.** Preserve the tone from `brief.md` on every insertion. Research citations should blend into the author's voice, not read like academic paper apparatus in a reflective essay.
- **No unilateral edits.** Every change is accept/reject.
- **No invented tradeoffs or evidence.** Research comes from the researcher agent; tradeoffs come from the author.

## Finishing

After the pass:

1. Summarize: _"Challenged [N] claims. [M] had sources the author provided. [K] new sources integrated with citations. [J] claims softened. [L] tradeoff paragraphs added. [P] context glosses."_
2. Surface any unresolved items — claims the author chose to leave unsourced, tradeoffs not addressed — as a final note the author can choose to address or ship with.
3. Suggest next step:

> "Knowledge pass done. Remaining unresolved: [list]. Next: say 'title lab' to activate the `title-lab` skill, or resume with `/blog-writer:write-blog <slug>`."

## Rules

- **Every challenge quotes the specific sentence.** No vague "paragraph 3 feels hand-wavy."
- **Delegate research to blog-researcher via Task.** Do not run WebSearch/WebFetch directly.
- **Accept/reject per insertion.** Apply immediately with `Edit` once accepted.
- **Never invent tradeoffs or facts.** Research comes from agent; tradeoffs come from author.
- **Preserve tone.** Citations fit the voice of the post.
- **Scope the pass first.** Ask tough / selective / structural before starting.
