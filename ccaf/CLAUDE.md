# CCAF: Claude Certified Architect – Foundations mock exam

A self-serve readiness gate for the CCAF certification. `/ccaf:mock-exam` administers a faithful
mock exam and reports a scaled /1000 score with the 720 pass line, so a candidate can check
readiness before booking the real (paid) exam.

## Layout

- `commands/mock-exam.md` — the `/ccaf:mock-exam` command (loads the engine skill).
- `skills/ccaf-exam/SKILL.md` — the assemble → administer → score engine.
- `data/ccaf-blueprint.md` — domains, weights, scenarios, the syllabus, scope lists, scoring.
- `data/ccaf-question-bank.md` — 12 self-authored seed questions, used as seeds + anchors.
- `scripts/ccaf-exam.sh` — silent state helper (init / get / record / score / clear); never use Write/Edit on the attempt file.
- `scripts/tests/ccaf-exam.test.sh` — shell test harness for the data files + helper logic.

## Conventions

- Per-attempt state lives at `~/.claude/ccaf-exam.local.md` (user-level, gitignored, never shared).
- Untimed, honor-system, fully offline. Self-serve: nothing is reported or persisted as history.
- Scoring: `scaled = 100 + 15 × correct` (linear over the real 100–1000 band); pass = 720 (≥ 42/60).
- The scaled score is an honest estimate, never presented as Anthropic's proprietary equating curve.
