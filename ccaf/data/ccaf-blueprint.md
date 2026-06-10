# CCAF Mock Exam — Blueprint

Distilled, version-controlled encoding of the **Claude Certified Architect – Foundations (CCAF)**
exam guide (Anthropic, PBC; guide v0.1, 2025-02-10). This is the read-only authority the
`/ccaf:mock-exam` command's `ccaf-exam` skill uses to assemble a mock exam. It is **not** shared or
modified at runtime.

The syllabus below is distilled from the public CCAF exam-guide structure — its domains, scenarios,
and scope. The seed questions in `ccaf-question-bank.md` are self-authored. Generated questions
must test the points below and stay strictly inside the in-scope list.

> The official scaled-scoring curve is proprietary and unpublished. This mock approximates it
> transparently (see `## Scoring`). Treat a 720+ here as a readiness signal, not a guarantee.

## Exam shape (replicated exactly)

- **60 questions** per attempt.
- **4 of the 6 scenarios** below, chosen at random per attempt.
- **Case-study framing** — like the real exam, questions are organized around the chosen
  scenarios: the exam is grouped into 4 contiguous case-study sections, each opening with its
  case-study brief (below), and every question is set inside its section's case.
- Each question: single-select, **1 correct option + 3 distractors** (A–D).
- **No penalty for guessing** — an unanswered question scores as incorrect.
- Scaled score reported on the **100–1000** band; **pass = 720**; pass/fail designation.
- Untimed (the real exam is 120 min; this mock does not enforce or report time).

## Target candidate (calibrates difficulty)

A solution architect with ~6+ months hands-on building production systems with Claude: Agent SDK
(multi-agent orchestration, subagent delegation, tool integration, lifecycle hooks), Claude Code
team configuration (CLAUDE.md, skills, MCP servers, plan mode), MCP tool/resource design,
prompt engineering for reliable structured output, context-window management, CI/CD integration,
and sound escalation/reliability judgment. Questions test **practical tradeoff judgment in
production**, not trivia or API-parameter memorization.

## Domains and weightings

The 60 questions are distributed by these weights (rounded to sum exactly 60):

| Code | Domain                                     | Weight | Questions / 60 |
| ---- | ------------------------------------------ | ------ | -------------- |
| D1   | Agentic Architecture & Orchestration       | 27%    | 16             |
| D2   | Tool Design & MCP Integration              | 18%    | 11             |
| D3   | Claude Code Configuration & Workflows      | 20%    | 12             |
| D4   | Prompt Engineering & Structured Output     | 20%    | 12             |
| D5   | Context Management & Reliability           | 15%    | 9              |

`16 + 11 + 12 + 12 + 9 = 60`.

## Scenarios (4 of 6 per attempt)

Each question is framed inside a scenario. Pick 4 at random per attempt.

| Slug                     | Scenario                            | Primary domains | Frame |
| ------------------------ | ----------------------------------- | --------------- | ----- |
| `customer-support`       | Customer Support Resolution Agent   | D1, D2, D5      | Agent SDK agent handling returns/billing/account issues via MCP tools (get_customer, lookup_order, process_refund, escalate_to_human); target 80%+ first-contact resolution with sound escalation. |
| `code-generation`        | Code Generation with Claude Code    | D3, D5          | Team using Claude Code for generation/refactor/debug/docs; custom slash commands, CLAUDE.md config, plan mode vs direct. |
| `multi-agent-research`   | Multi-Agent Research System         | D1, D2, D5      | Coordinator delegates to web-search, document-analysis, synthesis, and report subagents to produce cited reports. |
| `developer-productivity` | Developer Productivity with Claude  | D2, D3, D1      | Agent SDK tools to explore unfamiliar codebases, understand legacy systems, generate boilerplate; built-in tools + MCP servers. |
| `claude-code-ci`         | Claude Code for Continuous Integration | D3, D4       | Claude Code in CI/CD: automated reviews, test generation, PR feedback; actionable feedback, minimize false positives. |
| `structured-extraction`  | Structured Data Extraction          | D4, D5          | Extract from unstructured docs, validate with JSON schemas, high accuracy, graceful edge-case handling, downstream integration. |

## Case-study briefs (copy verbatim into assembled exams)

