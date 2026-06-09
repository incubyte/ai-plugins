---
name: ccaf-exam
description: "Engine for the /ccaf:mock-exam mock exam. Assembles a 60-question CCAF mock (official seed questions + verified generated ones), administers it 4 questions per screen with resumable progress, and scores it on the real 100–1000 band with a 720 pass line. Use when running or resuming /ccaf:mock-exam."
---

# CCAF Mock Exam Engine

You administer a faithful **mock** of the Claude Certified Architect – Foundations (CCAF) exam.
Three phases — **assemble → administer → score** — over one resumable attempt file. Be calm and
exam-like: no hints, no answer keys shown mid-exam, no chit-chat between questions.

All state lives in `~/.claude/ccaf-exam.local.md`, written **only** through the pre-approved
helper so there are no permission prompts:

```
"${CLAUDE_PLUGIN_ROOT}/scripts/ccaf-exam.sh" <init|get|record|score|clear> [...]
```

Read-only authority: `${CLAUDE_PLUGIN_ROOT}/data/ccaf-blueprint.md` (domains, weights, scenarios,
in/out-of-scope, scoring) and `${CLAUDE_PLUGIN_ROOT}/data/ccaf-question-bank.md` (the 12 official
seed questions). Read both before assembling.

## On startup — resume / fresh / recover

1. If `$ARGUMENTS` is `fresh`: run `ccaf-exam.sh clear`, then go to **Assemble**.
2. Otherwise read the current status: `ccaf-exam.sh get --field status`.
   - **Command fails / no file** → no attempt exists → go to **Assemble**.
   - **`in_progress`** → read `ccaf-exam.sh get --field next_index`. Greet:
     *"Welcome back — you're on question N of 60."* Ask via **AskUserQuestion**:
     *Resume* (continue from `next_index`, same stored questions) / *Start fresh* (clear + reassemble).
   - **`completed`** → tell them the previous attempt is finished. Ask via **AskUserQuestion**:
     *Start a fresh attempt* / *Cancel*. A fresh attempt clears and reassembles.
   - **Malformed / unreadable** (you read it and it isn't a valid exam file — missing frontmatter,
     truncated blocks): explain briefly, do **not** score or administer it, and offer
     *Start fresh* / *Cancel* via AskUserQuestion. Never crash; never score a damaged attempt.

## Assemble

Goal: a frozen, well-formed 60-question exam written to the attempt file.

1. **Pick scenarios.** Choose **4 of the 6** scenarios at random (vary the choice across attempts;
   don't always pick the same four). The six slugs are in the blueprint.
2. **Domain quotas (hard constraint).** Exactly: **D1=16, D2=11, D3=12, D4=12, D5=9** (= 60).
3. **Seed anchors.** Include the official seed questions whose `scenario` is among the four chosen
   (verbatim — never reword or re-key them). They count toward their domain quotas.
4. **Generate the remainder** up to 60, honoring the quotas and spread across the chosen scenarios.
   Each generated question:
   - tests a task statement for its tagged domain (see blueprint), stays strictly **in-scope**, and
     never touches an **out-of-scope** topic;
   - has one clearly-correct option and three plausible-but-wrong distractors;
   - matches the official questions' style and difficulty (use them as few-shot anchors).
5. **Verify each generated question independently.** For each, run an *independent* check that did
   **not** see your authoring rationale — prefer spawning a fresh subagent via the Task tool that
   receives only the question + options and must (a) pick the single defensible answer and (b) flag
   any second-correct or implausible distractor. Reject and regenerate any question that fails
   (budget ~3 tries); if it still fails, substitute another in-domain question or an unused seed.
   Official seed questions are authoritative and skip this check.
6. **Shuffle answer positions.** For every question (seed and generated), place the correct option
   at a varied A–D position so the answer key carries no positional pattern across the exam.
7. **Write the file** by piping the assembled body to `ccaf-exam.sh init` (one call, via stdin —
   never the Write/Edit tools). Use exactly this schema:

```
---
status: in_progress
total: 60
scenarios: <slug1>,<slug2>,<slug3>,<slug4>
next_index: 1
---
[[Q1]]
domain: D3
scenario: code-generation
source: official
id: official-04
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

Rules for the body: one `[[Q<n>]]` block per question numbered 1..60 in order; each block has
`domain:`, `scenario:`, `source:` (`official` or `generated`), `id:`, `stem:`, the four options,
`answer_key:` (the correct letter after shuffling), and an empty `user_answer:`. Keep each block
free of blank lines — the helper parses `user_answer:` as the block terminator.

After writing, confirm with `ccaf-exam.sh get --field total` → should print `60`.

## Administer

Loop until the exam is fully answered:

1. Read `ccaf-exam.sh get --field next_index`. If it is greater than `total` (60), go to **Score**.
2. Read the file (`ccaf-exam.sh get`) and take the next **up to 4** unanswered questions starting
   at `next_index`.
3. Present them in **one AskUserQuestion call** (up to 4 questions per screen), each as a
   single-select with the four options A–D. Show the stem and options **only** — never the
   `answer_key`, never an explanation, never whether a prior answer was right.
4. When the candidate submits the screen, record each answer:
   `ccaf-exam.sh record --q <n> --answer <A|B|C|D>` (one call per question). This advances
   `next_index` past the answered run, so quitting now and re-running resumes cleanly.
5. Repeat. (A candidate may decline to answer a question; leave it unrecorded — it will score as
   incorrect, and resume will return to it.)

Do not capture or report time at any point.

## Score

1. Run `ccaf-exam.sh score`. It prints:
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
     D1 Agentic Architecture & Orchestration   13/16
     D2 Tool Design & MCP Integration           8/11
     D3 Claude Code Config & Workflows         10/12
     D4 Prompt Engineering & Structured Output  9/12
     D5 Context Management & Reliability         6/9   ← weakest
   ```
3. Add the disclaimer verbatim in spirit: *"This scaled score is an estimate
   (scaled = 100 + 15 × correct, a linear mapping over the real 100–1000 band). It is NOT
   Anthropic's proprietary equating curve. Treat 720+ here as a readiness signal, not a guarantee."*
4. If PASS: note they're in good shape to book the real exam. If FAIL: point at the weakest
   domain(s) from the breakdown as where to study. Do not persist, export, or share the result —
   it's shown in the terminal only.

## Integrity note

The answer key lives in the attempt file (needed for resume and scoring). This is an honor-system
gate — opening the file to peek only cheats the candidate before a paid attempt. Do not build
obfuscation; just never *display* keys during administration.
