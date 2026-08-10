---
name: ccaf-exam
description: "Engine for the /ccaf:mock-exam mock exam. Assembles a 60-item CCAF mock mixing multiple-choice and multiple-response items (all generated fresh per attempt, anchored to a self-authored reference bank and independently verified), administers it 4 items per screen with resumable progress, and scores it on the real 100–1000 band with a 720 pass line. Use when running or resuming /ccaf:mock-exam."
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

Read-only authority: `${CLAUDE_PLUGIN_ROOT}/data/ccaf-blueprint.md` (domains, weights, the 30 task
statements, item composition, scenarios, in/out-of-scope, scoring) and
`${CLAUDE_PLUGIN_ROOT}/data/ccaf-question-bank.md` (30 self-authored **reference** questions, one
per task statement — style/difficulty/format anchors only, never served). Read both before assembling.
`${CLAUDE_PLUGIN_ROOT}/data/ccaf-prep-guide.md` holds the study routes and certification logistics —
read it only when giving post-result guidance, never for item content.

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

Goal: a frozen, well-formed 60-item exam written to the attempt file.

1. **Pick scenarios.** Choose **4 of the 6** scenarios at random (vary the choice across attempts;
   don't always pick the same four). The six slugs and their case-study briefs are in the blueprint.
2. **Domain quotas (hard constraint).** Exactly: **D1=16, D2=11, D3=12, D4=12, D5=9** (= 60).
   `init` enforces this deterministically and refuses a mis-weighted exam.
3. **Item-format quotas (hard constraint).** Exactly **45 multiple-choice** (`select: 1`),
   **11 choose-two** (`select: 2`), and **4 choose-three** (`select: 3`) — 15 multiple-response
   items, 25% of the exam, matching the real item mix. `init` enforces the multiple-response count
   exactly and caps choose-three at 5. Spread the 15 across domains roughly in proportion to the
   quotas — **D1 4, D2 3, D3 3, D4 3, D5 2** — so no domain is all one format. Every item has
   exactly four options A–D, whatever its `select:` count.
4. **Reference anchors — never served.** Read the 30 bank questions as few-shot anchors for style,
   difficulty, distractor construction, and multiple-response shape only. Each task statement has
   exactly one anchor — read the one matching the task statement you are writing against. Do **not** copy any bank
   question — or a near-verbatim variant of one — into the exam: the bank ships in the repo with
   answers and explanations, so candidates may have already read it. Every served item is freshly
   generated (`init` rejects any `source: authored` / `id: seed-*` block).
5. **Generate all 60 items**, honoring both sets of quotas and spread across the chosen scenarios.
   Each item:
   - is set inside its scenario's **case-study brief** (answerable from brief + stem; may add
     detail, must never contradict the brief);
   - tests one of the **30 task statements** for its tagged domain (see the blueprint syllabus) and
     records it in the block's `task:` field, stays strictly **in-scope**, and never touches an
     **out-of-scope** topic;
   - spreads across task statements rather than clustering — aim to touch most of a domain's task
     statements before repeating one, and never write three items on the same task statement;
   - has exactly `select:` clearly-correct options and the rest plausible-but-wrong distractors,
     built from the domain's common-mistake list;
   - matches the bank questions' style and difficulty without reusing their stems or options.

   For a **multiple-response** item, additionally:
   - **state the count in the stem, in bold, as the last sentence** — `**Select TWO.**` /
     `**Select THREE.**`. Never leave it implicit; the real exam always states it.
   - make each correct option *independently* correct and *distinct* — two options restating the
     same idea is the tell of a badly-built choose-two, and candidates are taught to distrust it.
   - for **choose-three over four options**, remember the item reduces to "identify the one option
     that does not belong", so the single wrong option must be a *near-miss* anti-pattern that a
     partial-knowledge candidate would genuinely accept. If you cannot write it that way, make the
     item choose-two instead. Prefer choose-two as the default multiple-response shape.
6. **Verify every item independently.** For each, run an *independent* check that did **not** see
   your authoring rationale — prefer spawning a fresh subagent via the Task tool that receives only
   the stem, the options, and the required number of responses, and must (a) name exactly that many
   defensible options and (b) flag any extra defensible option or implausible distractor. Reject
   and regenerate any item that fails (budget ~3 tries); if it still fails, substitute a fresh
   in-domain item. A multiple-response item where the verifier picks a different set is a defect,
   not a difficulty win.
7. **Shuffle answer positions.** Place correct options at varied positions. Across the 45
   multiple-choice items keep each letter at roughly 11 (stay within 9–13) so the key carries no
   positional pattern; `init` rejects a degenerate spread. For multiple-response items vary which
   letter combinations carry the key — don't let `AB` dominate.
