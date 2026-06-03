# Blog Writer

An interactive writing partner for technical and meta-technical blog posts — DevEx, XP, TDD, quality, architecture, or anything else you think out loud about.

The plugin treats *you* as the source of truth. Your brain dump, your scars, your opinions — that's the blog. Claude's job is to render your thinking as prose, then push back on it like a tough editor would.

## Two commands — for A/B testing

There are currently two commands with different workflows. Try both on real posts; the one you prefer stays and the other goes.

### `/blog-writer:write-blog <brain dump | file path | slug>` — multi-phase

End-to-end orchestration through eight phases with explicit handoffs: brief → (angle) → (outline) → draft → (editorial) → (knowledge) → title → (cover). Parenthesized phases are optional; you pause, skip, or redirect at each handoff. Section-by-section drafting with accept / reject / rewrite. Research (claim challenge) runs near the end of the flow.

**Pros:** fine-grained author control at every step; dedicated skills for each concern; research-as-audit catches claims you committed to prose.
**Cons:** many decision points; session-long; research arrives *after* drafting, so findings can force expensive rework.

### `/blog-writer:write <brain dump | file path | slug>` — streamlined

One-batch Q&A then a clean draft, then an annotation loop: brain dump → silent triage + research → one informed Q&A batch → clean drafted post → you annotate with `@bw` in your editor where you want changes → revise loop → title → (optional cover).

**Pros:** few decision points; research informs the questions and draft from the start; you interact only with the parts you want changed.
**Cons:** single-pass drafting relies on the Q&A being thorough enough up front; less granular "I want to reshape this mid-draft" control.

All state persists in `drafts/<slug>/`; resume either command across sessions.

## The skills (used by `/blog-writer:write-blog` and activated by trigger phrase)

Skills aren't slash commands — they activate when you describe what you want. Say any of the trigger phrases in conversation and the matching skill takes over. The `write-blog` orchestrator calls them automatically; you can also invoke them standalone. The streamlined `/blog-writer:write` command does NOT call these skills (it handles framing, drafting, and revision inline — except for `brand-voice`, `title-lab`, and `cover-image`, which both commands use).

**The `brand-voice` skill is loaded at the top of both commands and stays in context for the entire run.** It defines Incubyte's voice attributes, messaging pillars, structural arc, preferred / avoided terminology, red flags, AI tells, and the pre-publication checklist. Every downstream decision — tone candidates, draft generation, editorial polish, title selection — operates inside its constraints. When a downstream skill's output conflicts with brand-voice guidance, brand-voice wins.

| Skill | Trigger phrases | What it does |
|---|---|---|
| `brand-voice` | auto-loaded by both commands; also: "brand voice", "Incubyte voice", "style guide", "AI tells", "check brand consistency" | Incubyte's voice attributes, messaging pillars, structural arc (Friction → Zoom Out → Complicate → Usable Landing), preferred/avoided terms, red flags, AI tells, pre-publication checklist. Constraints every other skill's output. |
| `blog-brief` | "start a new blog", "I have a brain dump", "blog brief" | Brain dump → thesis, audience, takeaway, tone → `drafts/<slug>/brief.md` |
| `find-the-angle` | "sharpen my angle", "find the angle", "my thesis is too generic" | Interrogate for scars / reversals / contrarian beliefs → 2–3 angle candidates → `angle.md` |
| `outline` | "outline this", "structure the post", "build the outline" | 3–6 sections with purpose and material pointers, arc-shape matched to tone → `outline.md` |
| `draft-with-me` | "draft with me", "start drafting", "draft the blog" | Section-by-section draft from your material only. Accept / reject / rewrite / skip. Captures pasted images. |
| `editorial-pass` | "editorial pass", "polish the draft", "line edits" | Line-level craft with before/after and Kept/Cut. Tone preserved. |
| `knowledge-pass` | "knowledge pass", "challenge my claims", "fact check", "find supporting evidence" | Challenge claims; delegate research to the `blog-researcher` agent; weave in citations. |
| `title-lab` | "title lab", "title this post", "help me find a title" | 5–8 titles across strategies with tradeoffs + matching deks. Written to draft frontmatter and injected into the body (H1 replaced, dek as italic line beneath). |
| `cover-image` | "cover image", "image prompt", "generate cover image prompt" | 2 distinct cover prompts for Midjourney/DALL-E/ChatGPT; iterate until approved. Prompt only — never generates the image itself. |

## The agent

| Agent | Called by | What it does |
|---|---|---|
| `blog-researcher` | `knowledge-pass` skill (multi-phase flow) and the `write` command (streamlined flow, during framing) | Finds 2–3 substantive web sources per claim, with stance (supports / complicates / refutes) and honest synthesis. Returns findings; never modifies the draft. |

## Artifact layout

Every post lives in its own folder in whatever directory you invoked from:

**Multi-phase (`write-blog`)** produces multiple artifacts:
```
drafts/<slug>/
  brief.md, angle.md, outline.md, draft.md, images/
```

**Streamlined (`write`)** produces one authored file:
```
drafts/<slug>/
  draft.md                  # frontmatter (thesis, audience, tone, arc, title, dek) + prose
  images/
```

Cover image prompts, when you ask for them, are printed in chat — not saved to disk. You copy them into your image tool directly.

State is on disk, not in memory. Resume with `/blog-writer:write-blog <slug>` or `/blog-writer:write <slug>`.

## Principles

1. **Your core, rendered.** Claude never invents claims, opinions, experiences, tradeoffs, or sources. Material comes from you (brief + angle + brain dump + conversation) or — for research only — from the `blog-researcher` agent, which reports findings honestly rather than fabricating.
2. **Accept / reject, one chunk at a time.** Every revision is an offer you can take or refuse. You're always in control of the prose.
3. **Tone is explicit.** Picked during `blog-brief`, preserved by every downstream skill.
4. **Challenge is a feature.** `knowledge-pass` pushes hard on claims. That's the point.
5. **Conversation over report.** Skills talk with you; they don't hand back a marked-up dump.
6. **Minimum commands for the task.** While A/B testing, there are two commands (`write-blog` and `write`). When a winner is picked, the loser is removed and the plugin returns to a single command.

## Install

As part of the Incubyte marketplace:

```
/plugin install blog-writer@incubyte-plugins
```

## Version

0.3.0 — A/B test pair shipped. Two commands (`write-blog`, `write`), 8 skills, 1 agent. Pick a winner and the loser is removed.
