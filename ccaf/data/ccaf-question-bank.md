# CCAF Mock Exam — Reference Question Bank

A set of **12 self-authored reference questions** spanning the five domains and all six scenario
contexts. They are **anchors only**: the assembler reads them as few-shot references for style,
difficulty, and distractor construction — they are **never copied into an assembled exam** (every
served question is generated fresh; the state helper rejects any bank-sourced block). Rationale:
this file ships in the plugin with answers and explanations, so a candidate may have read it —
serving these questions would inflate scores. Each question was written for this plugin against
the blueprint's self-authored syllabus; none reproduces exam material. Stable and
version-controlled — not regenerated at runtime. The `correct` letter refers to the option text.

Each entry: stable `id`, `source: authored`, `domain` (D1–D5), `scenario` slug, `stem`, four
`options`, the `correct` letter, and an `explanation` that says why the right answer is right and
why the distractors are wrong — the explanation tone is part of what generated questions anchor to.

```yaml
questions:
  - id: ref-01
    source: authored
    domain: D1
    scenario: customer-support
    stem: >-
      Your support agent runs on a hand-rolled loop around the Messages API. The loop exits as
      soon as the model's reply text contains the phrase "issue resolved" — and tickets are being
      closed with refunds promised to the customer but issue_refund never actually called. What
      should determine when the loop ends?
    options:
      A: A fixed ceiling of eight iterations, which is more than any normal ticket needs.
      B: The API's stop_reason — keep executing requested tools and appending their results while it is "tool_use", and finish only on "end_turn".
      C: A unique end-of-ticket sentinel token the model is instructed to emit when it considers the ticket complete.
      D: The first response that contains assistant prose rather than a tool call.
    correct: B
    explanation: >-
      stop_reason is the API's contract for whether the model intends to keep acting: "tool_use"
      means there is work in flight, "end_turn" means it is done. Scanning prose (the current bug),
      a sentinel token (C), or prose-vs-tool-call shape (D) are all text heuristics — the model can
      narrate before or alongside tool calls, so they exit early in exactly this way. An iteration
      ceiling (A) is a runaway backstop, not a stop condition; it truncates legitimately long
      tickets.

  - id: ref-02
    source: authored
    domain: D1
    scenario: multi-agent-research
    stem: >-
      Your coordinator delegates source-gathering to a search subagent, then spawns an analysis
      subagent prompted to "evaluate the credibility of the sources found earlier." The analysis
      subagent consistently replies that no sources were provided. What is actually wrong?
    options:
      A: The analysis subagent's tool list is missing the search tool, so it cannot re-run the search itself.
      B: The coordinator should resume the search subagent's session so the analysis step runs inside that memory.
      C: Subagents start with isolated context — the coordinator must pass the gathered sources, with their metadata, explicitly in the analysis subagent's prompt.
      D: The two subagents must be spawned in the same response so they share a conversation thread.
    correct: C
    explanation: >-
      Subagents do not inherit the coordinator's history or each other's — "found earlier" refers
      to context the analysis agent has never seen. The fix is to pass the findings explicitly
      (structured, with source metadata so attribution survives). A misdiagnoses — the job is to
      evaluate provided sources, not re-search; B misuses session resume, which is continuity for
      one agent, not memory sharing across agents; D is false — parallel spawning does not create
      shared context.

  - id: ref-03
    source: authored
    domain: D1
    scenario: developer-productivity
    stem: >-
      Your Agent SDK tool investigates "why is this legacy service slow?" Today it always runs the
      same five analysis steps in a fixed order, and usually burns most of its budget on steps
      irrelevant to the actual bottleneck — a hot query should lead to schema inspection, a chatty
      API call pattern to network tracing. What should you change?
    options:
      A: Replace the fixed sequence with dynamic decomposition - let each finding determine which investigation the agent runs next.
      B: Keep the pipeline but reorder the five steps from cheapest to most expensive.
      C: Run all five steps in parallel so the irrelevant ones at least add no wall-clock time.
      D: Append a sixth step that re-runs any earlier step whose output looked irrelevant.
    correct: A
    explanation: >-
      Open-ended diagnosis is the textbook case for adaptive decomposition: intermediate findings
      should steer the next delegation. Fixed chains suit predictable, always-the-same work — not
      investigation. B and C optimize the cost or latency of a plan that is wrong in the first
      place (and C still spends the budget), while D doubles down after the waste has happened
      instead of preventing it.

  - id: ref-04
    source: authored
    domain: D2
    scenario: customer-support
    stem: >-
      Whenever issue_refund fails, your MCP server returns the bare string "refund failed" — the
      same for card-network timeouts, refund-window-expired policy rejections, and malformed
      amounts. The agent responds by retrying all of them three times, including the policy
      rejections it should be explaining to the customer. What should the server return instead?
    options:
      A: An HTTP-style numeric status code, so the model can look up the failure class.
      B: Nothing - failures should raise and terminate the loop so a human reviews every failed refund.
      C: The raw upstream payment-processor response, so no failure detail is lost.
      D: A structured error via the isError flag carrying a category, a retryable indicator, and a human-readable explanation - with policy rejections marked non-retryable.
    correct: D
    explanation: >-
      The agent retries everything because the error gives it nothing to discriminate on. A
      structured error (category + retryable + explanation) lets it retry the timeout, fix the
      malformed amount, and explain the policy rejection. A bare numeric code (A) assumes lookup
      knowledge and still omits the explanation; killing the loop (B) turns recoverable faults
      into outages; raw processor payloads (C) are uninterpretable to the model and risk leaking
      internals.

  - id: ref-05
    source: authored
    domain: D2
    scenario: developer-productivity
    stem: >-
      Your codebase-exploration agent has accumulated 22 tools spanning search, build, ticketing,
      deployment, and docs. Logs show it now regularly calls deployment and ticketing tools in the
      middle of exploration tasks and often picks the wrong search variant. What is the most
      effective fix?
    options:
      A: Scope the agent to the few search-and-read tools its job needs, and expose the other capabilities through separate role-specific agents.
      B: Keep all 22 tools but add a system-prompt rule listing which tools are appropriate during exploration.
      C: Require interactive approval before every tool call so misuse gets caught by a human.
      D: Collapse everything into a single execute(action, args) tool so there is only one tool to choose.
    correct: A
    explanation: >-
      Selection reliability degrades as the catalog grows, and tools outside the agent's role
      invite misuse - scoping the toolset to the role fixes the cause. A prompt rule (B) is a
      probabilistic patch on top of a structural problem; human approval per call (C) destroys
      throughput without improving selection; one generic mega-tool (D) just moves the
      disambiguation into an untyped argument, where it gets worse.

  - id: ref-06
    source: authored
    domain: D3
    scenario: code-generation
    stem: >-
      You wrote naming-convention instructions that Claude Code follows perfectly on your machine,
      but every teammate reports it ignores them entirely. What is the most likely cause, and the
      fix?
    options:
      A: Teammates' installations cache stale configuration; have them reinstall Claude Code.
      B: Conventions must be duplicated into every subdirectory's CLAUDE.md to load reliably; copy them down the tree.
      C: The instructions live in your personal ~/.claude/CLAUDE.md; move them into the project's committed CLAUDE.md and verify with /memory on a teammate's machine.
      D: The instructions must be registered in .claude/commands/ to be loaded at session start.
    correct: C
    explanation: >-
      "Works only for the author" is the signature of user-level memory: ~/.claude/CLAUDE.md is
      personal and never ships with the repo. Project-level CLAUDE.md is committed, so everyone
      gets it on clone/pull - and /memory confirms what actually loaded. A invents a caching
      mechanism; B misunderstands the hierarchy (directory files scope context, they are not
      required duplication); D confuses memory with slash commands.

  - id: ref-07
    source: authored
    domain: D3
    scenario: claude-code-ci
    stem: >-
      Your pipeline runs `claude -p "review this diff"` and then greps the prose output for the
      word "critical" to decide whether to block the merge. It misfires constantly - most recently
      blocking on "no critical issues found." What is the right approach?
    options:
      A: Harden the grep with word boundaries and a denylist of negating phrases like "no critical".
      B: Request structured results - run with --output-format json constrained by a findings/severity schema, and have the gate read fields instead of prose.
      C: Lower the model temperature so the review wording becomes predictable enough to grep.
      D: Instruct the model to end its review with exactly "BLOCK" or "PASS" and grep only the final line.
    correct: B
    explanation: >-
      Gating decisions need a machine contract, and schema-constrained JSON output is that
      contract - the gate reads severity fields, not sentences. Hardening the grep (A) is an arms
      race against natural language; temperature (C) changes sampling, not the absence of a
      contract; a sentinel last line (D) is still an unenforced prose convention the model can
      violate or bury, just a smaller grep.

  - id: ref-08
    source: authored
    domain: D3
    scenario: code-generation
    stem: >-
      Your team has a 40-step release-cutting procedure used about twice a month, and a half-page
      of universal coding standards that should apply in every session. Where should each live in
      Claude Code?
    options:
      A: Both in the root CLAUDE.md, so neither can ever be missed.
      B: Both as skills, so they are versioned and loaded only on demand.
      C: The release procedure in CLAUDE.md since it is critical; the routine coding standards as a skill.
      D: The coding standards in the committed CLAUDE.md (always loaded); the release procedure as a skill invoked when someone cuts a release.
    correct: D
    explanation: >-
      The split follows usage: universal standards belong in always-loaded project memory, while
      an occasional multi-step procedure belongs in an on-demand skill. Putting the 40 steps in
      CLAUDE.md (A, C) taxes every single session with content used twice a month; making the
      standards a skill (B, C) means they are absent unless someone remembers to invoke them -
      backwards on both counts.

  - id: ref-09
    source: authored
    domain: D4
    scenario: structured-extraction
    stem: >-
      Your invoice extractor's schema marks purchase_order_number as required and non-nullable.
      For invoices that genuinely have no PO, the model fabricates plausible-looking PO numbers,
      and downstream matching silently accepts them. Adding "never fabricate values" to the prompt
      has not fixed it. What will?
    options:
      A: Make the field nullable (or optional) so the model can return null when the document has no PO, and have downstream handle null explicitly.
      B: Add few-shot examples in which fabricated PO numbers are shown and corrected.
      C: Add a regex pattern constraint to the field so invented values fail schema validation.
      D: Set temperature to zero so the model stops producing creative field values.
    correct: A
    explanation: >-
      A required non-nullable field gives the model no legal way to say "absent," so it must
      invent - the schema is the cause, and nullability is the structural fix. Few-shot scolding
      (B) fights the schema's incentive without removing it; a regex (C) cannot reject a
      fabricated number that matches the real format; temperature zero (D) makes the fabrication
      deterministic, not absent.

  - id: ref-10
    source: authored
    domain: D4
    scenario: claude-code-ci
    stem: >-
      Your automated PR reviewer drowns teams in nitpicks, so you added "Be conservative - report
      only high-confidence, important issues" to the prompt. The noise barely changed. What is the
      effective fix?
    options:
      A: Add "think step by step before reporting each issue" so findings are better reasoned.
      B: Run the review twice and report only the issues that appear in both runs.
      C: Replace the vague instruction with explicit categories - define which issue types to report and which to skip, with concrete examples and severity rules for each.
      D: Cap the reviewer at five findings per pull request so only the most severe surface.
    correct: C
    explanation: >-
      Precision comes from the model knowing what counts, and confidence adjectives do not define
      that - explicit report/skip categories with examples do. Deeper reasoning per finding (A)
      polishes findings it should not be making; double-run intersection (B) doubles cost and
      suppresses real intermittent findings while still never defining "important"; a numeric cap
      (D) hides genuine issues on bad PRs and still lets five nitpicks through on clean ones.

  - id: ref-11
    source: authored
    domain: D5
    scenario: multi-agent-research
    stem: >-
      Spot-checks of your research briefs show claims cited to the wrong documents. Subagents
      return prose summaries, and the synthesis agent adds citations afterward by matching each
      claim to whichever gathered source looks most related. How do you make citations
      trustworthy?
    options:
      A: Give the synthesis agent search access so it can re-verify each claim before citing it.
      B: Require subagents to return structured claim-source mappings (claim, source, excerpt, date) and have synthesis carry those mappings through rather than re-attributing.
      C: Append the full text of every gathered source to the synthesis prompt so it can check its own attributions.
      D: Add a final proofreading agent that checks every citation against the bibliography's format.
    correct: B
    explanation: >-
      Attribution is destroyed at summarization time; once claims are detached from sources, any
      later matching - by synthesis (now) or re-verification (A) - is guesswork that costs extra
      and can land on a different source than the one actually used. Preserving claim-source
      mappings end-to-end keeps the link that existed when the claim was extracted. Full-text
      stuffing (C) blows the context window and still re-attributes heuristically; format
      checking (D) validates the wrong property.

  - id: ref-12
    source: authored
    domain: D5
    scenario: structured-extraction
    stem: >-
      Your extraction pipeline reports 97% overall accuracy, and leadership wants to auto-approve
      every extraction the model scores above 0.9 confidence. What should you verify before
      agreeing?
    options:
      A: That the 97% figure was measured on a sample large enough to be statistically stable.
      B: That confidence is computed per document rather than per field, since documents are the approval unit.
      C: That a second extraction run agrees with the first on at least 95% of high-confidence fields.
      D: That accuracy holds per document type and per field on labeled samples, and that 0.9 confidence actually corresponds to an acceptable error rate - by stratified sampling of high-confidence extractions.
    correct: D
    explanation: >-
      An aggregate 97% can hide systematic failure on one document type or field, and model
      confidence is meaningless for gating until calibrated against ground truth - both must be
      checked on labeled, stratified samples before automation. Sample size (A) stabilizes the
      aggregate without unmasking segments; per-document confidence (B) is coarser, the wrong
      direction; run-to-run agreement (C) measures consistency, and correlated errors agree with
      themselves.
```

## Anchor coverage of the reference bank

| Domain | Reference questions |
| ------ | ------------------- |
| D1     | ref-01, ref-02, ref-03 |
| D2     | ref-04, ref-05 |
| D3     | ref-06, ref-07, ref-08 |
| D4     | ref-09, ref-10 |
| D5     | ref-11, ref-12 |

Every scenario has two anchor examples: `customer-support` (ref-01, ref-04), `code-generation`
(ref-06, ref-08), `multi-agent-research` (ref-02, ref-11), `developer-productivity` (ref-03,
ref-05), `claude-code-ci` (ref-07, ref-10), `structured-extraction` (ref-09, ref-12). Either way,
every served question is generated fresh — these 12 never appear in an exam.
