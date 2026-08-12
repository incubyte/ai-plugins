---
name: ccaf-practice
description: "Engine for the /ccaf:practice command. Asks which specific CCAF domains to focus on and how many questions (10/20/30), assembles a proportionally-weighted partial exam of single-answer multiple-choice items, anchored to the reference bank and independently verified, administers it 4 items per screen with resumable progress, and scores it with a per-domain performance chart. Attempt state lives in ~/.claude/ccaf-practice.local.md — separate from /ccaf:mock-exam. Use when running or resuming /ccaf:practice."
user-invocable: false
---

# CCAF Practice Engine

You run a focused CCAF practice session covering only the domains the candidate selects.
Four phases — **domain selection → assemble → administer → score** — over one resumable
attempt file. Keep it calm and focused: no hints, no answer keys shown mid-session, no
chit-chat between questions.

All state lives in two local files, written **only** through the pre-approved helper so there
are no permission prompts: `~/.claude/ccaf-practice.local.md` (the **questions file** —
stems, options, case blocks; write-once, key-free) and
`~/.claude/ccaf-practice.local.answers.md` (the **answers file** — keys + recorded answers +
progress; small and rewritten per screen). These are **separate** from the `/ccaf:mock-exam`
files — practice sessions never touch `~/.claude/ccaf-exam.local.md`. You never need to read
the answers file: `get` returns the key-free questions file, and progress comes from
`get --field` / `blanks`. This keeps answer keys out of the conversation entirely.

Always set `CCAF_EXAM_FILE` so the helper writes to the practice files, not the mock-exam
files. All `ccaf-exam.sh` references in this skill assume this prefix:

```
CCAF_EXAM_FILE=~/.claude/ccaf-practice.local.md \
  "${CLAUDE_PLUGIN_ROOT}/scripts/ccaf-exam.sh" <init|get|record|blanks|audit|score|clear> [...]
```

Read-only authority: `${CLAUDE_PLUGIN_ROOT}/data/ccaf-blueprint.md` (domains, weights, the 30 task
statements, item composition, scenarios, in/out-of-scope, scoring) and
`${CLAUDE_PLUGIN_ROOT}/data/ccaf-question-bank.md` (30 self-authored **reference** questions, one
per task statement — style/difficulty/format anchors only, never served). Read both before assembling.

## On startup — resume / fresh / recover

1. If `$ARGUMENTS` is `fresh`: run `ccaf-exam.sh clear`, then go to **Domain Selection**.
2. Otherwise read the current status — suppress stderr so a missing file does not show as a
   red error: `ccaf-exam.sh get --field status 2>/dev/null || echo "no active exam"`.
   - **"no active exam"** → no attempt exists → go to **Domain Selection**.
   - **`in_progress`** → read `ccaf-exam.sh get --field next_index` and
     `ccaf-exam.sh get --field total`. Greet:
     *"Welcome back — you're on question N of <total>."* Ask via **AskUserQuestion**:
     *Resume* (continue from `next_index`, same stored questions) / *Start fresh*
     (clear + new domain selection).
   - **`completed`** → tell them the previous attempt is finished. Ask via **AskUserQuestion**:
     *Start a fresh attempt* / *Cancel*. A fresh attempt clears and goes to Domain Selection.
   - **Anything else — empty/unrecognized status, or the file isn't a valid exam file**
     (missing frontmatter, truncated blocks): treat as **malformed**. Explain briefly, do
     **not** score or administer it, and offer *Start fresh* / *Cancel* via AskUserQuestion.
     Never crash; never score a damaged attempt; never assemble over it without the candidate
     choosing Start fresh (the helper's `init` refuses to overwrite an in-progress attempt —
     clear first).

## Domain Selection

The `AskUserQuestion` tool supports at most 4 options per question. Use two sequential
multiSelect questions to cover all five domains without any non-domain filler options.

**Question 1** (multiSelect, 3 options) — "Which domains would you like to practise?":

- D1: Agentic Architecture & Orchestration
- D2: Tool Design & MCP Integration
- D3: Claude Code Configuration & Workflows

**Question 2** (multiSelect, 2 options) — "Select from remaining domains:":

- D4: Prompt Engineering & Structured Output
- D5: Context Management & Reliability

Combine the answers: `selected_domains = [all checked options across both questions]`. If
the combined list is empty (nothing selected in either question), explain that at least one
domain is required and re-ask from Question 1.

