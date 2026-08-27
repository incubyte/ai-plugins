# CCAF Mock Exam — Reference Question Bank

A set of **30 self-authored reference questions** — one per task statement, covering all five
domains, all 30 task statements (D1.1–D5.6), and all six scenario contexts. Every item is
single-answer: four options, exactly one correct. They are **anchors only**: the assembler reads
them as few-shot references for style, difficulty, and distractor construction — they are **never
copied into an assembled exam** (every served item is generated fresh; the state helper rejects any
bank-sourced block). Rationale: this file ships in the plugin with answers and explanations, so a
candidate may have read it — serving these would inflate scores. Every question here was written for
this plugin against the blueprint's task statements and anti-pattern catalogs; none reproduces exam
material or any part of the published exam guide. Stable and version-controlled — not regenerated at
runtime.

Each entry:

| Field | Meaning |
| ----- | ------- |
| `id` | stable identifier (`ref-NN`) |
| `source` | always `authored` — the marker the helper rejects at exam-write time |
| `domain` | `D1`–`D5` |
| `task` | the task statement it tests (`D1.1`–`D5.6`, see the blueprint syllabus) |
| `scenario` | one of the six scenario slugs |
| `stem` | the question |
| `options` | exactly four options, `A`–`D` |
| `correct` | the correct letter |
| `explanation` | why the correct option is right **and** why each distractor is wrong — the explanation tone is part of what generated items anchor to |

> **Do not imitate these anchors' answer positions.** The `correct` letters here are lopsided
> (A appears far more often than D) because each question was written for its content, not its key
> position. Answer position must be shuffled independently per attempt, and the state helper refuses
> a full mock whose keys are skewed — see `check_key_spread`. Anchor *content* is the reference;
> anchor *letters* are noise.

