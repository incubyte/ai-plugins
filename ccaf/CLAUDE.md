# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# CCAF: Claude Certified Architect – Foundations mock exam

A self-serve readiness gate for the CCAF certification. `/ccaf:mock-exam` administers a faithful
mock exam and reports a scaled /1000 score with the 720 pass line, so a candidate can check
readiness before booking the real (paid) exam.

## Running tests

```bash
bash scripts/tests/ccaf-exam.test.sh   # shell state helper (init/get/record/score/clear)
python3 scripts/tests/server.test.py   # web server (parser, HTTP routes, submit)
```

`ccaf-exam.test.sh` exercises `scripts/ccaf-exam.sh` end-to-end: data-file structure,
init/get/record/score/clear, resume cursor, scoring math, composition enforcement, and
concurrency guards. Isolated via `CCAF_EXAM_FILE` env var — it never touches `~/.claude/`.

`server.test.py` exercises `web/server.py`: `parse_questions_file`, `parse_answers_file`,
and all HTTP routes (ping, exams list, exam/result fetch, submit). Each test class
spins up its own ephemeral-port server instance and cleans up after itself.

## Layout

- `commands/prepare.md` — the `/ccaf:prepare` command (loads the tutor skill).
- `commands/mock-exam.md` — the `/ccaf:mock-exam` command (loads the exam engine skill).
- `skills/ccaf-tutor/SKILL.md` — the conversational teaching engine (topic menu → teach → check → adapt); stateless.
- `skills/ccaf-exam/SKILL.md` — the assemble → administer → score engine; contains a **Web Mode** section (triggered by `--web`) that hands off to the browser after assembly.
- `agents/ccaf-check-author.md` — mini-agent the tutor spawns to author one scenario check at a time.
- `data/ccaf-blueprint.md` — domains, weights, scenarios, the syllabus, scope lists, scoring. Shared curriculum for both commands.
- `data/ccaf-question-bank.md` — 12 self-authored reference questions; style/difficulty anchors only, never served in an exam (helper-enforced).
- `scripts/ccaf-exam.sh` — silent state helper (init / get / record / blanks / audit / score / clear); never use Write/Edit on the attempt files.
- `scripts/start-web-server.sh` — web mode launcher: generates a timestamped exam ID, exports the current exam pair to `~/.claude/ccaf-exams/<ID>.json` via `web/server.py`, starts the Python server on port **8765**, opens the browser.
- `scripts/tests/ccaf-exam.test.sh` — shell test harness for the data files + helper logic.
- `web/server.py` — Python stdlib HTTP server (no external deps). Two modes: `export` (parse exam files → write JSON with Base64-obfuscated keys) and `serve` (API for the browser app: GET `/`, `/ping`, `/exams`, `/exam/<id>`, `/result/<id>`; POST `/submit`). Shuts itself down after receiving `POST /submit`.
- `web/app.html` — self-contained single-file browser exam app (HTML + vanilla JS + inline CSS). Start screen (exam library), exam screen (free navigation, flagging, 120-min enforced timer), result screen (per-domain CSS bar chart).

## Conventions

- Per-attempt state is a pair of user-level, gitignored files: `~/.claude/ccaf-exam.local.md`
  (questions — write-once, key-free) and `~/.claude/ccaf-exam.local.answers.md` (keys + recorded
  answers + progress — small, rewritten per screen, never read during administration).
- **Never use Write/Edit on the attempt files.** All reads/writes go through `ccaf-exam.sh`
  subcommands so that answer keys stay out of the conversation context and atomic rewrites are guaranteed.
- **Web mode** (`/ccaf:mock-exam --web`): after assembly, `start-web-server.sh` exports the exam to `~/.claude/ccaf-exams/` as JSON (with Base64-obfuscated keys), starts a Python stdlib server on port **8765**, and opens the browser. The server shuts itself down after receiving the submit POST. Saved exams accumulate in `~/.claude/ccaf-exams/`; results alongside as `<id>-result.json`.
- The exam file path is overridable: `CCAF_EXAM_FILE=/path/to/file bash scripts/ccaf-exam.sh …`
  (the answers file path derives automatically from it). The test suite uses this.
- Untimed, honor-system, fully offline. Self-serve: nothing is reported or persisted as history.
  The real exam's 120-minute budget is stated once up front for self-pacing; no time is ever captured.
- Scoring: `scaled = 100 + 15 × correct` (linear over the real 100–1000 band); pass = 720 (≥ 42/60).
- The scaled score is an honest estimate, never presented as Anthropic's proprietary equating curve.

## State helper subcommands

```
ccaf-exam.sh init [--force]           # read full payload from stdin (with keys), validate, split-write both files
ccaf-exam.sh get [--field <name>]     # print key-free questions file, or one frontmatter field
ccaf-exam.sh record --q N --answer X  # record one or more answers atomically (one call per screen)
ccaf-exam.sh blanks                   # list unanswered question numbers
ccaf-exam.sh audit                    # print composition histogram (domain quotas, key spread)
ccaf-exam.sh score [--partial]        # tally + scaled score + per-domain; marks attempt completed
ccaf-exam.sh clear                    # remove both attempt files
```

`init` enforces the blueprint composition for 60-question exams: domain quotas 16/11/12/12/9,
exactly 4 scenarios, contiguous `[[CASE:]]`-headed sections, non-degenerate key spread (6–26
per letter). `record` calls mid-exam run in the background (the next screen shows immediately);
the final screen records in the foreground. All writes serialize through a directory lock.

## Blueprint composition (enforced at init and score)

| Domain | Questions | Weight |
| --- | --- | --- |
| D1 | 16 | 27 % |
| D2 | 11 | 18 % |
| D3 | 12 | 20 % |
| D4 | 12 | 20 % |
| D5 |  9 | 15 % |

4 of 6 available scenarios are selected per attempt. Each scenario's questions form a
contiguous section in the file, headed by a `[[CASE:slug]]` block (title + brief). This
guarantees the brief shown above a screen always belongs to that screen's questions.

## Plugin structure

This is a Claude Code plugin (no build step, no `package.json`). The plugin manifest is at
`.claude-plugin/plugin.json`. Commands in `commands/` are loaded by the Claude Code harness;
each file's YAML frontmatter (`allowed-tools`) restricts what Bash commands the command may run
— `mock-exam.md` is sandboxed to `scripts/ccaf-exam.sh *`.