8. **Group into case-study sections.** Order the 60 items so each scenario's items are
   **contiguous** (4 sections, like the real exam), with domains and both item formats mixed within
   each section. Each section opens with its `[[CASE:<slug>]]` block — placed **directly before its
   first item**, not gathered at the top — whose `title:` and `brief:` are copied **verbatim** from
   the blueprint's case-study briefs. `init` rejects interleaved sections, a duplicated case block,
   or any item sitting under a different scenario's case block.
9. **Write the attempt** by piping the assembled body to `ccaf-exam.sh init` (one call, via
   stdin — never the Write/Edit tools). `init` validates the payload, then splits it itself:
   stems, options, and `select:` counts go to the questions file; keys and answer slots go to the
   separate answers file. Use exactly this payload schema:

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
task: D3.4
scenario: code-generation
source: generated
id: gen-01
select: 1
stem: <item text — keep to one logical line; no blank lines inside the block>
A) <option>
B) <option>
C) <option>
D) <option>
answer_key: A
user_answer:
[[Q2]]
domain: D1
task: D1.5
scenario: code-generation
source: generated
id: gen-02
select: 2
stem: <item text ending in **Select TWO.**>
A) <option>
B) <option>
C) <option>
D) <option>
answer_key: BD
user_answer:
[[Q3]]
...
```

Rules for the body: one `[[CASE:<slug>]]` block (with `title:` + `brief:`) before each scenario
section; one `[[Q<n>]]` block per item numbered 1..60 in order; each item block has `domain:`,
`task:`, `scenario:`, `source: generated` (always — bank questions are never served), a fresh `id:`
(`gen-<n>`), `select:` (1, 2, or 3), `stem:`, the four options, `answer_key:`, and an empty
`user_answer:`.

- `task:` is the task statement the item tests (`D1.1`–`D5.6`). It must **belong to the item's own
  `domain:`** and must exist — D1 has seven task statements, D2 five, D3–D5 six each. `init`
  rejects a tag that is malformed, out of range, or in a different domain. This is what lets the
  score report say *which objective* a candidate keeps missing, so a wrong tag sends them to study
  the wrong thing.
- `answer_key:` must name exactly `select:` letters, **distinct and in A–D order** (`BD`, not `DB`)
  — `init` rejects a key that disagrees with its `select:` count, repeats a letter, or lists
  letters out of order.

Keep every block free of blank lines — the helper parses `user_answer:` as the item-block
terminator.

After writing, run `ccaf-exam.sh audit` → must end `composition=OK` (it also prints the per-domain
and per-`select` histograms). `init` itself refuses a malformed body, a quota violation, a wrong
multiple-response count, a `select:`/key mismatch, a missing case block, a biased key spread, or a
mid-attempt overwrite — on refusal, fix the body and re-pipe; never fall back to Write/Edit. Then
tell the candidate their exam's composition in one short block: the 4 case studies chosen, the
fixed domain distribution (16/11/12/12/9), and the item mix (45 single-answer, 15 multiple-response).

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
4. Present the questions in **one AskUserQuestion call** (up to 4 per screen), each with the four
   options A–D. Read each item's `select:` count from the questions file and set the format from it:
   - `select: 1` → a normal single-select question.
   - `select: 2` or `select: 3` → set **`multiSelect: true`** on that question, and keep the stem's
     `**Select TWO.**` / `**Select THREE.**` sentence visible so the required count is on screen.

   **Map the option fields this way, every time:** each option's `label` is the bare letter —
   `"A"`, `"B"`, `"C"`, `"D"` — and the option's full text goes in its `description`. AskUserQuestion
   expects a label of a few words and an exam option is a whole sentence, so putting the text in
   `label` renders badly and truncates. Put the item's stem in `question` and use the item number as
   the `header` (`"Q12"`).

   Show the stem and options **only** — never the `answer_key`, never an explanation, never whether
   a prior answer was right.
5. **Enforce the response count once.** If a multiple-response item comes back with a different
   number of options than its `select:` count, re-present **that one item** in a fresh
   AskUserQuestion, prefixed with one plain line — *"Q12 asks for exactly TWO responses; you
   selected one."* — and record whatever the second response gives, correct count or not. The real
   exam blocks submission on the wrong count; this is the terminal equivalent. Never re-ask a third
   time, and never silently "fix" a selection by adding or dropping a letter yourself.
6. When the candidate submits the screen, **persist and advance in the same response** so the
   next questions appear without waiting on the save.

   **A multiSelect answer arrives comma-separated** — `"A, B"` — so **join the letters before
   recording**: `A, B` → `AB`. The helper deliberately rejects the raw string rather than guessing,
   so forgetting this produces a loud failure, not a silently mis-recorded answer; but it does stop
   the screen, so strip the separators yourself.
   - launch the screen's batched record **in the background** (Bash `run_in_background: true`),
     passing a multiple-response answer as its letters joined together in any order:
     `ccaf-exam.sh record --q 5 --answer A --q 6 --answer BD --q 7 --answer B --q 8 --answer ACD`
   - and, in that same response, print the next screen's case block (step 3) and issue its
     AskUserQuestion (step 4).
   The helper normalizes each set (uppercased, sorted, de-duplicated) so selection order never
   matters, and serializes concurrent writes through a lock, so back-to-back screens cannot corrupt
   the file. If a background record reports failure, stop presenting, re-run that exact record in
   the foreground (the answers are still in your context), then continue.
7. Repeat.

**Finish line (before Score).** Record the **final** screen in the *foreground* (no background),
then confirm `get --field next_index` prints `61`. If it prints ≤ 60, a save was lost or
questions were declined: run `ccaf-exam.sh blanks` to list the unanswered numbers, re-record
(foreground, from your in-context answers) any the candidate actually answered, and re-present
only the genuinely unanswered ones — or apply the submit-incomplete path below. Never score
while an in-flight record could still land.

**Free-text ("Other") responses.** AskUserQuestion adds an automatic *Other* field. If the text
unambiguously names the option(s) — letters A–D in any form (`B`, `b`, `A and C`, `AC`, `A, C`), or
a near-verbatim match of an option's text — record those letters. Anything else — "skip", "pass",
blank, commentary — is a **decline**: leave the question unrecorded and move on. Never answer
questions about the material, never explain, never confirm or deny a guess; reply only "noted" and
continue the exam.

**Changing an answer.** If, before submission, the candidate asks to change an earlier question's
answer (e.g. "change Q12 to B", or "make Q31 B and D"), re-record it with
`ccaf-exam.sh record --q 12 --answer B` / `--q 31 --answer BD` — the helper overwrites in place. The
real exam lets candidates revise before submitting; so does this.

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
   domain=D1 correct=.. total=.. pct=..   (one line per D1..D5)
   task=D1.4 correct=.. total=..          (one line per task statement the exam tested)
   ```
   and marks the file `completed`.