Each chosen scenario's brief goes into its `[[CASE:<slug>]]` block in the attempt file —
`title:` and `brief:` exactly as written here (each brief is one logical line). The brief is shown
above every screen of that section, and every question in the section must be answerable from the
brief plus its own stem (a question may add detail, but must never contradict the brief).

- `customer-support` — **Customer Support Resolution Agent** — You are the architect of a
  customer-support agent built on the Agent SDK for a consumer subscription company. The agent
  resolves returns, billing disputes, and account issues through MCP tools including
  `get_customer`, `lookup_order`, `process_refund`, and `escalate_to_human`. Leadership targets 80%+ first-contact
  resolution, but refunds move real money, so policy enforcement and sound escalation matter as
  much as speed.
- `code-generation` — **Code Generation with Claude Code** — Your platform team has adopted Claude
  Code for day-to-day code generation, refactoring, debugging, and documentation across several
  services. You own the shared configuration — the CLAUDE.md hierarchy, custom slash commands,
  rules, and skills — and you coach engineers on when to use plan mode versus direct execution.
- `multi-agent-research` — **Multi-Agent Research System** — You operate a research system in
  which a coordinator decomposes questions and delegates to web-search, document-analysis,
  synthesis, and report-writing subagents to produce cited reports for analysts. Subagents run
  with isolated context; the coordinator owns routing, error handling, and synthesis quality.
- `developer-productivity` — **Developer Productivity with Claude** — Your team builds Agent SDK
  tooling that helps engineers explore unfamiliar codebases, understand legacy systems, and
  generate boilerplate. Agents combine built-in tools (Grep, Glob, Read, Edit) with MCP servers
  for internal systems, and you tune tool scope and descriptions to keep each agent reliable.
- `claude-code-ci` — **Claude Code for Continuous Integration** — You are wiring Claude Code into
  CI/CD: automated review on pull requests, test generation, and PR feedback. Runs are
  non-interactive, output must be machine-parseable, and the team demands actionable findings
  with minimal false positives.
- `structured-extraction` — **Structured Data Extraction** — You are building a pipeline that
  extracts structured records from unstructured documents (invoices, contracts, reports),
  validates them against JSON schemas, and feeds downstream systems. Accuracy targets are high,
  edge cases must fail gracefully rather than fabricate, and human review capacity is limited.

---

## Full syllabus (generation guardrails — paraphrased)

Generated questions must test one of these points and be tagged with the domain shown. Each point
is something the candidate must **know** or be **able to do**. Anti-patterns are flagged because
the real exam's distractors are built from them.

### D1 — Agentic Architecture & Orchestration

- **D1.1 Agentic loops.** The loop lifecycle: send a request, inspect `stop_reason`
  (`"tool_use"` → execute the requested tools and iterate; `"end_turn"` → finish). Tool results
  are appended to conversation history so the model reasons about the next action. Model-driven
  tool choice vs hard-coded decision trees / fixed tool sequences. Anti-patterns (good distractor
  fodder): parsing natural-language signals to decide termination; using an arbitrary iteration
  cap as the primary stop condition; treating the presence of assistant text as "done."
- **D1.2 Coordinator–subagent orchestration.** Hub-and-spoke: the coordinator owns all
  inter-subagent communication, error handling, and routing. Subagents run with **isolated
  context** — they do not inherit the coordinator's history. The coordinator decomposes,
  delegates, aggregates, and decides which subagents to invoke based on query complexity (don't
  always run the full pipeline). Risk: too-narrow decomposition → incomplete coverage of broad
  topics. Partition scope across subagents to avoid duplication; run an iterative-refinement loop
  (evaluate synthesis for gaps → re-delegate targeted queries → re-synthesize). Route all comms
  through the coordinator for observability and consistent error handling.
- **D1.3 Subagent invocation, context passing, spawning.** The `Task` tool spawns subagents and
  `allowedTools` must include `"Task"`. Context must be provided **explicitly** in the subagent's
  prompt — no automatic inheritance or shared memory across invocations. `AgentDefinition`
  configures each subagent's description, system prompt, and tool restrictions. `fork_session`
  explores divergent approaches from a shared baseline. Pass prior agents' complete findings
  directly in the prompt; use structured formats to separate content from metadata (source URLs,
  doc names, page numbers) to preserve attribution. Spawn parallel subagents by emitting multiple
  `Task` calls in a single response. Coordinator prompts should state goals and quality criteria,
  not step-by-step procedures (enables subagent adaptability).