```yaml
questions:
  - id: ref-01
    source: authored
    domain: D1
    task: D1.1
    scenario: customer-support
    stem: >-
      Your support agent runs on a hand-rolled loop around the Messages API. The loop exits as
      soon as the model's reply text contains the phrase "issue resolved" — and tickets are being
      closed with refunds promised to the customer but process_refund never actually called. What
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
    task: D1.3
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
    task: D1.6
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
    task: D2.2
    scenario: customer-support
    stem: >-
      Whenever process_refund fails, your MCP server returns the bare string "refund failed" — the
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
    task: D2.3
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
    task: D3.1
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
    task: D3.6
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
    task: D3.2
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
    task: D4.3
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
    task: D4.1
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
    task: D5.6
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
    task: D5.5
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

  - id: ref-13
    source: authored
    domain: D1
    task: D1.4
    scenario: customer-support
    stem: >-
      Your agent may refund a return only once the warehouse has confirmed receipt. In roughly 8%
      of tickets it calls process_refund on the customer's assertion that they posted the item
      back, before lookup_order has confirmed anything, and finance is absorbing the losses. You
      have already strengthened the system prompt twice. What actually closes this?
    options:
      A: A programmatic prerequisite that blocks process_refund until lookup_order has returned a confirmed-received status for that order.
      B: A system-prompt rule stating in capitals that receipt confirmation is mandatory before any refund.
      C: Few-shot examples showing the agent declining to refund until receipt is confirmed.
      D: A lower temperature, so the agent follows the documented sequence more consistently.
    correct: A
    explanation: >-
      An order-sensitive step that moves money needs a deterministic gate - code that refuses the
      call until its precondition holds. B and C are the two probabilistic controls already known
      to have a non-zero failure rate, and the prompt has been strengthened twice; repeating a
      probabilistic control does not make it deterministic. D changes sampling, not availability -
      the model can still choose process_refund at any temperature.

  - id: ref-14
    source: authored
    domain: D2
    task: D2.1
    scenario: multi-agent-research
    stem: >-
      Your research system exposes search_web ("Searches for information") and search_archive
      ("Searches stored documents"). The search subagent sends live-web queries to search_archive
      about a third of the time, gets nothing back, and the coordinator then reports thin
      coverage. What is the most effective first step?
    options:
      A: Expand both descriptions to state what each searches, the query formats each expects, worked examples, and an explicit boundary naming when to use the other instead.
      B: Add a preprocessing step that classifies each query and calls whichever tool the classifier selects.
      C: Merge them into one search tool taking a source parameter the model must set.
      D: Add eight few-shot examples to the coordinator prompt showing live-web queries routed to search_web.
    correct: A
    explanation: >-
      Descriptions are the interface the model selects on, and these two are nearly
      interchangeable - "searches for information" does not tell the model where a live-web query
      belongs. Fixing the descriptions addresses the cause at the lowest cost. B replaces language
      understanding with a keyword classifier and adds a component to maintain; C moves the same
      ambiguity into an untyped parameter, where a wrong source value fails just as silently; D is
      token overhead layered on descriptions that still do not differentiate, and examples
      generalize poorly while the interface stays ambiguous.

  - id: ref-15
    source: authored
    domain: D5
    task: D5.2
    scenario: customer-support
    stem: >-
      Your agent escalates too rarely on the cases that need a human and too often on ones it could
      close, so you are rewriting its escalation criteria. Which rule should the criteria encode?
    options:
      A: Escalate when the customer explicitly asks for a person, when the policy is silent on what they are asking for, or when no further progress is possible.
      B: Escalate when the customer's messages read as angry or use strongly negative language.
      C: Escalate when the agent's own confidence in its proposed resolution falls below a threshold.
      D: Escalate whenever a ticket raises more than one distinct issue, since multi-issue cases are inherently complex.
    correct: A
    explanation: >-
      Escalation should fire on observable triggers - an explicit request (honored immediately,
      without investigating first), a request the policy does not address, or genuine deadlock. B and
      C are the classic unreliable proxies: sentiment tracks how someone feels, not whether the case
      exceeds the agent's capability, and self-reported confidence is poorly calibrated exactly where
      it matters. D invents a trigger - a multi-issue ticket is a decomposition problem, not an
      escalation one.
  - id: ref-16
    source: authored
    domain: D3
    task: D3.3
    scenario: code-generation
    stem: >-
      Every service in your monorepo keeps SQL migrations beside its own code
      (services/billing/migrations/, services/catalog/migrations/, and so on), and all migrations
      must follow the same reversibility and naming conventions wherever they live. Claude applies
      them inconsistently today. What is the most maintainable fix?
    options:
      A: A file in .claude/rules/ whose frontmatter scopes it with a glob such as **/migrations/*.sql, so the conventions load whenever a migration is touched.
      B: A migrations section in the root CLAUDE.md, relying on Claude to notice when it applies.
      C: A copy of the migration conventions in each service directory's own CLAUDE.md.
      D: A .claude/skills/write-migration/SKILL.md holding the conventions, invoked when someone writes a migration.
    correct: A
    explanation: >-
      The convention attaches to a file pattern recurring across many directories, which is
      exactly what a glob-scoped rule file is for - it loads automatically when a matching file is
      touched and stays out of every other session. B depends on the model inferring
      applicability from a heading, which is not deterministic. C is the maintenance trap: the
      same block duplicated per service, drifting the moment one copy changes. D makes automatic
      behavior contingent on somebody remembering to invoke a skill, when the requirement is that
      it applies by itself.

  - id: ref-17
    source: authored
    domain: D3
    task: D3.4
    scenario: developer-productivity
    stem: >-
      Your team is calibrating when plan mode is worth its cost. Which of these tasks most clearly
      warrants it?
    options:
      A: Renaming a misspelled constant that appears in four files.
      B: Splitting a shared utilities package into three, changing imports in about 60 files and requiring decisions about where each helper belongs.
      C: Adding a null check to one function after a stack trace pointed straight at the line.
      D: Regenerating an API client from an updated OpenAPI spec, where the generator output is deterministic.
    correct: B
    explanation: >-
      Plan mode pays for itself when work is large-scale and has genuine design decisions to settle
      before code moves - B must decide the new boundaries, and exploring first is what prevents
      rework. A and D are multi-file but have nothing to decide; the change is mechanical, which is
      the point that file count alone is not the trigger. C is the direct-execution case: one
      obvious change with a clear cause.
  - id: ref-18
    source: authored
    domain: D1
    task: D1.2
    scenario: multi-agent-research
    stem: >-
      A brief on "regulatory pressure on payment processors" came back covering only EU
      regulation. Every subagent succeeded - the search agent found good EU sources, analysis
      summarized them accurately, synthesis produced a clean report. The coordinator's log shows
      it created three subtasks: "EU PSD2 changes", "EU interchange caps", and "EU open-banking
      mandates". What should you change?
    options:
      A: Have the coordinator plan its decomposition against the dimensions the topic actually spans - jurisdiction, regulation type, time horizon - and check the subtask set covers them before delegating.
      B: Instruct the synthesis agent to identify coverage gaps in the findings it receives and flag them in the report.
      C: Broaden the search agent's queries so it returns sources beyond whichever region its subtask names.
      D: Loosen the analysis agent's relevance filter so it stops discarding non-EU sources.
    correct: A
    explanation: >-
      The subagents did exactly what they were assigned; the assignment was the defect. A
      decomposition that partitions one jurisdiction three ways can only produce a
      single-jurisdiction brief, so the fix belongs where scope is set - at the coordinator, before
      delegation. B is worth having but only annotates the gap after the fact; it cannot recover
      sources nobody was sent to find. C asks the search agent to ignore its own brief, which
      breaks scope partitioning everywhere else. D blames a filter that never ran - no non-EU
      sources reached analysis to be discarded.

  - id: ref-19
    source: authored
    domain: D5
    task: D5.3
    scenario: multi-agent-research
    stem: >-
      A document-analysis subagent fails partway through a batch of sources: two parse cleanly, the
      third times out repeatedly, and its local retries are exhausted. What should it report back to
      the coordinator?
    options:
      A: A single status value the coordinator can switch on, so recovery logic stays uniform across every subagent.
      B: Structured context - the failure type, the findings already extracted, what was attempted, and the retries already spent.
      C: An empty result marked successful, so one bad source does not fail the run.
      D: The raw timeout exception, propagated to a top-level handler that ends the research workflow.
    correct: B
    explanation: >-
      The coordinator has to choose between retrying differently, rerouting to another source, and
      proceeding degraded with a coverage note, and only structured context supports that choice -
      including the distinction between a timeout and a source that parsed but held nothing
      relevant. A collapses away every input the coordinator needs, and uniform recovery is the
      wrong goal since recovery should differ by failure type. C converts a failure into a fake
      success and silently drops coverage. D ends the whole run over one source when two already
      succeeded.
  - id: ref-20
    source: authored
    domain: D4
    task: D4.5
    scenario: claude-code-ci
    stem: >-
      Two automated workflows run against the synchronous API, and your lead wants both moved to
      the Message Batches API for the cost saving: (1) a nightly job generating missing test cases
      for the day's merged commits, reviewed by the team next morning, and (2) a security scan that
      must pass before a release branch is cut, inside a 30-minute build budget. What should you
      do?
    options:
      A: Move the nightly test generation to batch; keep the release-gate scan on the synchronous API.
      B: Move both and poll for completion - batches usually return well inside the window.
      C: Keep both synchronous, since batch results arrive out of order and cannot be matched back to their inputs.
      D: Move both, with a fallback that reissues synchronously if a batch has not returned in time.
    correct: A
    explanation: >-
      The Batches API trades latency for roughly half the cost: up to a 24-hour window and no
      latency SLA. Overnight test generation is indifferent to that; a release gate with a
      30-minute budget cannot absorb it. B treats typical-case timing as a guarantee, which is
      precisely what "no SLA" rules out for a blocking step. C is a misconception - custom_id
      correlates every request with its response. D pays for the same work twice and adds a
      timeout path to maintain, when matching each workload to the right API is simpler and
      already correct.

  - id: ref-21
    source: authored
    domain: D4
    task: D4.6
    scenario: claude-code-ci
    stem: >-
      In your pipeline one Claude Code session generates an implementation and then, in the same
      session, reviews its own diff. It reliably approves work that human reviewers later find
      bugs in, and spot-checks show a separate Claude Code run over the same diff catches several
      of them. What explains this best, and what should you do?
    options:
      A: The reviewing session still holds the reasoning it used to generate the code, so it is disposed to accept its own decisions - run the review as an independent instance with no generation context.
      B: The session's context window is nearly full by review time - raise the context budget so the whole diff fits with room to spare.
      C: The review prompt is not forceful enough - instruct the session to be adversarial and assume its own code is wrong.
      D: One pass cannot do both jobs well - have the same session generate, then review twice, and report only findings that recur.
    correct: A
    explanation: >-
      A model reviewing inside the generation session carries the justifications it just produced
      and is measurably less likely to question them; a fresh instance evaluates the diff on its
      evidence alone, which is why the separate run finds more. B misdiagnoses - the failure is
      disposition, not capacity, and more room does not make a model sceptical of itself. C is the
      same probabilistic patch as self-review instructions, only louder. D keeps the compromised
      context and then suppresses real findings, discarding any bug caught on one pass of two
      exactly when intermittent detection is what you needed.

  - id: ref-22
    source: authored
    domain: D1
    task: D1.5
    scenario: customer-support
    stem: >-
      Three MCP tools return dates differently: lookup_order gives Unix epoch seconds,
      get_customer gives ISO 8601 strings, and a shipping tool gives MM/DD/YYYY. The agent now
      miscalculates return windows, sometimes by weeks, and reasons out loud about converting the
      values. Where does this belong?
    options:
      A: A PostToolUse hook that normalizes each tool's date fields to one representation before the model ever sees the result.
      B: A system-prompt section documenting each tool's date format and the conversion arithmetic for each.
      C: An explicit parse_date tool the agent is instructed to call on every date before using it.
      D: Few-shot examples in which each format is converted correctly, one example per tool.
    correct: A
    explanation: >-
      Format heterogeneity is a data problem, not a reasoning problem, and a PostToolUse hook is
      the deterministic place to solve it - the model receives one consistent representation and
      never does date arithmetic at all. B and D leave the model performing conversions it will
      sometimes get wrong, and tax every turn for a transformation code does perfectly. C is
      worse: an extra round trip per date, and it still depends on the model remembering to call
      it - which is the failure mode you already have.

  - id: ref-23
    source: authored
    domain: D2
    task: D2.4
    scenario: developer-productivity
    stem: >-
      Your codebase-exploration agent needs a company Jira MCP server that every engineer should get
      automatically, and you are separately trialling an experimental graph-search server on your
      own machine. Both need auth tokens. How should you configure them?
    options:
      A: Both in the committed .mcp.json with the token values inline, since the repository is private.
      B: Jira in the committed .mcp.json referencing its token through environment-variable expansion; the experimental server in your user-scoped ~/.claude.json.
      C: Both in your user-scoped ~/.claude.json, sharing your config file with teammates who need Jira.
      D: Jira in the committed .mcp.json with its token in a committed .env file the server reads at startup.
    correct: B
    explanation: >-
      Scope follows audience - shared tooling belongs in committed project config so it arrives with
      a clone, and a personal experiment belongs in user scope where it cannot disturb anyone - and
      credentials are referenced through env-var expansion, never written into a committed file. A
      fails on that second point: repository privacy is not a secrets strategy, and a committed
      token is exposed to everyone with read access and to every fork and backup. C pushes shared
      setup onto each engineer individually, the "works on my machine" failure project scope exists
      to prevent. D commits the secret anyway, just one file over.
  - id: ref-24
    source: authored
    domain: D5
    task: D5.1
    scenario: customer-support
    stem: >-
      Late in long tickets your agent contradicts itself about amounts and dates it handled
      correctly earlier - quoting the wrong refund figure, forgetting a shipping credit it had
      promised. Your loop summarizes older turns to stay inside the context budget, and lookup_order
      returns 40-plus fields per call. What is the right fix?
    options:
      A: Summarize more aggressively, freeing more of the budget for recent turns.
      B: Instruct the agent to double-check every figure against earlier turns before quoting it.
      C: Keep a structured case-facts block - order numbers, amounts, statuses, commitments made - in every prompt outside the summarized history, and trim each tool result to the fields the ticket needs.
      D: Raise the summarization threshold so summarization begins later in the ticket.
    correct: C
    explanation: >-
      The figures are lost because summarization compresses exactly the load-bearing details, and
      the budget is being spent on tool output that mostly does not matter. Keeping facts outside
      the summary means they are never compressed, and trimming tool results removes the pressure
      that forced aggressive summarization in the first place. A makes the cause worse. B asks the
      model to check against turns that no longer contain the values, since the summary is what
      replaced them. D delays the same failure rather than preventing it.
  - id: ref-25
    source: authored
    domain: D1
    task: D1.7
    scenario: developer-productivity
    stem: >-
      Yesterday you used a named session to map a legacy billing service's dependency graph.
      Overnight another team merged a refactor that moved about half the modules you catalogued.
      You want to continue the investigation this morning. What is the soundest way to proceed?
    options:
      A: Start a fresh session and inject a written summary of yesterday's conclusions, noting that the module layout has since changed.
      B: Resume the named session with --resume and carry on asking questions as though nothing had changed.
      C: Resume the named session and ask it to re-read every file it examined yesterday before continuing.
      D: Use fork_session so yesterday's analysis is preserved on a branch while you continue on the trunk.
    correct: A
    explanation: >-
      Resuming carries forward tool results that are now wrong - the paths and module boundaries
      the session "knows" no longer exist, and nothing in the transcript tells it so. A written
      summary keeps the durable conclusions and drops the stale specifics. B is the anti-pattern
      itself. C pays the full re-exploration cost while leaving the outdated results in context to
      contradict the fresh ones. D misreads fork_session, which branches from a still-valid shared
      baseline; forking a stale baseline just yields two stale branches.

  - id: ref-26
    source: authored
    domain: D2
    task: D2.5
    scenario: developer-productivity
    stem: >-
      Your agent must find every caller of a normalizeAddress helper across an unfamiliar TypeScript
      monorepo, then change one call site whose surrounding line appears identically in three
      different files. What should it do?
    options:
      A: Use Glob for normalizeAddress to discover which files mention it, then Edit the target line.
      B: Use Grep for normalizeAddress to locate the call sites, then Read the target file and Write it back with the change.
      C: Use Grep for normalizeAddress, then Edit using the repeated line as the anchor, relying on it to change the first match.
      D: Read every file under the source root so the agent has full context, then Edit the target line.
    correct: B
    explanation: >-
      Grep searches file contents, which is what "find every caller" asks for, and when the anchor
      text is not unique the documented fallback is Read plus Write. A confuses the two search
      tools: Glob matches paths and filenames, so it finds nothing unless a file is named after the
      helper. C gets the search right but depends on first-match behaviour Edit does not promise - a
      non-unique anchor is exactly the case it refuses. D bulk-reads the codebase instead of
      building understanding incrementally, and still leans on the ambiguous Edit.
  - id: ref-27
    source: authored
    domain: D3
    task: D3.5
    scenario: code-generation
    stem: >-
      You need a caching layer in front of an internal pricing service, in a domain you have not
      worked in. Twice you have described what you want and received an implementation that missed
      something you only caught in review - first invalidation when upstream prices change, then
      behaviour during a cache-server outage. What should you do differently on the third attempt?
    options:
      A: Have Claude interview you about the requirements first - invalidation triggers, staleness tolerance, failure behaviour - and implement only once those answers are settled.
      B: Write a much longer and more detailed prose specification before asking for code again.
      C: Ask for three alternative implementations and pick whichever handles the most edge cases.
      D: Implement it yourself and ask Claude to review the result.
    correct: A
    explanation: >-
      Both failures share a cause: you did not know which decisions the design required, so you
      could not state them. Having the model surface the questions first converts unknown unknowns
      into explicit choices before any code exists. B assumes you can enumerate what you have
      twice failed to enumerate. C triples the cost and still leaves you judging edge cases you
      have not identified. D inverts the useful direction - the gap is in the requirements, and
      reviewing your own guesswork will not surface a requirement nobody wrote down.

  - id: ref-28
    source: authored
    domain: D4
    task: D4.2
    scenario: structured-extraction
    stem: >-
      Your contract extractor handles cleanly tabulated agreements well, but where the term length
      is stated in prose ("shall continue for a period of thirty-six (36) months from the
      Effective Date") it returns null for term_months about a third of the time. The schema is
      correct and the field is already nullable. What will most improve this?
    options:
      A: Add two to four examples demonstrating extraction from prose-stated terms alongside the tabulated ones already handled.
      B: Add an instruction to extract the term even when it is written in words rather than digits.
      C: Lower the temperature so extraction becomes more deterministic.
      D: Make term_months required and non-nullable so the model cannot return null.
    correct: A
    explanation: >-
      The schema is fine; the model is failing to recognise a structural variant, and targeted
      examples covering the variety actually present are the strongest fix - they also generalise
      to prose phrasings you did not enumerate. B is a prose instruction competing with the
      patterns the rest of the prompt teaches, so it helps unreliably. C makes the omission more
      consistent, not less. D is actively harmful: removing the legal way to say "absent" makes the
      model fabricate a term for contracts that genuinely have none.

  - id: ref-29
    source: authored
    domain: D4
    task: D4.4
    scenario: structured-extraction
    stem: >-
      Your pipeline retries any extraction that fails validation, appending the validation error to
      the retry prompt, but retry success is near zero for most failure classes. Which failure is
      worth retrying?
    options:
      A: tax_id failed validation because the invoice does not print a tax ID anywhere.
      B: purchase_order failed because the PO lives in a separate procurement system, not on the invoice.
      C: The line items sum to 4,180.00 but total_amount came back as 418.00.
      D: contract_end_date failed because the agreement states only a term length, and the start date is in a separate addendum you were not given.
    correct: C
    explanation: >-
      C is the model mishandling data that is present - a transposed decimal is visible in the
      source, and naming the error is usually enough to correct it. A, B and D are the limit of
      retrying: the information is not in the document, so no number of attempts can produce it, and
      each retry either re-fails or pressures the model into inventing a value. Those belong in
      null-plus-human-review, not the retry loop.
  - id: ref-30
    source: authored
    domain: D5
    task: D5.4
    scenario: developer-productivity
    stem: >-
      Ninety minutes into mapping an unfamiliar payments codebase, your agent starts describing
      "the typical repository pattern" instead of the specific classes it catalogued earlier, and
      contradicts a conclusion it had reached about the refund path. What should you do?
    options:
      A: Have it write its established findings to a scratchpad file and continue from that file, spawning subagents for any further verbose exploration.
      B: Ask it to re-read the files it has already analysed so the details are fresh again.
      C: Point out the contradiction and ask it to be more careful about referring to specific classes.
      D: Start over in a new session and re-run the whole exploration with a larger token budget.
    correct: A
    explanation: >-
      Generic answers and self-contradiction late in a long session are the signature of a full
      context window, not carelessness - the specifics have been pushed out of it. Persisting
      findings outside the window and delegating further discovery to subagents keeps the
      conclusions durable and stops the main context refilling. B spends the remaining budget
      re-reading and makes the pressure worse. C asks the model to recall what it no longer holds.
      D discards ninety minutes of valid findings that a scratchpad would have preserved.
```

