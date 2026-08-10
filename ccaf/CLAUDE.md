# CCAF: Claude Certified Architect – Foundations mock exam

A self-serve readiness gate for the CCAF certification (exam code `CCAR-F`). `/ccaf:mock-exam`
administers a faithful mock exam and reports a scaled /1000 score with the 720 pass line, so a
candidate can check readiness before booking the real (paid) exam.

Aligned to exam guide **v1.0 (effective July 2026)**. The guide's published *facts* are encoded
here; none of its prose is. Every stem, option, explanation, scenario brief, task-statement
description, and exercise is self-authored for this plugin — keep it that way when editing, and do
not commit the guide PDF (it is gitignored).

## Layout

- `commands/prepare.md` — the `/ccaf:prepare` command (loads the tutor skill).
- `commands/mock-exam.md` — the `/ccaf:mock-exam` command (loads the exam engine skill).
- `commands/practice.md` — the `/ccaf:practice` command (loads the practice engine skill).
- `skills/ccaf-tutor/SKILL.md` — the conversational teaching engine (topic menu → teach → check → adapt); stateless.
- `skills/ccaf-exam/SKILL.md` — the assemble → administer → score engine.
- `skills/ccaf-practice/SKILL.md` — the domain-selection → assemble → administer → score engine for focused domain practice; uses a separate state file so it never conflicts with `/ccaf:mock-exam`.
- `agents/ccaf-check-author.md` — mini-agent the tutor spawns to author one scenario check at a time.
- `data/ccaf-blueprint.md` — domains, weights, item composition, the 30 task statements (D1.1–D5.6), scenarios, case-study briefs, scope lists, scoring. Shared curriculum for all three commands, and the only authority for item content.
- `data/ccaf-question-bank.md` — 24 self-authored reference questions, each tagged with its `task:` and `select:`; style/difficulty/format anchors only, never served in an exam (helper-enforced). Five are multiple-response so that format has anchors too.
- `data/ccaf-prep-guide.md` — study routes, four hands-on exercises, multiple-response answering strategy, and certification logistics (fee, retakes, recertification). Read by the tutor; read by the exam skills only for post-result guidance, never for item content.
- `scripts/ccaf-exam.sh` — silent state helper (init / get / record / blanks / audit / score / clear); never use Write/Edit on the attempt files. `init` takes one payload (with keys) and splits it: questions file (write-once) + answers file (hot, ~60 lines) — so `record` rewrites only the tiny answers file and `get` output is key-free. Guards: `init` validates the payload — every item's `select:` count must equal its `answer_key` length, with distinct letters in A–D order — and, for 60-item exams, enforces the blueprint composition (domain quotas 16/11/12/12/9; exactly 15 multiple-response items with at most 5 choose-three; 4 scenarios in contiguous sections each headed by its own `[[CASE:]]` brief — so a screen's brief always matches its items; non-degenerate key spread across the single-answer items) — and refuses to overwrite an in-progress attempt (unless `--force`); `record` takes one or more `--q/--answer` pairs atomically (one call per screen), normalizes each answer set (uppercased, sorted, de-duplicated) so selection order never matters, and requires an in-progress attempt; `score` cross-validates the pair and requires `--partial` to score with unanswered items. All writes serialize through a directory lock (stale locks are stolen), so mid-exam `record` calls run **in the background** while the next screen shows; the final screen records in the foreground and completion is verified before scoring.
- `scripts/tests/ccaf-exam.test.sh` — shell test harness for the data files + helper logic.

## Conventions

- Per-attempt state is a pair of user-level, gitignored files: `~/.claude/ccaf-exam.local.md`
  (questions — write-once, key-free) and `~/.claude/ccaf-exam.local.answers.md` (keys + recorded
  answers + progress — small, rewritten per screen, never read during administration).
  `/ccaf:practice` uses a separate pair (`ccaf-practice.local.md` / `ccaf-practice.local.answers.md`)
  so the two modes never interfere.
- Untimed, honor-system, fully offline. Self-serve: nothing is reported or persisted as history.
  The real exam's 120-minute budget is stated once up front for self-pacing; no time is ever captured.
- **Two item formats**, as the real exam has. `select: 1` is multiple-choice; `select: 2`/`3` is
  multiple-response, rendered with `multiSelect: true` and stating its count in bold in the stem.
  A full mock is 45 / 11 / 4. Every item has exactly four options A–D — `AskUserQuestion` renders no
  more than four, which the README's fidelity table discloses rather than hides.
- Multiple-response scoring is **all-or-nothing**: the recorded set must equal the key exactly.
- Scoring: `scaled = 100 + 15 × correct` (linear over the real 100–1000 band); pass = 720 (≥ 42/60).
  Results always show per-domain correct/total **and percent**, labelled diagnostic-only — pass/fail
  is the total scaled score, as on the real criterion-referenced exam.
- The scaled score is an honest estimate, never presented as Anthropic's proprietary equating curve.
- Process creation can be slow on some machines (Windows + AV in particular), so hot paths in the
  helper avoid gratuitous subprocesses — `normalize_answer` is pure bash, and each validation check
  is a single `awk` pass rather than a loop of `grep`s. Keep it that way; `record` runs once per
  exam screen.
