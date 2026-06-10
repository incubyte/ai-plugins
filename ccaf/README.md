# CCAF

CCAF is a Claude Code plugin that helps you **prepare for** and **mock-test** against the **Claude Certified Architect – Foundations** exam — right in your terminal — so you get an honest readiness verdict before you book the real (paid) exam.

**Why this exists.** Incubyte is having everyone get CCAF-certified, with a simple rule: *practice first, and only sit the real exam once you can reliably score 720+.* Instead of every engineer hand-rolling a quiz from the exam-guide PDF, this plugin makes that learn-and-gate flow a couple of commands, consistent for the whole team.

**What you get — two commands, one loop:**

- **`/ccaf:prepare`** — a conversational coach that teaches the syllabus *turn by turn*: one concept at a time, a knowledge check every turn, pace and difficulty adapting to you. The formative side — build readiness.
- **`/ccaf:mock-exam`** — a 60-question weighted mock that mirrors the real exam's structure, a scaled `/1000` score with the **720** pass line, and a per-domain breakdown. The summative side — test readiness.

```
   /ccaf:prepare   ──build readiness──►   /ccaf:mock-exam
        ▲                                      │
        └────── study the weak domain ◄────────┘
              (a mock FAIL points you back to /ccaf:prepare <domain>)
```

> Learn with `prepare`, gate with `mock-exam`. Aim for 720+ on the mock, then book the real exam.

## How it mirrors the real exam

| Real exam rule | This mock |
| --- | --- |
| 60 questions | ✅ 60 per attempt |
| 5 domains, weighted 27 / 18 / 20 / 20 / 15 | ✅ same distribution (D1=16, D2=11, D3=12, D4=12, D5=9) |
| 4 of 6 scenarios, chosen at random | ✅ same |
| Single-select, 1 correct + 3 distractors | ✅ same |
| No penalty for guessing | ✅ unanswered = incorrect |
| Scaled 100–1000, pass = 720 | ✅ `scaled = 100 + 15 × correct`; pass at ≥ 42/60 |

The one thing it **can't** replicate is Anthropic's proprietary scaled-scoring curve — so the score is a transparent, linear *estimate*, clearly labelled. Treat 720+ as a readiness signal, not a guarantee.

## The flow

```
/ccaf:mock-exam
       |
       v
  [ ASSEMBLE ]   Pick 4 of 6 scenarios; pull the seed questions +
       |          generate the rest (each independently verified, A–D shuffled);
       |          freeze a 60-question exam to ~/.claude/ccaf-exam.local.md.
       v
  [ ADMINISTER ] 4 questions per screen. Progress saved after every screen —
       |          quit any time and re-run to resume where you left off.
       v
  [ SCORE ]      Scaled /1000, PASS/FAIL at 720, per-domain breakdown, and an
                  honest "this is an estimate" disclaimer.
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

### Test — `/ccaf:mock-exam`

```bash
/ccaf:mock-exam
```

Answer the questions four to a screen. When you finish, you get your scaled score, a PASS/FAIL at 720, and a domain-by-domain breakdown so you know where you're weak. A FAIL points you back to `/ccaf:prepare <weakest-domain>` for targeted practice.

```bash
/ccaf:mock-exam fresh
```

Discard any in-progress or completed attempt and assemble a brand-new exam.

**Resume:** the attempt persists to `~/.claude/ccaf-exam.local.md`. Close your terminal mid-exam and re-run `/ccaf:mock-exam` — it greets you with "Welcome back" and continues from the next unanswered question.

**Honor system:** untimed, self-serve, nothing reported or shared. The answer key lives in the attempt file so resume and scoring work — peeking only cheats you before a paid exam.

## How scoring works

- Raw `correct` = questions answered correctly (unanswered count as incorrect).
- `scaled = 100 + 15 × correct` — a linear mapping over the real 100–1000 band (equivalently `100 + round(correct ÷ 60 × 900)`; since `900 ÷ 60 = 15`, no rounding is needed).
- **Pass** iff `scaled ≥ 720`, i.e. **≥ 42 of 60** correct.
- A per-domain breakdown (correct / total per D1–D5) accompanies every result.

## What's inside

```
ccaf/
├── .claude-plugin/
│   └── plugin.json                # Plugin manifest
├── commands/
│   ├── prepare.md                 # /ccaf:prepare — conversational tutor entry point
│   └── mock-exam.md               # /ccaf:mock-exam — mock exam entry point
├── agents/
│   └── ccaf-check-author.md       # mini-agent: authors one scenario check per request (internal)
├── skills/
│   ├── ccaf-tutor/
│   │   └── SKILL.md               # tutor engine: topic menu → teach → check → adapt (internal)
│   └── ccaf-exam/
│       └── SKILL.md               # exam engine: assemble → administer → score (internal)
├── data/
│   ├── ccaf-blueprint.md          # domains, weights, scenarios, paraphrased syllabus, scoring
│   └── ccaf-question-bank.md      # 12 self-authored seed questions (seeds + anchors)
├── scripts/
│   ├── ccaf-exam.sh               # silent state helper (init / get / record / score / clear)
│   └── tests/
│       └── ccaf-exam.test.sh      # shell test harness for the data files + helper logic
├── CLAUDE.md                      # plugin conventions
├── README.md
└── LICENSE
```

## Notes

- **Question sourcing.** The 12 self-authored seed questions seed the bank and anchor style/difficulty; the rest are generated from the blueprint syllabus and pass an independent verifier (re-solve cold, plausible distractors, shuffled positions) before being served.
- **How `prepare` teaches.** The tutor reads the same blueprint as its curriculum, teaches one task statement per turn, and verifies by retrieval. Its apply-to-scenario checks are authored on demand by a small `ccaf-check-author` subagent (built from the syllabus anti-patterns), keeping the main teaching thread lean. Nothing is written to disk.
- **Roadmap.** Growing a larger verified question bank, broadening the tutor's coverage across all 30 task statements, and verifying the full lifecycle end-to-end are the next steps (tracked in `docs/specs/ccaf-mock-exam.md`).

## License

MIT