**Question count** (single-select, 3 options) — "How many questions?":

Before showing this prompt, compute the per-domain question count for each of the three
total options using the **real exam blueprint weights** as the authority
(D1=16, D2=11, D3=12, D4=12, D5=9 out of 60) — never assign counts arbitrarily:

  W = sum of blueprint weights of the selected domains
  quota(d) = floor(count × blueprint_weight(d) / W)
  remainder (count − Σquotas) → add to the domain with the highest blueprint weight

Show the computed per-domain counts as each option's description so the candidate sees
exactly what they will get before choosing. Example for D1 + D3 selected (W = 28):

- "10 questions" with description "D1: 6  |  D3: 4"
- "20 questions" with description "D1: 11  |  D3: 9"
- "30 questions" with description "D1: 17  |  D3: 13"

Compute at runtime for whatever domains the candidate actually selected — do not hardcode.
Set `total` from the chosen option, then go to **Assemble**.

## Assemble

Goal: a frozen, well-formed partial exam written to the attempt file.

1. **Pick scenarios.** Choose at random: **1 scenario** for total=10, **2 scenarios** for
   total=20 or 30. Pick from any of the 6 slugs in the blueprint (vary across attempts).
2. **Domain quotas (proportional, hard constraint).** Blueprint weights:
   D1=16, D2=11, D3=12, D4=12, D5=9. For the selected domains only:
   - W = sum of blueprint weights of the selected domains
   - quota(d) = floor(total × weight(d) / W) for each selected domain d
   - Assign any remainder (total − Σquotas) to the selected domain with the largest weight
   - Example: D2 + D4, total=20 → W=23, D2=floor(20×11/23)=9, D4=11
3. **Item format (hard constraint).** Every item is **single-answer**: four options A–D, exactly
   one correct, three plausible distractors. `init` refuses any answer key that is not a single
   letter. This diverges deliberately from the real exam, which also uses multiple-response items —
   see the blueprint. Never write an item that asks for two or three responses.
4. **Reference anchors — never served.** Read the 30 bank questions as few-shot anchors for style,
   difficulty, and distractor construction only. Each task statement has
   exactly one anchor — read the one matching the task statement you are writing against. Do **not** copy any bank
   question — or a near-verbatim variant of one — into the session: the bank ships in the repo with
   answers and explanations, so candidates may have already read it. Every served item is freshly
   generated (`init` rejects any `source: authored` / `id: seed-*` block).
5. **Generate all `total` items silently.** Honor the domain quotas, draw only from the selected
   domains, and spread across the chosen scenarios. Do **not** print stems, options, or running
   commentary to the user — keep all item data in context and proceed directly to verification.
   Each item:
   - is set inside its scenario's **case-study brief** (answerable from brief + stem; may add
     detail, must never contradict the brief);
   - tests one of the **30 task statements** for its tagged domain (see the blueprint syllabus) and
     records it in the block's `task:` field, stays strictly **in-scope**, and never touches an
     **out-of-scope** topic;
   - spreads across the domain's task statements rather than clustering on one or two — with only a
     handful of items per domain, prefer distinct task statements so the result names distinct gaps;
   - has one clearly-correct option and three plausible-but-wrong distractors, built from the
     domain's common-mistake list;
   - matches the bank questions' style and difficulty without reusing their stems or options.
6. **Verify questions in one parallel batch.** Split the items into groups of ~5. Then, in
   a **single response**, call the Task tool once for every group simultaneously — all with
   `run_in_background: true`. Do **not** call Task, wait for the result, and call Task again;
   all launches must be in the same tool-call batch with no barrier between them. Each agent
   receives only the stems and options for its group — no answer keys — and must return a per-item
   verdict (`pass` or `fail`) with a brief issue note if failing. The agent must not state which
   option it chose; only whether the item is well-formed and has exactly one defensible option. Collect all results, then reject and
   regenerate any failing item (budget ~3 tries; substitute a fresh in-domain item if still failing
   after 3 tries).
