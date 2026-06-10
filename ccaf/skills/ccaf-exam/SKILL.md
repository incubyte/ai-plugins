---
name: ccaf-exam
description: "Engine for the /ccaf:mock-exam mock exam. Assembles a 60-question CCAF mock (all questions generated fresh per attempt, anchored to a self-authored reference bank and independently verified), administers it 4 questions per screen with resumable progress, and scores it on the real 100–1000 band with a 720 pass line. Use when running or resuming /ccaf:mock-exam."
user-invocable: false
---

# CCAF Mock Exam Engine

You administer a faithful **mock** of the Claude Certified Architect – Foundations (CCAF) exam.
Three phases — **assemble → administer → score** — over one resumable attempt file. Be calm and
exam-like: no hints, no answer keys shown mid-exam, no chit-chat between questions.

All state lives in two local files, written **only** through the pre-approved helper so there
are no permission prompts: `~/.claude/ccaf-exam.local.md` (the **questions file** — stems,
options, case blocks; write-once, key-free) and `~/.claude/ccaf-exam.local.answers.md` (the
**answers file** — keys + recorded answers + progress; small and rewritten per screen). You
never need to read the answers file: `get` returns the key-free questions file, and progress
comes from `get --field` / `blanks`. This keeps answer keys out of the conversation entirely.

```
"${CLAUDE_PLUGIN_ROOT}/scripts/ccaf-exam.sh" <init|get|record|blanks|audit|score|clear> [...]
```

Read-only authority: `${CLAUDE_PLUGIN_ROOT}/data/ccaf-blueprint.md` (domains, weights, scenarios,
in/out-of-scope, scoring) and `${CLAUDE_PLUGIN_ROOT}/data/ccaf-question-bank.md` (12 self-authored
**reference** questions — style/difficulty anchors only, never served). Read both before assembling.

## On startup — resume / fresh / recover

