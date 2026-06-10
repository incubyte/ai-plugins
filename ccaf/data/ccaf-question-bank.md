# CCAF Mock Exam — Reference Question Bank

A curated set of **12 self-authored reference questions** spanning the five domains and the
scenario contexts. They are **anchors only**: the assembler reads them as few-shot references for
style, difficulty, and distractor construction — they are **never copied into an assembled exam**
(every served question is generated fresh; the state helper rejects any `id: seed-*` /
`source: authored` block). Rationale: this file ships in the plugin with answers and explanations,
so a candidate may have read it — serving these questions would inflate scores. Stable and
version-controlled — not regenerated at runtime. The `correct` letter refers to the option text.

Each entry: stable `id`, `source: authored`, `domain` (D1–D5), `scenario` slug, `stem`, four
`options`, the `correct` letter, and an `explanation` that says why the right answer is right and
why the distractors are wrong — the explanation tone is part of what generated questions anchor to.

```yaml
questions:
  - id: seed-01
    source: authored
    domain: D1
    scenario: customer-support
    stem: >-
      Your support agent must confirm a customer's identity with verify_identity before it calls
      issue_credit. In testing it usually does, but in roughly 1 in 10 sessions it issues a credit
      first. The fix has to be reliable because credits move money. What is the best approach?
    options:
      A: Add a prerequisite gate (hook) that blocks issue_credit until verify_identity has succeeded.
      B: Strengthen the system prompt to require identity verification before any credit.
      C: Add few-shot examples that always verify identity before issuing a credit.
      D: Lower the model temperature so it follows the ordering instruction more reliably.
    correct: A
    explanation: >-
      Money-moving steps need deterministic enforcement. A programmatic prerequisite (hook/gate)
      guarantees the order; prompt strengthening (B) and few-shot (C) only reduce — never eliminate —
      the failure rate, which is unacceptable when errors move money. Temperature (D) does not
      guarantee tool ordering.

  - id: seed-02
    source: authored
    domain: D2
    scenario: customer-support
    stem: >-
      Your agent keeps calling check_balance when users ask to "see my recent transactions," which
      should route to list_transactions. Both tools are described only as "Returns account data."
      What is the most effective first step to fix tool selection?
    options:
      A: Add a pre-turn keyword router that maps phrases to tools before the model runs.
      B: Merge the two tools into a single get_account tool.
      C: Rewrite each tool's description with its purpose, inputs, example queries, and when to use it versus the other.
      D: Add ten few-shot routing examples to the system prompt.
    correct: C
    explanation: >-
      Tool descriptions are the model's primary selection signal; enriching them is the low-effort,
      root-cause fix. A router (A) over-engineers and bypasses the model's understanding; merging (B)
      is a larger change than a "first step"; few-shot (D) adds tokens without addressing the thin
      descriptions.

  - id: seed-03
    source: authored
    domain: D5
    scenario: customer-support
    stem: >-
      A billing agent escalates simple in-policy refunds to humans, yet tries to resolve unusual
      cases the policy does not cover. First-contact resolution is low. What is the most
      proportionate first improvement?
    options:
      A: Route to a human whenever the model's self-reported confidence is below 8/10.
      B: Train a separate classifier on historical tickets to predict which cases to escalate.
      C: Auto-escalate whenever the customer's sentiment turns negative.
      D: Add explicit escalate-versus-resolve criteria, with few-shot examples, to the system prompt.
    correct: D
    explanation: >-
      The root cause is unclear decision boundaries, which explicit criteria plus examples fix
      proportionately. LLM self-confidence (A) is poorly calibrated; a trained classifier (B) is
      over-built before prompt optimization is tried; sentiment (C) does not track case complexity.

  - id: seed-04
    source: authored
    domain: D3
    scenario: code-generation
    stem: >-
      You wrote a /standup slash command and want every teammate to get it automatically when they
      clone or pull the repository. Where should the command file live?
    options:
      A: In ~/.claude/commands/standup.md in each developer's home directory.
      B: In .claude/commands/standup.md committed to the repository.
      C: In a "commands" section of the root CLAUDE.md.
      D: In a .claude/config.json file with a commands array.
    correct: B
    explanation: >-
      Project-scoped commands live in .claude/commands/ and ship via version control, so everyone
      gets them on clone/pull. ~/.claude (A) is personal and not shared; CLAUDE.md (C) holds context,
      not command definitions; (D) is not a real Claude Code mechanism.

  - id: seed-05
    source: authored
    domain: D3
    scenario: code-generation
    stem: >-
      You must split a shared "utils" module into well-bounded packages across about 30 files, and
      there are a couple of reasonable ways to draw the boundaries. How should you start in Claude
      Code?
    options:
      A: Direct execution driven by one detailed, up-front instruction set.
      B: Direct execution, refactoring file by file and letting the boundaries emerge.
      C: Direct execution, switching to plan mode only if it becomes messy.
      D: Plan mode, to map dependencies and decide the boundary design before editing.
    correct: D
    explanation: >-
      Multi-file scope, multiple valid approaches, and a structural decision point call for plan mode
      — explore and design before committing. The complexity is known up front, so deferring planning
      (B, C) risks costly rework, and (A) assumes the design is already settled.

  - id: seed-06
    source: authored
    domain: D3
    scenario: code-generation
    stem: >-
      Your repo mixes services with different styles, and you want one set of conventions applied to
      every file matching **/*.handler.ts regardless of which directory it sits in. What is the most
      maintainable setup?
    options:
      A: A .claude/rules/ file with `paths: ["**/*.handler.ts"]` glob frontmatter.
      B: One large root CLAUDE.md with a section per convention.
      C: A skill per service that the developer loads manually.
      D: A CLAUDE.md placed in each directory that contains handler files.
    correct: A
    explanation: >-
      Path-scoped rules with glob frontmatter apply by file pattern across directories — exactly the
      scattered-files case. Root CLAUDE.md (B) relies on inference; manual skills (C) are not
      automatic; per-directory CLAUDE.md files (D) cannot cleanly span files spread across the tree.

  - id: seed-07
    source: authored
    domain: D1
    scenario: multi-agent-research
    stem: >-
      Asked to cover "the global impact of remote work," your research system returns a thorough
      report — but only about the software industry, ignoring healthcare, education, and
      manufacturing. Each subagent handled its assigned subtopic well. What is the most likely root
      cause?
    options:
      A: The synthesis agent failed to flag coverage gaps in what it received.
      B: The web-search agent's queries were not broad enough.
      C: The coordinator decomposed the topic too narrowly, so whole sectors were never assigned.
      D: The document-analysis agent filtered out non-software sources.
    correct: C
    explanation: >-
      The subagents executed their assignments correctly; the gap is in what the coordinator chose to
      assign. Options A, B, and D blame downstream agents that worked correctly within the scope they
      were given.

  - id: seed-08
    source: authored
    domain: D5
    scenario: multi-agent-research
    stem: >-
      A document-fetch subagent receives a 503 from a source. How should it report the failure so the
      coordinator can recover intelligently?
    options:
      A: Retry silently with backoff and, if all retries fail, return "fetch failed."
      B: Return structured context — failure type, what was attempted, any partial results, and possible alternatives.
      C: Return an empty result marked successful so the pipeline keeps moving.
      D: Throw the error to a top-level handler that aborts the entire research run.
    correct: B
    explanation: >-
      Structured error context lets the coordinator decide whether to retry, reroute, or proceed with
      partial results. A generic status (A) hides that context; marking failure as success (C)
      silently drops coverage; aborting the whole run (D) is disproportionate to one source failing.

  - id: seed-09
    source: authored
    domain: D2
    scenario: multi-agent-research
    stem: >-
      Your synthesis agent frequently confirms small facts (dates, figures) mid-write by round-tripping
      through the coordinator to the search agent, adding latency. About 80% are trivial lookups and
      20% need real investigation. What is the most effective fix?
    options:
      A: Give the synthesis agent access to every search tool so it never round-trips.
      B: Have it batch all verification needs and send them to the coordinator at the end of the pass.
      C: Have the search agent pre-cache extra context around each source in case synthesis needs it.
      D: Give synthesis a narrow verify_fact tool for simple lookups, keeping coordinator-routed search for the complex 20%.
    correct: D
    explanation: >-
      Least privilege: give synthesis just enough for the common case while preserving the existing
      path for hard cases. Full tool access (A) over-provisions and invites misuse; end-of-pass
      batching (B) breaks steps that depend on earlier verified facts; speculative caching (C) cannot
      reliably predict what synthesis will need.

  - id: seed-10
    source: authored
    domain: D3
    scenario: claude-code-ci
    stem: >-
      Your CI job runs `claude "review this diff"` and the job hangs waiting for input. What is the
      correct way to run Claude Code non-interactively in a pipeline?
    options:
      A: Add the -p / --print flag — `claude -p "review this diff"`.
      B: Set an environment variable CI=true before running the command.
      C: Redirect stdin from /dev/null.
      D: Add a --ci flag — `claude --ci "review this diff"`.
    correct: A
    explanation: >-
      -p / --print is the documented non-interactive mode: it processes the prompt, writes the result
      to stdout, and exits. The others reference a non-existent env var (B) or flag (D), or a shell
      workaround (C) that doesn't address Claude Code's command design.

  - id: seed-11
    source: authored
    domain: D4
    scenario: claude-code-ci
    stem: >-
      You have (1) a pre-commit check developers wait on and (2) a weekend codebase-wide quality
      sweep. Someone proposes moving both to the Message Batches API for the cost savings. What is the
      right call?
    options:
      A: Move both to the Batches API and poll for completion.
      B: Use the Batches API for the weekend sweep only; keep the pre-commit check synchronous.
      C: Keep both synchronous to avoid batch result-ordering problems.
      D: Move both to batch with a fallback to synchronous if a batch runs long.
    correct: B
    explanation: >-
      Batch processing is ~50% cheaper but can take up to ~24h with no latency SLA — ideal for the
      latency-tolerant weekend sweep, unsuitable for a blocking pre-commit check. (A) gambles on
      speed for a blocking flow; (C) misunderstands that custom_id handles correlation; (D) adds
      complexity the simple split avoids.

  - id: seed-12
    source: authored
    domain: D4
    scenario: claude-code-ci
    stem: >-
      An automated review of a 20-file pull request gives deep feedback on some files, shallow on
      others, misses obvious bugs, and even contradicts itself across files. How should you
      restructure the review?
    options:
      A: Require developers to submit pull requests of four files or fewer.
      B: Switch to a larger-context model so all 20 files fit in one pass.
      C: Run per-file passes for local issues, plus a separate cross-file integration pass.
      D: Run the full PR three times and report only issues that appear in at least two runs.
    correct: C
    explanation: >-
      The root cause is attention dilution across many files; focused per-file passes plus a separate
      integration pass restore depth and consistency. (A) shifts the burden to developers; (B)
      misreads that a bigger context window does not fix attention quality; (D) suppresses real bugs
      that are only caught intermittently.
```

## Anchor coverage of the reference bank

| Domain | Reference questions |
| ------ | ------------------- |
| D1     | seed-01, seed-07 |
| D2     | seed-02, seed-09 |
| D3     | seed-04, seed-05, seed-06, seed-10 |
| D4     | seed-11, seed-12 |
| D5     | seed-03, seed-08 |

Scenarios with anchor examples: `customer-support`, `code-generation`, `multi-agent-research`,
`claude-code-ci` (4 of 6). For `developer-productivity` and `structured-extraction`, anchor on
the nearest-domain references plus the blueprint's case-study briefs. Either way, every served
question is generated fresh — these 12 never appear in an exam.
