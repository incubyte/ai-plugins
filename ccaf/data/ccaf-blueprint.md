# CCAF Mock Exam — Blueprint

Self-authored, version-controlled blueprint for the **Claude Certified Architect – Foundations
(CCAF)** mock exam. The exam *mechanics* below — question count, domains and weightings, scenario
names, scoring band and pass line, target candidate — are publicly corroborated facts about the
certification, reported consistently by multiple public study resources. Everything else in this
file — the per-domain syllabus, the common-mistake lists, the scenario frames, the case-study
briefs, and the scope lists — is **original material written for this plugin**, drawn from public
Anthropic product documentation and our own production experience building with Claude. It does
not reproduce Anthropic exam material. This is the read-only authority the `ccaf-exam` skill uses
to assemble a mock; it is not shared or modified at runtime.

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

Publicly described as a solution architect with roughly 6+ months hands-on building production
systems with Claude: the Claude API, Agent SDK (multi-agent orchestration, subagent delegation,
tool integration, hooks), Claude Code team configuration, MCP tool/resource design, prompt
engineering for reliable structured output, context-window management, and CI/CD integration.
Questions test **practical tradeoff judgment in production**, not trivia or API-parameter
memorization.

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

The six scenario names are public. The frames below are our own framings of those headline
settings — invented specifics, written for this plugin.

| Slug                     | Scenario                            | Primary domains | Frame (ours) |
| ------------------------ | ----------------------------------- | --------------- | ------------ |
| `customer-support`       | Customer Support Resolution Agent   | D1, D2, D5      | Agent SDK support agent for a subscription-commerce company; MCP tools such as `fetch_account`, `find_order`, `issue_refund`, `handoff_human`; resolve routine tickets end-to-end, hand off the rest safely — refunds move real money. |
| `code-generation`        | Code Generation with Claude Code    | D3, D5          | Platform team adopting Claude Code across services; shared CLAUDE.md, custom slash commands, rules, skills; coaching on plan mode vs direct execution. |
| `multi-agent-research`   | Multi-Agent Research System         | D1, D2, D5      | Coordinator decomposes questions and delegates to search, document-analysis, and synthesis/report subagents to produce cited briefs for analysts. |
| `developer-productivity` | Developer Productivity with Claude  | D2, D3, D1      | Agent SDK tooling that helps engineers explore unfamiliar and legacy codebases and generate boilerplate; built-in tools plus internal MCP servers. |
| `claude-code-ci`         | Claude Code for Continuous Integration | D3, D4       | Claude Code in CI/CD: automated review, test generation, PR feedback; non-interactive runs, machine-parseable output, minimal false positives. |
| `structured-extraction`  | Structured Data Extraction          | D4, D5          | Pipeline extracting schema-validated records from messy documents (invoices, contracts, reports); high accuracy targets, graceful failure, limited human-review capacity. |

## Case-study briefs (copy verbatim into assembled exams)

Each chosen scenario's brief goes into its `[[CASE:<slug>]]` block in the attempt file —
`title:` and `brief:` exactly as written here (each brief is one logical line). The brief is shown
above every screen of that section, and every question in the section must be answerable from the
brief plus its own stem (a question may add detail, but must never contradict the brief).

- `customer-support` — **Customer Support Resolution Agent** — You are the architect of a
  customer-support agent built on the Agent SDK for a subscription-commerce company. The agent
  resolves returns, billing disputes, and account issues through MCP tools including
  `fetch_account`, `find_order`, `issue_refund`, and `handoff_human`. The goal is to resolve
  routine tickets end-to-end and hand the rest to humans safely — refunds move real money, so
  policy enforcement and sound escalation matter as much as speed.
- `code-generation` — **Code Generation with Claude Code** — Your platform team has adopted Claude
  Code for day-to-day code generation, refactoring, debugging, and documentation across several
  services. You own the shared configuration — the CLAUDE.md hierarchy, custom slash commands,
  rules, and skills — and you coach engineers on when to use plan mode versus direct execution.