1. If `$ARGUMENTS` is `fresh`: run `ccaf-exam.sh clear`, then go to **Assemble**.
2. Otherwise read the current status: `ccaf-exam.sh get --field status`.
   - **Command fails with "no active exam"** → no attempt exists → go to **Assemble**.
   - **`in_progress`** → read `ccaf-exam.sh get --field next_index`. Greet:
     *"Welcome back — you're on question N of 60."* Ask via **AskUserQuestion**:
     *Resume* (continue from `next_index`, same stored questions) / *Start fresh* (clear + reassemble).
   - **`completed`** → tell them the previous attempt is finished. Ask via **AskUserQuestion**:
     *Start a fresh attempt* / *Cancel*. A fresh attempt clears and reassembles.
   - **Anything else — empty/unrecognized status, or the file isn't a valid exam file** (missing
     frontmatter, truncated blocks): treat as **malformed**. Explain briefly, do **not** score or
     administer it, and offer *Start fresh* / *Cancel* via AskUserQuestion. Never crash; never
     score a damaged attempt; never assemble over it without the candidate choosing Start fresh
     (the helper's `init` refuses to overwrite an in-progress attempt — clear first).

## Assemble

Goal: a frozen, well-formed 60-question exam written to the attempt file.

1. **Pick scenarios.** Choose **4 of the 6** scenarios at random (vary the choice across attempts;
   don't always pick the same four). The six slugs and their case-study briefs are in the blueprint.
2. **Domain quotas (hard constraint).** Exactly: **D1=16, D2=11, D3=12, D4=12, D5=9** (= 60).
   `init` enforces this deterministically and refuses a mis-weighted exam.
3. **Reference anchors — never served.** Read the 12 bank questions as few-shot anchors for
   style, difficulty, and distractor construction only. Do **not** copy any bank question — or a
   near-verbatim variant of one — into the exam: the bank ships in the repo with answers and
   explanations, so candidates may have already read it. Every served question is freshly
   generated (`init` rejects any `source: authored` / `id: seed-*` block).
4. **Generate all 60 questions**, honoring the quotas and spread across the chosen scenarios.
   Each question:
   - is set inside its scenario's **case-study brief** (answerable from brief + stem; may add
     detail, must never contradict the brief);
   - tests a task statement for its tagged domain (see blueprint), stays strictly **in-scope**, and
     never touches an **out-of-scope** topic;
   - has one clearly-correct option and three plausible-but-wrong distractors;
   - matches the bank questions' style and difficulty without reusing their stems or options.
5. **Verify every question independently.** For each, run an *independent* check that did
   **not** see your authoring rationale — prefer spawning a fresh subagent via the Task tool that
   receives only the question + options and must (a) pick the single defensible answer and (b) flag
   any second-correct or implausible distractor. Reject and regenerate any question that fails
   (budget ~3 tries); if it still fails, substitute a fresh in-domain question.
6. **Shuffle answer positions.** For every question (seed and generated), place the correct option
   at a varied A–D position — keep each letter at roughly 15 (stay within 13–17) so the key
   carries no positional pattern. (`init` rejects a degenerate spread.)
7. **Group into case-study sections.** Order the 60 questions so each scenario's questions are
   **contiguous** (4 sections, like the real exam), domains mixed within each section. Each
   section opens with its `[[CASE:<slug>]]` block — placed **directly before its first question**,
   not gathered at the top — whose `title:` and `brief:` are copied **verbatim** from the
   blueprint's case-study briefs. `init` rejects interleaved sections, a duplicated case block,
   or any question sitting under a different scenario's case block.
8. **Write the attempt** by piping the assembled body to `ccaf-exam.sh init` (one call, via
   stdin — never the Write/Edit tools). `init` validates the payload, then splits it itself:
   stems/options/case blocks go to the questions file, keys and answer slots to the separate
   answers file. Use exactly this payload schema:

```
---
status: in_progress
total: 60
scenarios: <slug1>,<slug2>,<slug3>,<slug4>
next_index: 1
---
[[CASE:code-generation]]
title: Code Generation with Claude Code
brief: <copied verbatim from the blueprint — one logical line>
[[Q1]]
domain: D3
scenario: code-generation
source: generated
id: gen-01
stem: <question text — keep to one logical line; no blank lines inside the block>
A) <option>
B) <option>
C) <option>
D) <option>
answer_key: A
user_answer:
[[Q2]]
...
```

Rules for the body: one `[[CASE:<slug>]]` block (with `title:` + `brief:`) before each scenario
section; one `[[Q<n>]]` block per question numbered 1..60 in order; each question block has
`domain:`, `scenario:`, `source: generated` (always — bank questions are never served), a fresh
`id:` (`gen-<n>`), `stem:`, the four options, `answer_key:` (the correct letter after shuffling),
and an empty `user_answer:`. Keep every block free of blank lines — the helper parses
`user_answer:` as the question-block terminator.

After writing, run `ccaf-exam.sh audit` → must end `composition=OK` (it also prints the per-domain
histogram). `init` itself refuses a malformed body, a quota violation, a missing case block, a
biased key spread, or a mid-attempt overwrite — on refusal, fix the body and re-pipe; never fall
back to Write/Edit. Then tell the candidate their exam's composition in one short block: the 4
case studies chosen and the fixed domain distribution (16/11/12/12/9).

## Administer

Before the first screen of a new attempt, state once: *"Heads-up: the real CCAF allows
120 minutes for 60 questions (~2 min each). This mock is untimed and doesn't track time —
pace yourself if you want realistic conditions."*

**Read the exam once, not per screen.** At the start of administration (fresh or resumed), run
`ccaf-exam.sh get` a single time and keep every stem, option, and `[[CASE]]` brief in context —
the output is the key-free questions file, so no answer key ever enters the session. Between
screens, do **not** re-read it, and never read the answers file at all. (Re-read only after a
crash/resume, or if a helper call errors.) Then loop:

1. On entry, read `get --field next_index` once; after that, track position yourself — you know
   which questions each screen presented. When every question has been presented and recorded,
   go to the **finish line** below.
2. Take the next **up to 4** unanswered questions starting from the current position **from the
   same case-study section** — screens never mix case studies (a section's last screen may have
   fewer than 4).
3. Immediately before the AskUserQuestion call, print the section's case as a short text block —
   every screen, so the case stays visible like the real exam:
   *"**Case study — <title>** (Q<m>–Q<n> of 60): <brief>"*
   The brief you print **must** be the `[[CASE]]` block matching the `scenario:` tag of the
   questions on *this* screen — derive it from the questions, never carry the previous screen's
   brief forward. When a screen starts a new section, announce the switch first:
   *"Case study 2 of 4 — <title>"*. (The file guarantees this is unambiguous: each case block
   directly heads a contiguous run of its own questions; `init` rejects any other layout.)
4. Present the questions in **one AskUserQuestion call** (up to 4 per screen), each as a
   single-select with the four options A–D. Show the stem and options **only** — never the
   `answer_key`, never an explanation, never whether a prior answer was right.
5. When the candidate submits the screen, **persist and advance in the same response** so the
   next questions appear without waiting on the save:
   - launch the screen's batched record **in the background** (Bash `run_in_background: true`):
     `ccaf-exam.sh record --q 5 --answer A --q 6 --answer C --q 7 --answer B --q 8 --answer D`
   - and, in that same response, print the next screen's case block (step 3) and issue its
     AskUserQuestion (step 4).
   The helper serializes concurrent writes through a lock, so back-to-back screens cannot
   corrupt the file. If a background record reports failure, stop presenting, re-run that exact
   record in the foreground (the answers are still in your context), then continue.
6. Repeat.

**Finish line (before Score).** Record the **final** screen in the *foreground* (no background),
then confirm `get --field next_index` prints `61`. If it prints ≤ 60, a save was lost or
questions were declined: run `ccaf-exam.sh blanks` to list the unanswered numbers, re-record
(foreground, from your in-context answers) any the candidate actually answered, and re-present
only the genuinely unanswered ones — or apply the submit-incomplete path below. Never score
while an in-flight record could still land.

**Free-text ("Other") responses.** AskUserQuestion adds an automatic *Other* field. If the text
unambiguously names one option (a letter A–D, or a near-verbatim match of one option's text),
record that letter. Anything else — "skip", "pass", blank, commentary — is a **decline**: leave
the question unrecorded and move on. Never answer questions about the material, never explain,
never confirm or deny a guess; reply only "noted" and continue the exam.

**Changing an answer.** If, before submission, the candidate asks to change an earlier question's
answer (e.g. "change Q12 to B"), re-record it with `ccaf-exam.sh record --q 12 --answer B` — the
helper overwrites in place. The real exam lets candidates revise before submitting; so does this.

**Declined questions & submitting incomplete.** A declined question stays blank in the file;
continue forward through the remaining screens rather than bouncing back mid-exam. At the
**finish line**, re-present the blanks **once** (grouped, under their case blocks, ≤4 per
screen). If the candidate declines again, or asks to finish/submit at any point: ask once via
AskUserQuestion — *"Return to the N unanswered question(s)"* / *"Submit incomplete (unanswered
score as incorrect)"*. On submit, go to **Score** using `score --partial`. Never re-present the
same question a third time; never loop endlessly.

Do not capture or report time at any point.

## Score

1. Run `ccaf-exam.sh score` (or `ccaf-exam.sh score --partial` when the candidate chose to submit
   with unanswered questions — plain `score` refuses blanks as a safety check). It prints:
   ```
   correct=<n>/60
   scaled=<100..1000>
   verdict=<PASS|FAIL>
   domain=D1 correct=.. total=..   (one line per D1..D5)
   ```
   and marks the file `completed`.
2. Render a result screen like the real exam, e.g.:

   ```
   CCAF Mock Exam — Result (estimated)
   Scaled score: 790 / 1000      PASS   (pass line: 720)

   Per-domain:
     D1 Agentic Architecture & Orchestration     13/16
     D2 Tool Design & MCP Integration             8/11
     D3 Claude Code Configuration & Workflows    10/12
     D4 Prompt Engineering & Structured Output    9/12
     D5 Context Management & Reliability           6/9   ← weakest
   ```
3. Add the disclaimer verbatim in spirit: *"This scaled score is an estimate
   (scaled = 100 + 15 × correct, a linear mapping over the real 100–1000 band). It is NOT
   Anthropic's proprietary equating curve. Treat 720+ here as a readiness signal, not a guarantee."*
4. If PASS: note they're in good shape to book the real exam. If FAIL: point at the weakest
   domain(s) from the breakdown as where to study. Do not persist, export, or share the result —
   it's shown in the terminal only.

## Integrity note

Answer keys live in a separate local answers file (needed for resume and scoring) that this
skill never reads during administration — so keys cannot appear in the conversation, even by
accident. This remains an honor-system gate: a candidate *can* open the answers file, and doing
so only cheats them before a paid attempt. Do not build obfuscation; just never read or display
the answers file outside of the helper's own scoring.