- **D1.4 Multi-step workflows: enforcement & handoff.** Programmatic enforcement (hooks,
  prerequisite gates) vs prompt-based ordering. When deterministic compliance is required (e.g.
  verify identity before a financial operation), prompt instructions alone have a non-zero failure
  rate — use a programmatic prerequisite that blocks downstream tools until earlier steps complete
  (block `process_refund` until `get_customer` returns a verified ID). Decompose multi-concern
  requests, investigate each in parallel against shared context, then synthesize one resolution.
  On mid-process escalation, compile a structured handoff summary (customer ID, root cause, refund
  amount, recommended action) for a human who lacks the transcript.
- **D1.5 Agent SDK hooks.** `PostToolUse` hooks intercept and transform tool results before the
  model processes them (e.g. normalize heterogeneous formats — Unix timestamps, ISO 8601, numeric
  status codes). Tool-call interception hooks block policy-violating actions (e.g. refunds over a
  threshold) and redirect to an alternative workflow. Hooks give **deterministic** guarantees;
  prompts give only probabilistic compliance — choose hooks when business rules must hold.
- **D1.6 Task decomposition strategies.** Fixed sequential pipelines (prompt chaining) vs dynamic
  adaptive decomposition driven by intermediate findings. Chaining suits predictable multi-aspect
  reviews (analyze each file, then a cross-file integration pass). Dynamic decomposition suits
  open-ended investigation (map structure → identify high-impact areas → prioritized plan that
  adapts as dependencies surface).
- **D1.7 Session state, resumption, forking.** `--resume <session-name>` continues a named prior
  session. `fork_session` creates independent branches from a shared analysis baseline. When
  resuming after code changes, inform the agent which files changed (targeted re-analysis).
  Starting fresh with a structured summary is often more reliable than resuming with stale tool
  results.

### D2 — Tool Design & MCP Integration

- **D2.1 Tool interfaces & descriptions.** Tool descriptions are the **primary** mechanism the LLM
  uses to select a tool; minimal descriptions cause unreliable selection among similar tools.
  Include input formats, example queries, edge cases, and when-to-use-vs-alternatives. Ambiguous or
  overlapping descriptions cause misrouting (`analyze_content` vs `analyze_document`). System-prompt
  wording can create unintended tool associations. Fixes: rewrite descriptions to differentiate;
  rename to remove overlap; split a generic tool into purpose-specific tools with defined I/O
  contracts.
- **D2.2 Structured error responses.** Use the MCP `isError` flag. Distinguish transient
  (timeout/unavailable), validation (bad input), business (policy), and permission errors. Generic
  "Operation failed" prevents recovery decisions. Return structured metadata: `errorCategory`,
  `isRetryable`, human-readable description; `retriable: false` + customer-friendly explanation for
  business violations. Subagents recover locally from transient failures and propagate only what
  they cannot resolve, with partial results and what was attempted. Distinguish an access failure
  (needs a retry decision) from a valid empty result (a successful query with no matches).
- **D2.3 Tool distribution & `tool_choice`.** Too many tools (e.g. 18 vs 4–5) degrades selection
  reliability; agents misuse tools outside their specialization. Scope each agent's tools to its
  role, with limited cross-role tools for high-frequency needs. Replace generic tools with
  constrained ones (`fetch_url` → `load_document` that validates URLs). `tool_choice`: `"auto"`
  (may return text), `"any"` (must call some tool), forced (`{"type":"tool","name":"..."}`). Use
  forced selection to guarantee a specific tool runs first; `"any"` to guarantee a tool call rather
  than conversational text.
- **D2.4 MCP server integration.** Project scope (`.mcp.json`, shared) vs user scope
  (`~/.claude.json`, personal/experimental). Env-var expansion (`${GITHUB_TOKEN}`) keeps secrets
  out of committed config. Tools from all configured servers are discovered at connection time and
  available simultaneously. MCP **resources** expose content catalogs (issue summaries, doc
  hierarchies, DB schemas) to reduce exploratory tool calls. Enhance MCP tool descriptions so the
  agent prefers them over built-ins like Grep. Prefer community MCP servers for standard
  integrations (e.g. Jira); reserve custom servers for team-specific workflows.