- `multi-agent-research` — **Multi-Agent Research System** — You operate a research system in
  which a coordinator decomposes questions and delegates to search, document-analysis, and
  synthesis/report subagents to produce cited briefs for analysts. Subagents run with isolated
  context; the coordinator owns routing, error handling, and synthesis quality.
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

## Syllabus (self-authored generation guardrails)

This syllabus is **original to this plugin**: our own enumeration — written from public Anthropic
documentation and production experience — of what a competent candidate should be able to do in
each of the five public domains. Generated questions must test one of these points, be tagged
with the domain shown, and stay strictly inside the in-scope list. Each "common mistakes" list is
our own catalog of practitioner errors; they make natural distractors because real candidates
hold these misconceptions.

### D1 — Agentic Architecture & Orchestration

Be able to:

- **Drive the agentic loop off the API contract.** Send a request; read `stop_reason`.
  `"tool_use"` → execute the requested tools, append the results to conversation history, call
  again; `"end_turn"` → the model is done. Let the model choose tools from well-described
  options; reserve hard-coded sequences for steps that must never vary.
- **Choose the orchestration shape for the job.** A single agent with tools handles bounded
  workflows. A coordinator with specialized subagents (hub-and-spoke) fits work that decomposes
  into separable concerns: the coordinator splits the task, scopes each delegation, aggregates
  results, and owns inter-agent communication and error handling. Match pipeline depth to query
  complexity instead of always running everything.
- **Respect subagent context isolation.** Subagents start fresh — they do not inherit the
  coordinator's conversation, and nothing is shared between invocations. Everything a subagent
  needs (prior findings, source metadata, constraints, quality criteria) must be passed
  explicitly in its prompt, in a structured form that preserves attribution. State goals and
  quality bars, not step-by-step procedures, so subagents can adapt.
- **Decompose to match the problem.** Fixed sequential pipelines suit predictable multi-step
  work; dynamic decomposition — where intermediate findings determine the next delegation —
  suits open-ended investigation. Partition scope so subtopics don't overlap; a decomposition
  that's too narrow silently drops coverage nobody was assigned.
- **Parallelize independent work.** Spawn independent subagents concurrently (multiple spawn
  calls in a single response) and join their results; keep genuinely dependent steps serial.
- **Enforce hard rules in code, not prose.** A programmatic prerequisite gate or hook that blocks
  a sensitive operation until its precondition holds gives a deterministic guarantee; prompt
  instructions and few-shot examples only reduce the failure rate. Hooks can also normalize tool
  results before the model consumes them and intercept policy-violating calls. When a step moves
  money or data irreversibly, prompt-level compliance is not enough.
- **Manage sessions deliberately.** Resume a named session when continuity matters; fork to
  explore alternatives from a shared baseline; when prior state has gone stale (e.g., code
  changed underneath), starting fresh with a written summary beats resuming with outdated tool
  results — and if you do resume, say what changed.

Common mistakes worth testing: deciding loop exit by scanning assistant text or sentinel phrases
instead of `stop_reason`; using an iteration cap as the primary stop condition; assuming
subagents see the parent's history; one mega-agent holding every tool; prompt-only enforcement of
order-sensitive, high-stakes steps; serial execution of independent delegations.

### D2 — Tool Design & MCP Integration

Be able to:

- **Treat tool descriptions as the selection interface.** The model picks tools by their
  descriptions; thin or interchangeable descriptions cause misrouting between similar tools.
  Good descriptions state purpose, input formats, example calls, and boundaries ("use X for …;
  use Y when …"). When two tools are confused, fix the descriptions (or rename/split the tools)
  before adding routing machinery on top.
- **Right-size each agent's toolset.** Selection reliability degrades as the tool catalog grows;
  scope each agent to the few tools its role needs, and expose other capabilities through other
  agents. Prefer purpose-specific, constrained tools over a generic do-anything tool.
- **Use `tool_choice` deliberately.** `"auto"` lets the model answer in text or call tools;
  `"any"` forces some tool call; forced (`{"type": "tool", "name": ...}`) guarantees a specific
  tool runs — useful for mandated first steps and schema-shaped output.
- **Design MCP error returns for recovery.** Use the `isError` flag with structured fields — an
  error category, whether it's retryable, and a human-readable explanation. Distinguish transient
  faults (retry), validation errors (fix input), business/policy rejections (don't retry —
  explain or escalate), and permission failures. A valid-but-empty result is not an error; a
  generic "operation failed" string strands the caller.
- **Configure MCP servers by scope.** Project-scoped config is committed and shared with the
  team; user-scoped config is personal/experimental. Reference secrets through environment
  variable expansion — never literal tokens in committed files. Tools from all connected servers
  are discovered at connection time and available together; MCP resources can expose content
  catalogs so agents browse instead of probing with repeated calls.
- **Use the built-in tools idiomatically.** Content search with Grep, path/name matching with
  Glob, Read before targeted Edit; build understanding incrementally (find entry points, follow
  imports) instead of bulk-reading the codebase.

Common mistakes worth testing: two tools whose descriptions could describe each other; giving
every subagent the full tool catalog; returning empty results or generic strings for failures;
treating a no-match query result as an error (or an access failure as "no results"); secrets
hard-coded in shared MCP config.

### D3 — Claude Code Configuration & Workflows

Be able to:

- **Place memory at the right level.** User-level memory (`~/.claude/`) is personal and never
  ships with the repo; project-level CLAUDE.md is committed and shared; directory-level files
  scope to a subtree. When one person's instructions work and the team's don't, check *where*
  the instructions live (`/memory` shows what's loaded). Keep CLAUDE.md lean with imports and
  split topic rules into `.claude/rules/` files.
- **Use path-scoped rules for cross-cutting conventions.** Rule files with glob `paths:`
  frontmatter load only when matching files are touched — the right tool when a convention
  applies to a file *pattern* scattered across many directories, where per-directory files or
  one monolith would be unmaintainable.
- **Ship team automation through the repo.** Project commands in `.claude/commands/` and skills
  in `.claude/skills/` are version-controlled and arrive with clone/pull; home-directory variants
  stay personal. A skill is an on-demand procedure for a specific task; CLAUDE.md is always-on
  context — put universal standards in CLAUDE.md and occasional multi-step procedures in skills.
- **Pick the working mode by the shape of the change.** Plan mode for multi-file, architectural,
  or ambiguous work — explore and design before committing; direct execution for small,
  well-scoped edits; delegate verbose discovery to a subagent that returns a summary so the main
  context stays clean.
- **Iterate the way the tool works best.** Concrete input/output examples beat prose
  descriptions; write tests first and iterate on failures; batch interacting concerns into one
  message and sequence independent ones.
- **Run Claude Code in CI correctly.** Non-interactive mode (`-p` / `--print`) so jobs don't hang
  waiting for input; structured output (`--output-format json`, with a schema) so the pipeline
  parses fields instead of prose; project context supplied via committed CLAUDE.md; review with a
  fresh instance rather than the session that wrote the code; pass prior findings and existing
  tests so reruns don't duplicate.

Common mistakes worth testing: team instructions trapped in a personal user-level file; one giant
CLAUDE.md doing everything; per-directory copies of a convention that wants a glob rule;
interactive invocation inside CI; the code-writing session reviewing its own output.

### D4 — Prompt Engineering & Structured Output

Be able to:

- **Replace vague quality adjectives with categorical criteria.** "Be conservative" and "only
  high-confidence issues" don't measurably improve precision. Define *which* findings to report
  and which to skip, with concrete examples and explicit severity rules; a high-noise category
  erodes trust in everything else — disable it until its definition is fixed.
- **Use few-shot examples to pin format and judgment.** Two to four targeted examples that
  demonstrate the output shape, show the reasoning for choosing one action over a plausible
  alternative, and cover the input variety you expect — including how to handle the ambiguous
  cases.
- **Guarantee parseable output with tool use + JSON schema.** Schema-enforced tool input
  eliminates JSON syntax errors — but not semantic ones (values that don't sum, content in the
  wrong field). Design schemas defensively: mark fields optional/nullable when the source may
  lack them (a required non-nullable field forces the model to invent a value); use enums with an
  "other"-plus-detail escape hatch; add companion fields that enable self-checks (calculated vs
  stated totals, conflict flags).
- **Build validation feedback loops.** On a validation failure, retry with the specific errors
  included in the prompt. Retries fix format and structure problems; they cannot conjure data the
  source never contained — distinguish the two before retrying.
- **Match the API to the workload.** Batch processing trades latency for cost (roughly half
  price, results within a day, no latency SLA, no multi-turn tool use): right for overnight and
  bulk jobs, wrong for anything a person or a merge is waiting on. Correlate results by
  `custom_id`, resubmit only failures, and pilot the prompt on a sample before the bulk run.
- **Structure review at scale.** An independent instance catches what self-review misses — a
  model reviewing its own output in-session retains its generation reasoning. For large diffs,
  run focused per-file passes plus a separate cross-file integration pass instead of one diluted
  mega-pass; self-reported confidence per finding helps route what humans look at first.

Common mistakes worth testing: required schema fields forcing fabricated values; "don't
hallucinate" as a structural fix; retrying extraction of data that isn't in the document; batch
APIs in blocking workflows; grading your own homework in the same session.

### D5 — Context Management & Reliability

Be able to:

- **Preserve load-bearing facts across long interactions.** Progressive summarization loses
  exactly the things that matter — numbers, dates, identifiers, commitments. Maintain a
  structured facts block (order numbers, amounts, statuses, promises made) that travels with
  every prompt outside any summary; trim verbose tool results to the relevant fields; remember
  that long-context recall favors the beginning and end of the input, so lead with key findings
  under explicit headers.
- **Manage long working sessions.** Persist findings to scratchpad files so they survive context
  boundaries; offload verbose exploration to subagents; summarize each phase before starting the
  next; compact when discovery output dominates the window. Degraded, generic answers late in a
  session are a context problem, not a model mood.
- **Escalate on observable triggers, not proxies.** Escalate when the customer explicitly asks,
  when the case falls outside policy, or when no progress is possible — and encode those triggers
  with examples. Sentiment and model self-reported confidence are unreliable proxies for case
  complexity. On ambiguous identity, ask for more identifiers rather than guessing. A handoff
  should carry a structured summary (who, what happened, evidence, recommended action) for a
  human who hasn't seen the transcript.
- **Propagate errors with enough context to act.** Between agents, a failure report should carry
  the failure type, what was attempted, partial results, and viable alternatives — so the
  coordinator can retry, reroute, or proceed degraded. Recover locally from transient faults;
  never convert a failure into a fake success; never abort the whole run for one failed source;
  carry coverage annotations (what's well-supported vs missing) into the final synthesis.
- **Calibrate confidence against ground truth.** A strong aggregate accuracy can hide systematic
  failure on specific document types or fields. Before auto-accepting "high-confidence" outputs,
  validate accuracy per segment on labeled samples and check that the confidence threshold maps
  to an acceptable error rate (stratified sampling of high-confidence cases); route
  low-confidence and conflicting cases to the limited human reviewers.
- **Keep provenance through synthesis.** Claim–source attribution survives summarization only if
  it's required as structured output (claim, source, excerpt, date) and carried through every
  stage. Conflicting credible sources get an attributed disagreement — with dates, so temporal
  drift isn't mistaken for contradiction — rather than a silent pick.

Common mistakes worth testing: vague summaries that drop figures; sentiment-triggered escalation;
trusting self-reported confidence; "search failed" with no actionable detail; empty-result-as-
success; re-attributing citations after the fact; one uniform output format for every content
type.

## Key concepts & exact identifiers (public product/API surface — use precise names)

- **Agent SDK / agents** — agentic loop; `stop_reason` (`"tool_use"`, `"end_turn"`); hooks
  (post-tool-result transformation, tool-call interception); subagent spawning and `Task`-style
  delegation; tool allowlists; session resume and forking.
- **MCP** — servers, tools, resources; `isError`; structured error fields (category,
  retryable); tool descriptions & distribution; project vs user scope (`.mcp.json` committed vs
  personal config); environment-variable expansion for secrets.
- **Claude Code** — CLAUDE.md hierarchy (user/project/directory) + imports; `.claude/rules/`
  with `paths:` glob frontmatter; `.claude/commands/`; `.claude/skills/` with `SKILL.md`
  frontmatter; plan mode; direct execution; `/memory`; `/compact`; `--resume`.
- **Claude Code CLI** — `-p` / `--print`; `--output-format json`; JSON-schema-constrained output.
- **Claude API** — `tool_use` + JSON schema; `tool_choice` (`"auto"`, `"any"`, forced
  `{"type":"tool","name":"..."}`); `stop_reason`; `max_tokens`; system prompts.
- **Message Batches API** — ~50% cost; results within ~24h; no latency SLA; `custom_id`;
  polling; no multi-turn tool calling.
- **JSON Schema** — required vs optional; nullable; enums; escape-hatch fields; syntax vs
  semantic validation; retry-with-error-feedback loops.
- **Other** — built-in tools (Read/Write/Edit/Bash/Grep/Glob); few-shot prompting; prompt
  chaining; context-window management (summarization pitfalls, serial-position effects,
  scratchpads); confidence calibration and stratified sampling.

## In-scope topics

Agentic loop design; multi-agent orchestration and subagent context; tool interface design; MCP
tool/resource design and server configuration; structured error handling and propagation;
escalation design; Claude Code team configuration (memory, rules, commands, skills); plan mode vs
direct execution; iterative development workflows; CI/CD integration; structured output via tool
use; schema design and validation loops; few-shot prompting; batch vs synchronous workloads;
context-window strategy; human-review workflows and confidence calibration; provenance.

## Out-of-scope topics (this mock does not generate questions on)

Model training or fine-tuning; pricing, billing, or account administration; hosting/deploying MCP
server infrastructure (networking, containers); Claude internals, weights, or safety training;
embeddings and vector-database internals; computer use (browser/desktop automation);
vision/image analysis; streaming/SSE implementation details; rate limits and quota math;
OAuth/key rotation and auth protocols; cloud-provider-specific configuration; model benchmarking
comparisons; prompt-caching internals; tokenization specifics.

## Few-shot anchors (reference-only)

The 12 self-authored questions in `ccaf-question-bank.md` are the style, difficulty, and
explanation-tone anchors — **they are never served in an exam** (the bank is readable by any
candidate, so serving it would inflate scores; the state helper rejects bank questions at write
time). Generated questions should match their shape without reusing their stems or options:
a realistic production scenario, one clearly-correct option, and three distractors that a
candidate with incomplete knowledge might plausibly pick (build distractors from the
common-mistake lists above). Explanations say why the right answer is right **and** why each
distractor is wrong.

## Scoring

- Raw `correct` = count of questions whose recorded answer equals the answer key
  (unanswered = incorrect).
- `scaled = 100 + 15 × correct` (this is `100 + round(correct ÷ 60 × 900)`; since `900 ÷ 60 = 15`
  exactly, no rounding is needed). Range: 0 correct → 100, 60 correct → 1000.
- **Pass iff `scaled ≥ 720`**, i.e. **≥ 42 of 60** correct (42 → 730 PASS; 41 → 715 FAIL).
- Always report a per-domain breakdown (correct / total per D1–D5) and the estimate disclaimer.