2. Render a result screen like the real exam — which reports pass/fail, the scaled score, and
   **percent correct per domain**:

   ```
   CCAF Mock Exam — Result (estimated)
   Scaled score: 790 / 1000      PASS   (pass line: 720)

   Per-domain (percent correct, as the real score report shows):
     D1 Agentic Architecture & Orchestration     13/16    81%
     D2 Tool Design & MCP Integration             8/11    73%
     D3 Claude Code Configuration & Workflows    10/12    83%
     D4 Prompt Engineering & Structured Output    9/12    75%
     D5 Context Management & Reliability           6/9    67%   ← weakest
   ```
3. **Name the specific objectives that cost them points.** From the `task=` lines, list the task
   statements where they got **nothing** right, then those they went half on — at most five lines,
   worst first, each with the task statement's short title from the blueprint syllabus. This is the
   most actionable part of the report: "D5 is weak" is a domain, "you missed both D5.2 items" is a
   thing to go read. Skip the section entirely if nothing was missed.

   ```
   Objectives to revisit:
     D5.2  Escalation and ambiguity resolution      0/2
     D4.5  Batch processing strategies              0/1
     D1.3  Subagent invocation and context passing  1/3
   ```
4. Add two notes, in spirit:
   - *"Domain percentages are diagnostic only — like the real exam, pass/fail is decided by the
     total scaled score alone."*
   - *"This scaled score is an estimate (scaled = 100 + 15 × correct, a linear mapping over the real
     100–1000 band). It is NOT Anthropic's proprietary equating curve. Treat 720+ here as a
     readiness signal, not a guarantee."*
5. Give one targeted next step:
   - **PASS with no domain badly trailing** — they're in good shape to book the real exam.
   - **PASS but a domain under ~60%** — say so plainly: a weak domain inside a passing total is a
     coin-flip on a different form. Point at `/ccaf:practice` for that domain before booking.
   - **FAIL** — name the weakest domain(s) and recommend the tutor: *"Your weakest area is D5. Run
     `/ccaf:prepare D5` to work through it turn by turn, then `/ccaf:practice` to drill it, then
     come back for another mock."*

   If they ask what a real attempt costs them, the fee, retake waiting periods, and recertification
   rules are in `data/ccaf-prep-guide.md`. Do not persist, export, or share the result — it's shown
   in the terminal only.

## Integrity note

Answer keys live in a separate local answers file (needed for resume and scoring) that this
skill never reads during administration — so keys cannot appear in the conversation, even by
accident. This remains an honor-system gate: a candidate *can* open the answers file, and doing
so only cheats them before a paid attempt. Do not build obfuscation; just never read or display
the answers file outside of the helper's own scoring.
