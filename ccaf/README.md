# CCAF

CCAF is a Claude Code plugin that administers a faithful **mock** of the **Claude Certified Architect – Foundations** exam — right in your terminal — and gives you an honest readiness verdict before you book the real (paid) exam.

**Why this exists.** Incubyte is having everyone get CCAF-certified, with a simple rule: *practice first, and only sit the real exam once you can reliably score 720+.* Instead of every engineer hand-rolling a quiz from the exam-guide PDF, this plugin makes that practice-and-gate a single command, consistent for the whole team.

**What you get.** One command, `/ccaf:mock-exam`: a 60-question weighted mock that mirrors the real exam's structure, a scaled `/1000` score with the **720** pass line, and a per-domain breakdown that tells you exactly what to study. Resumable, untimed, fully offline.

> Aim for 720+ here, then book the real exam.

## How it mirrors the real exam

| Real exam rule | This mock |
| --- | --- |
| 60 questions | ✅ 60 per attempt |
| 5 domains, weighted 27 / 18 / 20 / 20 / 15 | ✅ same distribution (D1=16, D2=11, D3=12, D4=12, D5=9) |
| 4 of 6 scenarios, chosen at random | ✅ same |
| Questions organized around case studies | ✅ 4 case-study sections; the case brief stays visible on every screen |
| Single-select, 1 correct + 3 distractors | ✅ same |
| No penalty for guessing | ✅ unanswered = incorrect |
| Answers revisable before submit | ✅ ask to change any earlier answer mid-exam |
| Scaled 100–1000, pass = 720 | ✅ `scaled = 100 + 15 × correct`; pass at ≥ 42/60 |
| 120-minute time limit | ❌ untimed by design — it shows the 120-min / ~2-min-per-question budget up front so you can self-pace |

Two things it does **not** replicate, on purpose: Anthropic's proprietary scaled-scoring curve (impossible — the score here is a transparent, linear *estimate*, clearly labelled) and the 120-minute clock (deliberate — the mock is resumable and honor-system; time yourself if you want realistic conditions). Treat 720+ as a readiness signal, not a guarantee.

## The flow

```
/ccaf:mock-exam
       |
       v
  [ ASSEMBLE ]   Pick 4 of 6 case studies; generate all 60 questions fresh
       |          (anchored to the reference bank, each independently verified,
       |          A–D shuffled); group into 4 case-study sections; freeze the
       |          exam to ~/.claude/ccaf-exam.local.md. The 16/11/12/12/9
       |          domain split is machine-enforced at write time (a
       |          mis-weighted exam is refused), and the composition is shown
       |          to you up front.
       v
  [ ADMINISTER ] 4 questions per screen, case brief always visible. Each screen
       |          saves atomically in the background while the next one shows —
       |          no save-wait between screens. Quit any time; re-run to resume.
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

```bash
/ccaf:mock-exam
```

Answer the questions four to a screen. When you finish, you get your scaled score, a PASS/FAIL at 720, and a domain-by-domain breakdown so you know where you're weak.

```bash
/ccaf:mock-exam fresh
```

Discard any in-progress or completed attempt and assemble a brand-new exam.

**Resume:** the attempt persists to `~/.claude/ccaf-exam.local.md`. Close your terminal mid-exam and re-run `/ccaf:mock-exam` — it greets you with "Welcome back" and continues from the next unanswered question.

**Honor system:** untimed, self-serve, nothing reported or shared. The answer key lives in a separate local answers file (`~/.claude/ccaf-exam.local.answers.md`) that is never shown — and never even read — during the exam; it exists so resume and scoring work. Peeking at it only cheats you before a paid exam.

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
│   └── mock-exam.md               # /ccaf:mock-exam — the entry point
├── skills/
│   └── ccaf-exam/
│       └── SKILL.md               # engine: assemble → administer → score (internal)
├── data/
│   ├── ccaf-blueprint.md          # domains, weights, scenarios, paraphrased syllabus, scoring
│   └── ccaf-question-bank.md      # 12 self-authored reference questions (anchors only — never served)
├── scripts/
│   ├── ccaf-exam.sh               # silent state helper (init / get / record / score / clear)
│   └── tests/
│       └── ccaf-exam.test.sh      # shell test harness for the data files + helper logic
├── CLAUDE.md                      # plugin conventions
├── README.md
└── LICENSE
```

## Notes

- **Question sourcing.** Every question in every attempt is **generated fresh** from the blueprint syllabus and passes an independent verifier (re-solve cold, plausible distractors, shuffled positions) before being served. The 12 self-authored questions in the bank are style/difficulty anchors only — they never appear in an exam (machine-enforced), because the bank ships in this repo with answers, and re-serving readable questions would inflate your readiness signal.
- **Roadmap.** v1 generates everything per attempt anchored to a small reference bank; growing a larger verified anchor bank, adding a short per-domain "practice" mode, and verifying the full lifecycle end-to-end are the next steps (tracked in `docs/specs/ccaf-mock-exam.md`).

## License

MIT
