# CCAF: Claude Certified Architect – Foundations mock exam

A self-serve readiness gate for the CCAF certification. `/ccaf:mock-exam` administers a faithful
mock exam and reports a scaled /1000 score with the 720 pass line, so a candidate can check
readiness before booking the real (paid) exam.

## Layout

- `commands/mock-exam.md` — the `/ccaf:mock-exam` command (loads the engine skill).
- `skills/ccaf-exam/SKILL.md` — the assemble → administer → score engine.
- `data/ccaf-blueprint.md` — domains, weights, scenarios, the syllabus, scope lists, scoring.
- `data/ccaf-question-bank.md` — 12 self-authored seed questions, used as seeds + anchors.
- `scripts/ccaf-exam.sh` — silent state helper (init / get / record / audit / score / clear); never use Write/Edit on the attempt file. Guards: `init` validates the body — and, for 60-question exams, enforces the blueprint composition (domain quotas 16/11/12/12/9, 4 scenarios in contiguous sections each headed by its own `[[CASE:]]` brief — so a screen's brief always matches its questions — non-degenerate key spread) — and refuses to overwrite an in-progress attempt (unless `--force`); `record` takes one or more `--q/--answer` pairs atomically (one call per screen) and requires an in-progress attempt; `score` refuses corrupt files and requires `--partial` to score with unanswered questions. All writes serialize through a `<attempt-file>.lock` directory lock (stale locks are stolen), so mid-exam `record` calls run **in the background** while the next screen shows; the final screen records in the foreground and completion is verified before scoring.
- `scripts/tests/ccaf-exam.test.sh` — shell test harness for the data files + helper logic.

## Conventions

- Per-attempt state lives at `~/.claude/ccaf-exam.local.md` (user-level, gitignored, never shared).
- Untimed, honor-system, fully offline. Self-serve: nothing is reported or persisted as history.
  The real exam's 120-minute budget is stated once up front for self-pacing; no time is ever captured.
- Scoring: `scaled = 100 + 15 × correct` (linear over the real 100–1000 band); pass = 720 (≥ 42/60).
- The scaled score is an honest estimate, never presented as Anthropic's proprietary equating curve.