- **D2.5 Built-in tools.** `Grep` for content search; `Glob` for path/name patterns; `Read`/`Write`
  for full files; `Edit` for targeted unique-match changes (fall back to Read+Write when the anchor
  text isn't unique). Build understanding incrementally — Grep entry points, then Read to follow
  imports and trace flows — rather than reading everything upfront. Trace usage across wrapper
  modules by finding all exported names, then searching each.

### D3 — Claude Code Configuration & Workflows

- **D3.1 CLAUDE.md hierarchy.** User-level (`~/.claude/CLAUDE.md`, **not** shared via VCS),
  project-level (`.claude/CLAUDE.md` or root), directory-level (subdir CLAUDE.md). `@import` keeps
  files modular. `.claude/rules/` holds topic-specific rule files instead of one monolith. Diagnose
  hierarchy issues (a teammate missing instructions because they're in user-level config). Use
  `/memory` to verify which memory files are loaded.
- **D3.2 Custom commands & skills.** Project commands in `.claude/commands/` (shared via VCS) vs
  user commands in `~/.claude/commands/` (personal). Skills in `.claude/skills/` with `SKILL.md`
  frontmatter: `context: fork` (run in an isolated sub-agent context so verbose/exploratory output
  doesn't pollute the main conversation), `allowed-tools` (restrict tool access during the skill),
  `argument-hint`. Personal skill variants live in `~/.claude/skills/`. Choose skills (on-demand,
  task-specific) vs CLAUDE.md (always-loaded universal standards).
- **D3.3 Path-specific rules.** `.claude/rules/` files with YAML `paths:` glob frontmatter load
  only when editing matching files (less irrelevant context, fewer tokens). Glob rules beat
  directory-level CLAUDE.md for conventions spanning many directories (e.g. `**/*.test.tsx` for
  test files scattered through the codebase).
- **D3.4 Plan mode vs direct execution.** Plan mode for complex/large-scale change, multiple valid
  approaches, architectural decisions, multi-file edits — it enables safe exploration before
  committing and prevents costly rework. Direct execution for simple, well-scoped changes. The
  `Explore` subagent isolates verbose discovery and returns summaries to preserve main-conversation
  context. Combine plan-mode investigation with direct-execution implementation.
- **D3.5 Iterative refinement.** Concrete input/output examples communicate transformations better
  than prose. Test-driven iteration: write tests first, then iterate by sharing failures. The
  interview pattern: have Claude ask questions to surface considerations before implementing. Send
  all issues in one message when they interact; iterate sequentially when independent.
- **D3.6 CI/CD integration.** `-p` / `--print` runs Claude Code non-interactively (no input hang).
  `--output-format json` + `--json-schema` produce machine-parseable findings for inline PR
  comments. CLAUDE.md supplies project context (testing standards, fixtures, review criteria) to
  CI-invoked Claude. Session isolation: the session that generated code is less effective at
  reviewing it than an independent instance. Include prior review findings to avoid duplicate
  comments; provide existing tests so generation doesn't duplicate coverage.

### D4 — Prompt Engineering & Structured Output

- **D4.1 Explicit criteria for precision.** Explicit categorical criteria beat vague instructions
  ("flag a comment only when claimed behavior contradicts actual code" vs "check comments are
  accurate"). "Be conservative" / "only high-confidence" don't actually improve precision. High
  false-positive categories erode trust in the accurate ones. Define which issues to report vs skip;
  temporarily disable a high-FP category while you improve it; give explicit severity criteria with
  concrete code examples.
- **D4.2 Few-shot prompting.** The most effective lever for consistently formatted, actionable
  output when instructions alone are inconsistent. Demonstrate ambiguous-case handling; enable
  generalization to novel patterns; reduce extraction hallucination. Use 2–4 targeted examples that
  show the reasoning for choosing one action over plausible alternatives; demonstrate the desired
  output shape; distinguish acceptable patterns from genuine issues; cover varied document
  structures.
- **D4.3 Structured output via `tool_use`.** `tool_use` + JSON schema is the most reliable way to
  guarantee schema-compliant output (eliminates JSON syntax errors). `tool_choice`: `"auto"` (may
  return text), `"any"` (must call a tool, model picks), forced (a specific named tool). Strict
  schemas kill **syntax** errors but not **semantic** ones (line items not summing, wrong-field
  placement). Design required vs optional fields, enums with an `"other"` + detail escape hatch, and
  **nullable** fields so the model returns null instead of fabricating to satisfy a required field.
  Add format-normalization rules in the prompt alongside the strict schema.
- **D4.4 Validation, retry, feedback loops.** Retry-with-error-feedback: append the specific
  validation errors on retry. Retries are useless when the info is simply **absent** from the source
  (vs format/structural errors, which retries fix). Track a `detected_pattern` field to analyze
  false-positive dismissals. Distinguish semantic validation errors from syntax errors (the latter
  eliminated by tool use). Self-correction flows: extract `calculated_total` alongside
  `stated_total` to flag discrepancies; add `conflict_detected` booleans for inconsistent sources.
- **D4.5 Batch processing.** The Message Batches API: ~50% cost savings, up to a 24-hour window,
  **no latency SLA**. Right for non-blocking, latency-tolerant workloads (overnight reports, weekly
  audits, nightly test generation); wrong for blocking workflows (pre-merge checks). It does **not**
  support multi-turn tool calling within a single request. `custom_id` correlates request/response
  pairs. Match the API to the workload; compute submission frequency from SLA constraints; resubmit
  only failed docs by `custom_id` (chunk oversized ones); prompt-refine on a sample before bulk.
- **D4.6 Multi-instance & multi-pass review.** Self-review is limited — a model retains its
  generation reasoning and is less likely to question its own decisions in the same session.
  Independent review instances (no prior reasoning context) catch more than self-review or extended
  thinking. Multi-pass review (per-file local passes + a cross-file integration pass) avoids
  attention dilution and contradictory findings. Have the model self-report confidence per finding
  for calibrated review routing.

### D5 — Context Management & Reliability

- **D5.1 Preserving conversation context.** Progressive-summarization risk: vague summaries lose
  numbers, percentages, dates, and customer-stated expectations. "Lost in the middle": models
  reliably use the beginning and end of long inputs but may drop the middle. Tool results accumulate
  tokens disproportionately to relevance (40+ fields when 5 matter). Pass complete history for
  coherence. Techniques: extract a persistent "case-facts" block (amounts, dates, order numbers,
  statuses) included in each prompt outside the summary; trim verbose tool outputs to relevant
  fields; put key findings at the start with explicit section headers; have subagents return
  structured data (key facts, citations, relevance) instead of verbose reasoning when downstream
  budgets are tight.
- **D5.2 Escalation & ambiguity resolution.** Appropriate triggers: explicit human request, policy
  gaps/exceptions (not merely "complex"), and inability to make progress. Escalate immediately on an
  explicit demand; otherwise offer to resolve when it's straightforward. Sentiment and self-reported
  confidence are **unreliable** proxies for case complexity. Multiple customer matches → ask for
  more identifiers rather than guess. Add explicit escalation criteria with few-shot examples;
  acknowledge frustration while offering resolution when capable, escalating only if the customer
  reiterates.
- **D5.3 Error propagation across agents.** Structured error context (failure type, attempted query,
  partial results, alternatives) lets the coordinator recover intelligently. Distinguish access
  failures (need a retry decision) from valid empty results. Generic statuses ("search unavailable")
  hide context. Anti-patterns: silently suppressing errors (returning empty as success) and
  terminating the whole workflow on a single failure. Subagents recover locally for transient issues
  and propagate only the unresolved, with partial results; synthesis output carries coverage
  annotations (well-supported vs gaps from unavailable sources).
- **D5.4 Large-codebase context.** Long sessions degrade — the model gives inconsistent answers and
  cites "typical patterns" instead of the specific classes found earlier. Use scratchpad files to
  persist key findings across context boundaries; delegate verbose exploration to subagents while
  the main agent coordinates; export structured agent state/manifests for crash recovery; summarize
  a phase's findings before spawning the next phase's subagents; use `/compact` when context fills
  with discovery output.
- **D5.5 Human review & confidence calibration.** Aggregate accuracy (e.g. 97%) can mask poor
  performance on specific document types or fields. Use stratified random sampling of
  high-confidence extractions to measure error rates and spot novel patterns. Calibrate field-level
  confidence scores against labeled validation sets. Validate accuracy by document type and field
  before automating high-confidence extractions; route low-confidence or
  ambiguous/contradictory cases to human review to prioritize limited reviewer capacity.
- **D5.6 Provenance & uncertainty in multi-source synthesis.** Source attribution is lost during
  summarization unless claim-source mappings are preserved. Require structured claim-source mappings
  (source URLs, doc names, excerpts) that downstream agents carry through synthesis. Handle
  conflicting statistics from credible sources by annotating the conflict with attribution rather
  than arbitrarily picking one. Require publication/collection dates so temporal differences aren't
  misread as contradictions. Render content types appropriately (financial → tables, news → prose,
  technical → structured lists) instead of forcing one uniform format.

## Key concepts & exact identifiers (use precise names in questions)

- **Agent SDK** — `AgentDefinition`; agentic loop; `stop_reason` (`"tool_use"`, `"end_turn"`);
  hooks (`PostToolUse`, tool-call interception); subagent spawning via the `Task` tool;
  `allowedTools` (must include `"Task"` to spawn); `fork_session`.
- **MCP** — servers, tools, resources; `isError`; `errorCategory`, `isRetryable`/`retriable`; tool
  descriptions & distribution; `.mcp.json` (project) vs `~/.claude.json` (user); env-var expansion.
- **Claude Code** — CLAUDE.md hierarchy (user/project/dir) + `@import`; `.claude/rules/` with
  `paths:` glob frontmatter; `.claude/commands/`; `.claude/skills/` `SKILL.md` (`context: fork`,
  `allowed-tools`, `argument-hint`); plan mode; direct execution; `/memory`; `/compact`;
  `--resume`; the `Explore` subagent.
- **Claude Code CLI** — `-p` / `--print`; `--output-format json`; `--json-schema`.
- **Claude API** — `tool_use` + JSON schema; `tool_choice` (`"auto"`, `"any"`, forced
  `{"type":"tool","name":"..."}`); `stop_reason`; `max_tokens`; system prompts.
- **Message Batches API** — ~50% cost; ≤24h window; no SLA; `custom_id`; polling; no multi-turn
  tool calling.
- **JSON Schema / Pydantic** — required vs optional; enums; nullable; `"other"` + detail; strict
  mode (syntax not semantics); validation-retry loops; semantic vs syntax errors.
- **Other** — built-in tools (Read/Write/Edit/Bash/Grep/Glob); few-shot prompting; prompt chaining;
  context-window management (progressive summarization, lost-in-the-middle, scratchpads);
  confidence scoring (field-level, calibration, stratified sampling).

## In-scope topics

Agentic loop implementation; multi-agent orchestration; subagent context management; tool
interface design; MCP tool/resource design; MCP server config; structured error handling &
propagation; escalation decision-making; CLAUDE.md config; custom commands & skills; plan mode
vs direct execution; iterative refinement; structured output via `tool_use`; few-shot prompting;
batch processing; context-window optimization; human review workflows; information provenance.

## Out-of-scope topics (never generate questions on these)

Fine-tuning / training custom models; API auth / billing / account management; deep
language/framework implementation beyond tool & schema config; deploying/hosting MCP servers
(infra, networking, containers); Claude internals / training / weights; Constitutional AI / RLHF
/ safety training; embeddings / vector DB internals; computer use (browser/desktop);
vision/image analysis; streaming / SSE implementation; rate limits / quotas / pricing math;
OAuth / key rotation / auth protocols; specific cloud-provider configs; benchmarking / model
comparison; prompt-caching internals (beyond "it exists"); tokenization specifics.

## Few-shot anchors (reference-only)

The 12 self-authored questions in `ccaf-question-bank.md` are the style, difficulty, and
explanation-tone anchors — **they are never served in an exam** (the bank is readable by any
candidate, so serving it would inflate scores; the state helper rejects bank questions at write
time). Generated questions should match their shape without reusing their stems or options:
a realistic production scenario, one clearly-correct option, and three distractors that a
candidate with incomplete knowledge might plausibly pick (build distractors from the anti-patterns
flagged in the syllabus above). Explanations say why the right answer is right **and** why each
distractor is wrong.

## Scoring

- Raw `correct` = count of questions whose recorded answer equals the answer key
  (unanswered = incorrect).
- `scaled = 100 + 15 × correct` (this is `100 + round(correct ÷ 60 × 900)`; since `900 ÷ 60 = 15`
  exactly, no rounding is needed). Range: 0 correct → 100, 60 correct → 1000.
- **Pass iff `scaled ≥ 720`**, i.e. **≥ 42 of 60** correct (42 → 730 PASS; 41 → 715 FAIL).
- Always report a per-domain breakdown (correct / total per D1–D5) and the estimate disclaimer.
