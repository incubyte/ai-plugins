---
name: ccaf-practice
description: "Engine for the /ccaf:practice command. Asks which specific CCAF domains to focus on and how many questions (10/20/30), assembles a proportionally-weighted partial exam anchored to the reference bank and independently verified, administers it 4 questions per screen with resumable progress, and scores it with a per-domain performance chart. Attempt state lives in ~/.claude/ccaf-practice.local.md — separate from /ccaf:mock-exam. Use when running or resuming /ccaf:practice."
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

Read-only authority: `${CLAUDE_PLUGIN_ROOT}/data/ccaf-blueprint.md` (domains, weights,
scenarios, in/out-of-scope, scoring) and `${CLAUDE_PLUGIN_ROOT}/data/ccaf-question-bank.md`
(12 self-authored **reference** questions — style/difficulty anchors only, never served).
Read both before assembling.

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
3. **Reference anchors — never served.** Read the 12 bank questions as few-shot anchors for
   style, difficulty, and distractor construction only. Do **not** copy any bank question — or
   a near-verbatim variant of one — into the session: the bank ships in the repo with answers
   and explanations, so candidates may have already read it. Every served question is freshly
   generated (`init` rejects any `source: authored` / `id: seed-*` block).
4. **Generate all `total` questions silently.** Honor the quotas, draw only from the selected
   domains, and spread across the chosen scenarios. Do **not** print stems, options, or running
   commentary to the user — keep all question data in context and proceed directly to
   verification. Each question:
   - is set inside its scenario's **case-study brief** (answerable from brief + stem; may add
     detail, must never contradict the brief);
   - tests a task statement for its tagged domain (see blueprint), stays strictly **in-scope**,
     and never touches an **out-of-scope** topic;
   - has one clearly-correct option and three plausible-but-wrong distractors;
   - matches the bank questions' style and difficulty without reusing their stems or options.
5. **Verify questions in one parallel batch.** Split the questions into groups of ~5. Then, in
   a **single response**, call the Task tool once for every group simultaneously — all with
   `run_in_background: true`. Do **not** call Task, wait for the result, and call Task again;
   all launches must be in the same tool-call batch with no barrier between them. Each agent
   receives only the stems + options for its group — no answer keys — and must return a
   per-question verdict (`pass` or `fail`) with a brief issue note if failing. The agent must
   not state which letter it chose; only whether the question is well-formed. Collect all
   results, then reject and regenerate any failing question (budget ~3 tries; substitute a
   fresh in-domain question if still failing after 3 tries).
6. **Shuffle answer positions.** For every question, place the correct option at a varied A–D
   position — aim for reasonable spread. (The strict 13–17 per-letter check is only enforced
   by the helper for 60-question exams; it is not applied here.)
7. **Group into case-study sections.** Order the questions so each scenario's questions are
   **contiguous**, domains mixed within each section. Each section opens with its
   `[[CASE:<slug>]]` block — placed **directly before its first question**, not gathered at
   the top — whose `title:` and `brief:` are copied **verbatim** from the blueprint's
   case-study briefs. `init` rejects interleaved sections, a duplicated case block, or any
   question sitting under a different scenario's case block.
8. **Write the attempt** by piping the assembled body to `ccaf-exam.sh init` (one call, via
   stdin — never the Write/Edit tools). `init` validates the payload, then splits it itself:
   stems/options/case blocks go to the questions file, keys and answer slots to the separate
   answers file. Use exactly this payload schema:

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
scenario: customer-support
source: generated
id: gen-01
stem: <question text — keep to one logical line; no blank lines inside the block>
A) <option>
B) <option>
C) <option>
D) <option>
answer_key: B
user_answer:
[[Q2]]
...
```

Rules for the body: one `[[CASE:<slug>]]` block (with `title:` + `brief:`) before each
scenario section; one `[[Q<n>]]` block per question numbered 1..total in order; each question
block has `domain:`, `scenario:`, `source: generated` (always — bank questions are never
served), a fresh `id:` (`gen-<n>`), `stem:`, the four options, `answer_key:` (the correct
letter after shuffling), and an empty `user_answer:`. Keep every block free of blank lines —
the helper parses `user_answer:` as the question-block terminator.

After writing, run `ccaf-exam.sh audit` (for non-60-question exams the helper prints domain
counts without enforcing blueprint quotas — manually confirm per-domain counts match your
computed quotas; if they don't, fix the body and re-pipe; never fall back to Write/Edit).
Then tell the candidate their session's composition in one short block: the selected domains,
the scenario(s) chosen, and the domain distribution.

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
then confirm `get --field next_index` prints `total + 1`. If it prints ≤ total, a save was
lost or questions were declined: run `ccaf-exam.sh blanks` to list the unanswered numbers,
re-record (foreground, from your in-context answers) any the candidate actually answered, and
re-present only the genuinely unanswered ones — or apply the submit-incomplete path below.
Never score while an in-flight record could still land.

**Free-text ("Other") responses.** AskUserQuestion adds an automatic *Other* field. If the text
unambiguously names one option (a letter A–D, or a near-verbatim match of one option's text),
record that letter. Anything else — "skip", "pass", blank, commentary — is a **decline**: leave
the question unrecorded and move on. Never answer questions about the material, never explain,
never confirm or deny a guess; reply only "noted" and continue the session.

**Changing an answer.** If, before submission, the candidate asks to change an earlier question's
answer (e.g. "change Q3 to B"), re-record it with `ccaf-exam.sh record --q 3 --answer B` — the
helper overwrites in place.

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
   domain=D1 correct=.. total=..   (one line per D1..D5)
   ```
   and marks the file `completed`. Use only the per-domain lines — do not display a scaled
   /1000 score or a PASS/FAIL verdict.
2. For each domain where `total > 0`, compute `pct = correct / total` and assign a flag:
   - **pct ≥ 0.80** → `Perfect`
   - **0.60 ≤ pct < 0.80** → `Needs some prep`
   - **pct < 0.60** → `Needs work`

   Render a bar chart using `█` (filled) and `░` (empty) scaled to 10 chars, one domain per
   line. Only show domains where `total > 0`. Example:

   ```
   CCAF Practice — Domain Performance

   D2  Tool Design & MCP Integration           ████████░░  8/11   Needs some prep
   D4  Prompt Engineering & Structured Output  ██████████  12/12  Perfect
   ```

3. Below the chart, print one recommendation line per domain that is not `Perfect`:
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