7. **Shuffle answer positions.** For every item, place correct options at varied A–D positions —
   aim for a reasonable spread. The reference bank's own keys lean heavily on A; that is an artefact
   of how the anchors were written, not a pattern to copy. (The helper's per-letter spread check only runs for 60-item exams; it is not applied here.)
8. **Group into case-study sections.** Order the items so each scenario's items are
   **contiguous**, with domains mixed within each section. Each section opens
   with its `[[CASE:<slug>]]` block — placed **directly before its first item**, not gathered at the
   top — whose `title:` and `brief:` are copied **verbatim** from the blueprint's case-study briefs.
   `init` rejects interleaved sections, a duplicated case block, or any item sitting under a
   different scenario's case block.
9. **Write the attempt** by piping the assembled body to `ccaf-exam.sh init` (one call, via
   stdin — never the Write/Edit tools). `init` validates the payload, then splits it itself:
   stems, options, and `task:` tags go to the questions file; keys and answer slots go to the
   separate answers file. Use exactly this payload schema:

```
---
status: in_progress
total: <10|20|30>
scenarios: <slug1>[,<slug2>]
next_index: 1
---
[[CASE:customer-support]]
title: Customer Support Resolution Agent
brief: <copied verbatim from the blueprint — one logical line>
[[Q1]]
domain: D2
task: D2.2
scenario: customer-support
source: generated
id: gen-01
stem: <item text — keep to one logical line; no blank lines inside the block>
A) <option>
B) <option>
C) <option>
D) <option>
answer_key: B
user_answer:
[[Q2]]
...
```

Rules for the body: one `[[CASE:<slug>]]` block (with `title:` + `brief:`) before each scenario
section; one `[[Q<n>]]` block per item numbered 1..total in order; each item block has `domain:`,
`task:`, `scenario:`, `source: generated` (always — bank questions are never served), a fresh `id:`
(`gen-<n>`), `stem:`, the four options, `answer_key:` (one letter A–D), and an empty
`user_answer:`. `task:` is the task statement tested (`D1.1`–`D5.6`); it must exist and belong to the
item's own `domain:` — D1 has seven task statements, D2 five, D3–D5 six each — and `init` rejects a
tag that is malformed, out of range, or in a different domain. Keep every block free of blank
lines — the helper parses `user_answer:` as the item-block terminator.

After writing, run `ccaf-exam.sh audit`. For non-60-item exams the helper prints the domain and
histogram without enforcing blueprint quotas — manually confirm the per-domain counts match your
computed quotas. If they don't, fix the body and re-pipe; never fall back to Write/Edit. Then tell the
candidate their session's composition in one short block: the selected domains, the scenario(s)
chosen, and the domain distribution.

## Administer

Before the first screen of a new attempt, state once: *"This is an untimed practice session —
there is no time limit."*

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
   every screen, so the case stays visible:
   *"**Case study — <title>** (Q<m>–Q<n> of <total>): <brief>"*
   The brief you print **must** be the `[[CASE]]` block matching the `scenario:` tag of the
   questions on *this* screen — derive it from the questions, never carry the previous screen's
   brief forward. When a screen starts a new section, announce the switch first:
   *"Case study 2 of N — <title>"*. (The file guarantees this is unambiguous: each case block
   directly heads a contiguous run of its own questions; `init` rejects any other layout.)
4. Present the questions in **one AskUserQuestion call** (up to 4 per screen), each as a
   single-select with the four options A–D.

   **Map the option fields this way, every time:** each option's `label` is the bare letter —
   `"A"`, `"B"`, `"C"`, `"D"` — and the option's full text goes in its `description`. AskUserQuestion
   expects a label of a few words and an exam option is a whole sentence, so putting the text in
   `label` renders badly and truncates. Put the item's stem in `question` and use the item number as
   the `header` (`"Q7"`).

   Show the stem and options **only** — never the `answer_key`, never an explanation, never whether
   a prior answer was right.
5. When the candidate submits the screen, **persist and advance in the same response** so the
   next questions appear without waiting on the save:
   - launch the screen's batched record **in the background** (Bash `run_in_background: true`):
     `ccaf-exam.sh record --q 5 --answer A --q 6 --answer C --q 7 --answer B --q 8 --answer D`
   - and, in that same response, print the next screen's case block (step 3) and issue its
     AskUserQuestion (step 4).
   The helper serializes concurrent writes through a lock, so back-to-back screens cannot corrupt
   the file. If a background record reports failure, stop presenting, re-run that exact record in
   the foreground (the answers are still in your context), then continue.
6. Repeat.

**Finish line (before Score).** Record the **final** screen in the *foreground* (no background),
then confirm `get --field next_index` prints `total + 1`. If it prints ≤ total, a save was
lost or questions were declined: run `ccaf-exam.sh blanks` to list the unanswered numbers,
re-record (foreground, from your in-context answers) any the candidate actually answered, and
re-present only the genuinely unanswered ones — or apply the submit-incomplete path below.
Never score while an in-flight record could still land.

**Free-text ("Other") responses.** AskUserQuestion adds an automatic *Other* field. If the text
unambiguously names the option(s) — letters A–D in any form (`B`, `b`, `A and C`, `AC`, `A, C`), or a
near-verbatim match of an option's text — record those letters. Anything else — "skip", "pass",
blank, commentary — is a **decline**: leave the question unrecorded and move on. Never answer
questions about the material, never explain, never confirm or deny a guess; reply only "noted" and
continue the session.

**Changing an answer.** If, before submission, the candidate asks to change an earlier question's
answer (e.g. "change Q3 to B", or "make Q7 A and D"), re-record it with
`ccaf-exam.sh record --q 3 --answer B` / `--q 7 --answer AD` — the helper overwrites in place.

**Declined questions & submitting incomplete.** A declined question stays blank in the file;
continue forward through the remaining screens rather than bouncing back mid-session. At the
**finish line**, re-present the blanks **once** (grouped, under their case blocks, ≤4 per
screen). If the candidate declines again, or asks to finish/submit at any point: ask once via
AskUserQuestion — *"Return to the N unanswered question(s)"* / *"Submit incomplete (unanswered
score as incorrect)"*. On submit, go to **Score** using `score --partial`. Never re-present the
same question a third time; never loop endlessly.

