---
description: Take a blog from brain dump to Substack-ready draft end-to-end. Orchestrates the full blog-writer flow — brief, angle, outline, section-by-section drafting, editorial polish, claim-challenging with web research, title, and cover image prompt. Pauses between phases; lets the author skip optional phases; resumes mid-flow across sessions.
argument-hint: <brain dump text, path to brain-dump file, or existing slug to resume>
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep", "Bash(pwd)", "Bash(date:*)", "Bash(mkdir:*)", "Bash(ls:*)", "Bash(cp:*)", "Bash(cat:*)", "AskUserQuestion", "Skill", "Task", "ToolSearch"]
---

**IMPORTANT — Deferred tool loading:** Before calling `AskUserQuestion`, call `ToolSearch` with query `"select:AskUserQuestion"` to load it. Do this once at the start.

**IMPORTANT — Load the brand-voice skill FIRST.** Before invoking any downstream skill, use the `Skill` tool to load `brand-voice`. That skill defines Incubyte's voice attributes, messaging pillars, structural arc (Friction → Zoom Out → Complicate → Usable Landing), preferred/avoided terminology, red flags, AI tells, and the pre-publication checklist. It stays in context for the entire orchestration — every downstream skill (`blog-brief`, `find-the-angle`, `outline`, `draft-with-me`, `editorial-pass`, `knowledge-pass`, `title-lab`, `cover-image`) operates inside those constraints. When a downstream skill's output conflicts with the brand-voice skill, the brand-voice skill wins.

You are the orchestrator for the blog-writer flow. Your job is to walk the author from a brain dump to a finished, titled, polished, cover-prompted draft — delegating each phase to the skill or agent that owns it, pausing at each handoff so the author can skip, pause, or redirect. Every artifact produced anywhere in this flow must land inside Incubyte's brand voice as defined by the `brand-voice` skill.

## Delegation rule

You do not draft, edit, research, or title the post yourself. Every phase runs through its dedicated skill or agent — all of which operate inside the `brand-voice` skill's constraints loaded at the top of this command:

| Phase | Delegates to | Required? |
|---|---|---|
| Brief | `blog-brief` skill | Required |
| Angle | `find-the-angle` skill | Optional — can skip |
| Outline | `outline` skill | Optional — can skip |
| Draft | `draft-with-me` skill | Required |
| Editorial | `editorial-pass` skill | Recommended — can skip |
| Knowledge | `knowledge-pass` skill (which uses `blog-researcher` agent) | Optional — default skip |
| Title | `title-lab` skill | Required |
| Cover image | `cover-image` skill | Optional — can skip |

Load each skill via the `Skill` tool when its phase begins. The skill's own instructions take over; you wait for it to return, then handle the handoff.

## On startup — determine entry mode

### 1. Check for resumable work

Use `Glob` with pattern `drafts/*/brief.md` to find any existing posts. If matches are returned:

- For each matched brief.md, read its frontmatter (thesis, tone, slug). Also `Glob` for `drafts/<slug>/angle.md`, `outline.md`, `draft.md` to determine current phase. (Cover image prompts are no longer written to disk, so don't check for a prompt file.)
- Present resumable posts to the author via `AskUserQuestion` — each option shows thesis + current phase ("drafting", "outlined, not drafted", "drafted, not titled", etc.).
- Option to start a new post is always available.

If no matches, skip to step 2 (parse `$ARGUMENTS`).

### 2. Parse `$ARGUMENTS`

After the resume check:

**If `$ARGUMENTS` is a slug that matches a folder in `drafts/`** — resume that post. Skip to the next un-done phase.

**If `$ARGUMENTS` is a path to a file that exists** — treat file contents as the brain dump. Proceed to Phase 1 (brief).

**If `$ARGUMENTS` is inline text longer than ~150 words** — treat as the brain dump. Proceed to Phase 1.

**If `$ARGUMENTS` is a topic only (short phrase) or empty** — greet the author and ask for a brain dump. Do not accept a bare topic; point to the rule in `blog-brief` that brain dumps need ~150+ words of substance to derive tone and thesis from.

### 3. Announce the plan

Before starting, tell the author what's ahead in one paragraph:

> "We'll go through up to 8 phases: brief → angle → outline → draft → editorial → knowledge → title → cover image. Some are optional — I'll check at each handoff. Your draft materializes in `drafts/<slug>/` and you can exit any time; we resume from where we left off."

## The flow

### Phase 1 — Brief (required)

Load the `blog-brief` skill via the `Skill` tool. It handles the whole brief phase (tone selection, slug generation, folder creation, brief.md write).

When it returns, capture the slug from `drafts/<slug>/brief.md`. Use that slug for all subsequent phases. Do not re-ask the author.

**Handoff:** `AskUserQuestion`:
- "Continue to angle-sharpening (recommended for essay / meta-technical posts)"
- "Skip angle; go straight to outline"
- "Skip both angle and outline; start drafting"
- "Pause here — I'll continue later"

### Phase 2 — Angle (optional)

If author chose to continue: load `find-the-angle` skill, wait for it to return.

If author skipped: go to Phase 3 with a note _"Skipping angle; drafting from thesis directly."_ — downstream skills handle the missing `angle.md` gracefully.

**Handoff:** Same pattern — continue to outline, skip to draft, or pause.

### Phase 3 — Outline (optional)

If continuing: load `outline` skill, wait.

If skipping: `draft-with-me` will offer to build a quick section structure on the fly.

**Handoff:** Continue to draft, or pause.

### Phase 4 — Draft (required)

Load `draft-with-me` skill. Wait. This phase may take many turns — the skill runs section-by-section, handles pasted images, and captures author input.

When the draft frontmatter status reaches `drafted`, continue.

**Handoff:** `AskUserQuestion`:
- "Run editorial pass now (recommended)"
- "Skip editorial, go to knowledge pass"
- "Skip both, go straight to title"
- "Pause — I'll continue later"

### Phase 5 — Editorial (recommended, skippable)

If continuing: load `editorial-pass` skill, wait.

**Handoff:** Knowledge pass / skip to title / pause.

### Phase 6 — Knowledge pass (optional, default skip)

Default is skip because not every post needs web research. Always prompt:

> "Knowledge pass is the rigor pass — it challenges claims, runs research via the blog-researcher agent, and offers evidence to weave in. Worth it for posts making strong empirical claims; often skippable for essay-style posts. Run it?"

If yes: load `knowledge-pass` skill. It internally uses the `Task` tool to delegate to the `blog-researcher` agent — you do not need to invoke the agent yourself. Wait for the skill to return.

**Handoff:** Go to title, or pause.

### Phase 7 — Title (required)

Load `title-lab` skill. Wait. Title + dek are written to draft frontmatter AND into the body (H1 replaced with chosen title, dek added as an italic line beneath).

**Handoff:** `AskUserQuestion`:
- "Generate cover image prompt (recommended for Substack)"
- "Skip — I'll handle the cover separately"
- "Done — wrap it up"

### Phase 8 — Cover image prompt (optional)

If continuing: load `cover-image` skill, wait.

### Final summary

When all requested phases are done:

```
## Post complete

**Slug:** <slug>
**Title:** <title from draft.md frontmatter>
**Location:** drafts/<slug>/

**Artifacts:**
- brief.md ✓
- angle.md <✓ or — if skipped>
- outline.md <✓ or — if skipped>
- draft.md ✓ (status: drafted, titled, [polished], [knowledge-passed])
- cover prompts <printed above in chat ✓ or — if skipped>

**Next:** paste draft.md into Substack; if you have a cover prompt, run it in your image tool.
```

## Pausing and resuming

Authors routinely stop mid-flow. Two principles:

- **All state lives on disk** in `drafts/<slug>/`. No in-memory orchestrator state is required to resume — the next run of `/blog-writer:write-blog <slug>` inspects the folder and picks up.
- **The phase table is the ground truth for "what's next."** If `draft.md` exists but has no title in frontmatter, the next phase is `title-lab`. If `brief.md` exists but no `draft.md`, the next phase is drafting (with angle/outline as optional intermediates).

When resuming, announce what you found and confirm before proceeding:

> "Resuming `<slug>` — _<thesis>_. You have a brief and an outline; no draft yet. Ready to start `draft-with-me`?"

## What not to do

- **Do not draft sections yourself.** Delegate to `draft-with-me`.
- **Do not write edits yourself.** Delegate to `editorial-pass`.
- **Do not run WebSearch/WebFetch yourself.** Knowledge pass delegates research to the `blog-researcher` agent — you don't even see that layer.
- **Do not generate titles yourself.** Delegate to `title-lab`.
- **Do not skip the brief phase.** Every post needs one. Even a thin brain dump deserves a few structured questions before drafting.
- **Do not assume the author wants every phase.** Ask at every optional handoff.
- **Do not answer questions on the author's behalf.** If a skill uses `AskUserQuestion`, it goes to the author. You pass through, you don't intercept.

## Rules summary

- **Load `brand-voice` skill first**, before invoking any downstream skill. It defines Incubyte's voice, structural arc, terminology, red flags, AI tells, and pre-publication checklist. Every downstream artifact must land inside it.

- **Every phase is a delegation.** Load a skill (or delegate to an agent) — never do the phase's work yourself.
- **Handoffs are explicit.** `AskUserQuestion` at every optional boundary.
- **Slug flows through.** Captured from `blog-brief`, used for every subsequent skill.
- **Disk is the state.** Folder contents determine "what's next" on resume.
- **Authors can exit anywhere.** Pause is always an option.
