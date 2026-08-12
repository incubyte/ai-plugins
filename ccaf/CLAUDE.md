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
- `data/ccaf-question-bank.md` — 30 self-authored reference questions, one per task statement, each tagged with its `task:`; style/difficulty anchors only, never served in an exam (helper-enforced). All single-answer. Their key letters lean toward A — content is the reference, letters are noise.
- `data/ccaf-prep-guide.md` — study routes, four hands-on exercises, and certification logistics (fee, retakes, recertification). Read by the tutor; read by the exam skills only for post-result guidance, never for item content.
- `scripts/ccaf-exam.sh` — silent state helper (init / get / record / blanks / audit / score / clear); never use Write/Edit on the attempt files. `init` takes one payload (with keys) and splits it: questions file (write-once) + answers file (hot, ~60 lines) — so `record` rewrites only the tiny answers file and `get` output is key-free. Guards: `init` validates the payload — one `answer_key` letter A–D per item, and a `task:` tag that exists and belongs to the item's own domain — and, for 60-item exams, enforces the blueprint composition (domain quotas 16/11/12/12/9; 4 scenarios in contiguous sections each headed by its own `[[CASE:]]` brief — so a screen's brief always matches its items; a key spread within a sixth to a third per letter) — and refuses to overwrite an in-progress attempt (unless `--force`); `record` takes one or more `--q/--answer` pairs atomically (one call per screen), uppercases each answer so a lowercase free-text reply matches, and requires an in-progress attempt; `score` cross-validates the pair and requires `--partial` to score with unanswered items. All writes serialize through a directory lock (stale locks are stolen), so mid-exam `record` calls run **in the background** while the next screen shows; the final screen records in the foreground and completion is verified before scoring.
- `scripts/tests/ccaf-exam.test.sh` — shell test harness for the data files + helper logic.

## Conventions

- Per-attempt state is a pair of user-level, gitignored files: `~/.claude/ccaf-exam.local.md`
  (questions — write-once, key-free) and `~/.claude/ccaf-exam.local.answers.md` (keys + recorded
  answers + progress — small, rewritten per screen, never read during administration).
  `/ccaf:practice` uses a separate pair (`ccaf-practice.local.md` / `ccaf-practice.local.answers.md`)
  so the two modes never interfere.
- Untimed, honor-system, fully offline. Self-serve: nothing is reported or persisted as history.
  The real exam's 120-minute budget is stated once up front for self-pacing; no time is ever captured.
- **Single-answer items only** — four options A–D, exactly one correct. This is a deliberate
  divergence: the real exam also uses multiple-response items. The blueprint records the reasoning
  and the consequence (a score here is, if anything, optimistic), and the README's fidelity table
  states it. Never reintroduce a response count without changing all three.
- Scoring: `scaled = 100 + 15 × correct` (linear over the real 100–1000 band); pass = 720 (≥ 42/60).
  Results always show per-domain correct/total **and percent**, labelled diagnostic-only — pass/fail
  is the total scaled score, as on the real criterion-referenced exam.
- Every item carries a `task:` tag (`D1.1`–`D5.6`) that `init` validates against its `domain:`, and
  `score` aggregates misses by task statement so a result names the objectives to revisit. This goes
  beyond what the real score report shows; the validation exists because a mistagged item would send
  a candidate to study the wrong thing. Task-statement counts per domain: D1 7, D2 5, D3–D5 6 each.
- The scaled score is an honest estimate, never presented as Anthropic's proprietary equating curve.
- Process creation can be slow on some machines (Windows + AV in particular), so hot paths in the
  helper avoid gratuitous subprocesses — `normalize_answer` is pure bash, and each validation check
  (`check_items`, `check_composition_questions`, `check_key_spread`) is a single `awk` pass rather
  than a loop of `grep`s. **Keep it that way.** This is not micro-optimising:
  an earlier grep-per-check version made the test suite slow enough to exhaust Cygwin's fork table
  mid-run (`fork: Resource temporarily unavailable`), so the suite could not finish at all on
  Windows. `record` runs once per exam screen and `validate_pair` runs on every score.
- Even now the suite can occasionally report spurious failures on Windows when a fork fails inside a
  fixture's `init` (the symptom is a whole section failing with "not found" / empty field reads).
  Re-run before investigating; if it reproduces, it is real. A clean run is `100 passed, 0 failed`.
