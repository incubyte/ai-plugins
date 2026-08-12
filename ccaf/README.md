# CCAF

CCAF is a Claude Code plugin that helps you **prepare for** and **mock-test** against the **Claude Certified Architect – Foundations** exam — right in your terminal — so you get an honest readiness verdict before you book the real (paid) exam.

**Why this exists.** Incubyte is having everyone get CCAF-certified, with a simple rule: *practice first, and only sit the real exam once you can reliably score 720+.* Instead of every engineer hand-rolling a quiz from the exam-guide PDF, this plugin makes that learn-and-gate flow a couple of commands, consistent for the whole team.

Aligned to the published exam guide **v1.0 (effective July 2026, exam code `CCAR-F`)**: the same 60 items, the same five weighted domains, and the same 30-objective index. One format divergence — this plugin serves single-answer items only, where the real exam also uses multiple-response items ([why](#how-it-mirrors-the-real-exam)). **Every question, scenario brief, task-statement description, and exercise in this plugin is self-authored** — the guide's published *facts* (weights, item counts, the objective index, backend tool names, policies) are reflected, but none of its prose and no exam item is reproduced.

## The real exam at a glance

| | |
| --- | --- |
| Exam code | `CCAR-F` |
| Items | 60 — multiple-choice **and** multiple-response (each item states how many responses to select). *This plugin serves single-answer only — see below.* |
| Structure | 4 scenarios drawn from a bank of 6 |
| Time limit | 120 minutes |
| Delivery | Proctored by Pearson VUE — online or at a test centre |
| Passing score | Scaled **720** on a 100–1000 range |
| Reporting | Pass/fail + scaled score + percent correct per domain |
| Fee | $125 USD per attempt |
| Validity | 12 months, renewable with a free non-proctored assessment |
| Retakes | 14 / 30 / 90-day waits after successive failures; max 4 attempts per rolling year |

That retake ladder is the argument for this plugin: a failed attempt costs $125 *and* two weeks. Full logistics — booking, ID, accommodations, appeals, recertification — are in `data/ccaf-prep-guide.md`.

**What you get — three commands, one loop:**

- **`/ccaf:prepare`** — a conversational coach that teaches the syllabus *turn by turn*: one concept at a time, a knowledge check every turn, pace and difficulty adapting to you. The formative side — build readiness.
- **`/ccaf:practice`** — focused domain practice: pick the domains you want to drill, choose 10, 20, or 30 questions, and get a per-domain bar-chart score. The targeted side — close specific gaps.
- **`/ccaf:mock-exam`** — a 60-item weighted mock that mirrors the real exam's structure, a scaled `/1000` score with the **720** pass line, and a per-domain and per-objective breakdown. The summative side — test readiness.

```
   /ccaf:prepare   ──build readiness──►   /ccaf:practice   ──close gaps──►   /ccaf:mock-exam
        ▲                                                                           │
        └──────────────────── study the weak domain ◄──────────────────────────────┘
                                (a mock FAIL points you back to /ccaf:prepare <domain>)
```

> Learn with `prepare`, drill gaps with `practice`, gate with `mock-exam`. Aim for 720+ on the mock, then book the real exam.

## How it mirrors the real exam

| Real exam rule | This mock |
| --- | --- |
| 60 items | ✅ 60 per attempt |
| 5 domains, weighted 27 / 18 / 20 / 20 / 15 | ✅ same distribution (D1=16, D2=11, D3=12, D4=12, D5=9), machine-enforced |
| 30 task statements (D1.1–D5.6) | ✅ every item is written against one, and spread across them |
| 4 of 6 scenarios, chosen at random | ✅ same |
| Items organized around case studies | ✅ 4 case-study sections; the case brief stays visible on every screen |
| Multiple-choice **and** multiple-response | ❌ **single-answer only** — every item has four options and one correct answer. Deliberate; see the note below |
| No penalty for guessing | ✅ unanswered = incorrect |
| Answers revisable before submit | ✅ ask to change any earlier answer mid-exam |
| Scaled 100–1000, pass = 720 | ✅ `scaled = 100 + 15 × correct`; pass at ≥ 42/60 |
| Percent correct per domain on the report | ✅ shown, and labelled diagnostic-only — pass/fail is the total scaled score |
| — | ➕ **beyond the real report:** per-task-statement misses, so the result names the exact objectives to revisit, not just the weak domain |
| — | ➕ **beyond the real report:** answer-position spread is machine-enforced, so no letter is over-represented |
| 120-minute time limit | ❌ untimed by design — it shows the 120-min / ~2-min-per-item budget up front so you can self-pace |

Three things it does **not** replicate, and why.

**Multiple-response items.** The guide gives the item format as multiple-choice *and* multiple-response, with each item stating how many responses to select. This mock serves **single-answer items only** — a deliberate choice for this plugin, not an oversight. Two consequences worth holding onto: you will not rehearse a format that is scored all-or-nothing (one right and one wrong scores the same as zero right), and because single-answer items are the easier format, **a score here is if anything optimistic**. Treat 720 as the floor of readiness rather than a comfortable margin. `data/ccaf-prep-guide.md` explains how to train the underlying habit — decide the status of every option instead of stopping at the first strong one — without the format itself.

**The scaled-scoring curve.** Anthropic's is proprietary and unpublished, so the score here is a transparent linear *estimate*, clearly labelled as such.

**The 120-minute clock.** Deliberately absent — the mock is resumable and honor-system. Time yourself if you want realistic conditions.

Treat 720+ as a readiness signal, not a guarantee.

## The flow

```
/ccaf:mock-exam
       |
       v
  [ ASSEMBLE ]   Pick 4 of 6 case studies; generate all 60 items fresh
       |          (anchored to the reference bank, each independently verified,
       |          A–D shuffled); group into 4 case-study sections; freeze the
       |          exam to ~/.claude/ccaf-exam.local.md. The 16/11/12/12/9 domain
       |          split, the answer-position spread, and each item's task-statement
       |          tag are machine-enforced at write time (a mis-weighted exam, a
       |          skewed key spread, or a tag that does not belong to its own domain
       |          is refused), and the composition is shown to you up front.
       v
  [ ADMINISTER ] 4 items per screen, case brief always visible. Each screen saves
       |          atomically in the background while the next one shows — no
       |          save-wait between screens. Quit any time; re-run to resume.
       v
  [ SCORE ]      Scaled /1000, PASS/FAIL at 720, per-domain percent breakdown,
                  the objectives you missed, and an honest "this is an
                  estimate" disclaimer.
```

## Install

In Claude Code:

```bash
# Add the Incubyte marketplace
/plugin marketplace add incubyte/ai-plugins

# Install CCAF
/plugin install ccaf@incubyte-plugins
```

> Restart (or `/reload-plugins`) after installing.

## Usage

### Learn — `/ccaf:prepare`

```bash
/ccaf:prepare
```

A patient coach teaches the syllabus one concept at a time and checks your understanding every turn — by asking you to *apply* an idea, not by asking "make sense?". It opens with a **topic menu**: the syllabus as multi-select topic clusters, each with a short description — pick what you want to learn and the journey starts there. Within each topic it adapts: it advances when you're solid, re-teaches a different way when you're not, and reads your confidence with the occasional "why that one?". Jump anywhere at will:

```bash
/ccaf:prepare D4              # start on a specific domain
/ccaf:prepare plan mode       # or a specific topic
```

Untimed and conversational. It's **stateless** — Claude Code's native session resume carries continuity, so close the terminal and pick up where you left off. When a domain looks solid, it points you at the mock.

### Practice — `/ccaf:practice`

```bash
/ccaf:practice
```

Select one or more domains to focus on, then choose how many questions you want (10, 20, or 30). Items are drawn proportionally from the selected domains using the real blueprint weights. At the end you get a per-domain bar chart with percentages, plus the objectives you missed, — no overall score or PASS/FAIL verdict, since a partial session isn't weighted like a real form — and a targeted recommendation for any domain that needs work.

```bash
/ccaf:practice fresh
```

Discard any in-progress or completed practice attempt and start a new domain selection.

**Resume:** the attempt persists to `~/.claude/ccaf-practice.local.md`. Re-run `/ccaf:practice` to continue from where you left off. Practice state is completely separate from the mock exam — the two modes never interfere.

**Honor system:** same as the mock exam — untimed, self-serve, nothing reported or shared.

### Test — `/ccaf:mock-exam`

```bash
/ccaf:mock-exam
```

Answer the items four to a screen — each has four options and exactly one correct answer. When you finish, you get your scaled score, a PASS/FAIL at 720, a domain-by-domain percent breakdown, and the specific task statements you missed. A FAIL points you back to `/ccaf:prepare <weakest-domain>` for targeted practice.

```bash
/ccaf:mock-exam fresh
```

Discard any in-progress or completed attempt and assemble a brand-new exam.

**Resume:** the attempt persists to `~/.claude/ccaf-exam.local.md`. Close your terminal mid-exam and re-run `/ccaf:mock-exam` — it greets you with "Welcome back" and continues from the next unanswered question.

**Honor system:** untimed, self-serve, nothing reported or shared. The answer key lives in a separate local answers file (`~/.claude/ccaf-exam.local.answers.md`) that is never shown — and never even read — during the exam; it exists so resume and scoring work. Peeking at it only cheats you before a paid exam.

## How scoring works

- Raw `correct` = items answered correctly (unanswered count as incorrect).
- `scaled = 100 + 15 × correct` — a linear mapping over the real 100–1000 band (equivalently `100 + round(correct ÷ 60 × 900)`; since `900 ÷ 60 = 15`, no rounding is needed).
- **Pass** iff `scaled ≥ 720`, i.e. **≥ 42 of 60** correct.
- A per-domain breakdown (correct / total **and percent** per D1–D5) accompanies every result, mirroring the real score report. Like the real exam, those percentages are diagnostic only — pass/fail is decided by the total scaled score.
- Every item is tagged with the task statement it tests, so the result also names **which objectives** you missed (`D5.2 Escalation and ambiguity resolution — 0/2`) rather than only which domain. The real score report doesn't do this; it's the most actionable thing a mock can give you, since it converts a weak domain into a short reading list. Tags are validated at write time — a tag must exist and belong to its own domain — so the report can't send you to study the wrong objective.
- The real exam is **criterion-referenced**: you're measured against a fixed standard set by a formal standard-setting study, not graded against other candidates. 720 is a fixed bar.

## What's inside

```
ccaf/
├── .claude-plugin/
│   └── plugin.json                # Plugin manifest
├── commands/
│   ├── prepare.md                 # /ccaf:prepare — conversational tutor entry point
│   ├── mock-exam.md               # /ccaf:mock-exam — mock exam entry point
│   └── practice.md                # /ccaf:practice — focused domain practice entry point
├── agents/
│   └── ccaf-check-author.md       # mini-agent: authors one scenario check per request (internal)
├── skills/
│   ├── ccaf-tutor/
│   │   └── SKILL.md               # tutor engine: topic menu → teach → check → adapt (internal)
│   ├── ccaf-exam/
│   │   └── SKILL.md               # exam engine: assemble → administer → score (internal)
│   └── ccaf-practice/
│       └── SKILL.md               # practice engine: domain-select → assemble → administer → score (internal)
├── data/
│   ├── ccaf-blueprint.md          # exam mechanics + item composition + self-authored 30-task-statement syllabus, scenarios, scoring
│   ├── ccaf-question-bank.md      # 30 self-authored single-answer reference questions, one per task statement (anchors only — never served)
│   └── ccaf-prep-guide.md         # study routes, 4 hands-on exercises, certification logistics
├── scripts/
│   ├── ccaf-exam.sh               # silent state helper (init / get / record / score / clear)
│   └── tests/
│       └── ccaf-exam.test.sh      # shell test harness for the data files + helper logic
├── CLAUDE.md                      # plugin conventions
├── README.md
└── LICENSE
```

## Notes

- **Question sourcing.** Every item in every attempt is **generated fresh** from the blueprint syllabus and passes an independent verifier (re-solve cold, exactly one defensible option, plausible distractors, shuffled positions) before being served. The 30 self-authored questions in the bank are style/difficulty anchors only — they never appear in an exam (machine-enforced), because the bank ships in this repo with answers, and re-serving readable questions would inflate your readiness signal.
- **How `prepare` teaches.** The tutor reads the blueprint as its curriculum, teaches one of the 30 task statements per turn, and verifies by retrieval. Its apply-to-scenario checks are authored on demand by a small `ccaf-check-author` subagent (built from the syllabus anti-patterns), keeping the main teaching thread lean. At domain boundaries it can assign one of the prep guide's four hands-on exercises instead of another quiz. Nothing is written to disk.
- **Roadmap.** Everything is generated per attempt against a 30-question anchor bank, one per task statement. Next: end-to-end lifecycle verification — nobody has sat a full 60-item mock yet. If the single-answer decision is ever revisited, the multiple-response machinery is in this repo's history. Tracked in `docs/specs/ccaf-mock-exam.md`.
- **Provenance.** The plugin encodes the exam guide's published *facts* (item count, weights, the objective index, the scenarios' backend tool names and targets, and program policies) and nothing else from it: every stem, option, explanation, scenario brief, task-statement description, and exercise is written for this plugin. The guide PDF itself is deliberately not committed.

## License

MIT