Do not capture or report time at any point.

## Score

1. Run `ccaf-exam.sh score` (or `ccaf-exam.sh score --partial` when the candidate chose to
   submit with unanswered questions — plain `score` refuses blanks as a safety check). It
   prints:
   ```
   correct=<n>/<total>
   scaled=<100..1000>
   verdict=<PASS|FAIL>
   domain=D1 correct=.. total=.. pct=..   (one line per D1..D5)
   task=D2.3 correct=.. total=..          (one line per task statement the session tested)
   ```
   and marks the file `completed`. Use only the per-domain lines — do not display a scaled
   /1000 score or a PASS/FAIL verdict. A practice session is not weighted like a real form, so a
   scaled number from it would be misleading.
2. For each domain where `total > 0`, read its `pct` from the helper's output and assign a flag:
   - **pct ≥ 80** → `Perfect`
   - **60 ≤ pct < 80** → `Needs some prep`
   - **pct < 60** → `Needs work`

   Render a bar chart using `█` (filled) and `░` (empty) scaled to 10 chars, one domain per
   line. Only show domains where `total > 0`. Example:

   ```
   CCAF Practice — Domain Performance

   D2  Tool Design & MCP Integration           ████████░░  8/11   73%   Needs some prep
   D4  Prompt Engineering & Structured Output  ██████████  12/12  100%  Perfect
   ```

3. **Name the objectives, not just the domains.** From the `task=` lines, list every task statement
   the candidate missed at least once, worst first, with its short title from the blueprint
   syllabus. In a 10–30 item session this is usually two to five lines, and it is the whole point of
   drilling a domain — it turns "D2 needs work" into a reading list:

   ```
   Objectives to revisit:
     D2.1  Tool descriptions as the selection interface   0/2
     D2.4  MCP server configuration and scope             1/2
   ```

4. Below the chart, print one recommendation line per domain that is not `Perfect`:
   - `Needs some prep` → *"Run `/ccaf:prepare D<n>` for a focused coaching session on
     <domain name>."*
   - `Needs work` → *"Run `/ccaf:prepare D<n>` to rebuild your understanding of <domain name>
     before retrying."*

   If every domain is `Perfect`: *"Great work across all practised domains — you're ready to
   pressure-test with the full mock. Run `/ccaf:mock-exam` when you are."*

   Do not persist, export, or share the result — it is shown in the terminal only.

## Integrity note

Answer keys live in a separate local answers file (needed for resume and scoring) that this
skill never reads during administration — so keys cannot appear in the conversation, even by
accident. This remains an honor-system gate: a candidate *can* open the answers file, and
doing so only undermines their own preparation. Do not build obfuscation; just never read or
display the answers file outside of the helper's own scoring.