## Anchor coverage

Every task statement in the blueprint syllabus has exactly one anchor, so a generator (or the
`ccaf-check-author` agent) always has an in-objective example to match for style and difficulty.

| Domain | Task statement → anchor |
| ------ | ----------------------- |
| D1     | D1.1 ref-01 · D1.2 ref-18 · D1.3 ref-02 · D1.4 ref-13 · D1.5 ref-22 · D1.6 ref-03 · D1.7 ref-25 |
| D2     | D2.1 ref-14 · D2.2 ref-04 · D2.3 ref-05 · D2.4 ref-23 · D2.5 ref-26 |
| D3     | D3.1 ref-06 · D3.2 ref-08 · D3.3 ref-16 · D3.4 ref-17 · D3.5 ref-27 · D3.6 ref-07 |
| D4     | D4.1 ref-10 · D4.2 ref-28 · D4.3 ref-09 · D4.4 ref-29 · D4.5 ref-20 · D4.6 ref-21 |
| D5     | D5.1 ref-24 · D5.2 ref-15 · D5.3 ref-19 · D5.4 ref-30 · D5.5 ref-12 · D5.6 ref-11 |

**Scenario coverage.** Every slug appears at least three times: `customer-support` (ref-01, ref-04,
ref-13, ref-15, ref-22, ref-24), `code-generation` (ref-06, ref-08, ref-16, ref-27),
`multi-agent-research` (ref-02, ref-11, ref-14, ref-18, ref-19), `developer-productivity` (ref-03,
ref-05, ref-17, ref-23, ref-25, ref-26, ref-30), `claude-code-ci` (ref-07, ref-10, ref-20, ref-21),
`structured-extraction` (ref-09, ref-12, ref-28, ref-29).

Either way, every served item is generated fresh — these 30 never appear in an exam.
