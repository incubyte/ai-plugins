# CCAF Mock Exam — Blueprint

Self-authored, version-controlled blueprint for the **Claude Certified Architect – Foundations
(CCAF)** mock exam, aligned to the published exam guide (**v1.0, effective July 2026, exam code
`CCAR-F`**). The exam *mechanics* below — question count, item formats, domains and weightings,
scenario set, the 30-objective index, scoring band and pass line, target candidate — are the
certification's published facts. Everything else in this file is **original material written for
this plugin**: every task-statement description, every common-mistake list, every scenario frame
and case-study brief, and both scope lists are our own prose, drawn from public Anthropic product
documentation and our own production experience building with Claude. No sentence of Anthropic's
exam guide is reproduced here, and no exam item is reproduced. This is the read-only authority the
`ccaf-exam` and `ccaf-practice` skills use to assemble a mock; it is not shared or modified at
runtime.

> The official scaled-scoring curve is proprietary and unpublished. This mock approximates it
> transparently (see `## Scoring`). Treat a 720+ here as a readiness signal, not a guarantee.

## Exam shape (replicated)

- **60 items** per attempt.
- **4 of the 6 scenarios** below, chosen at random per attempt.
- **Case-study framing** — like the real exam, items are organized around the chosen scenarios:
  the exam is grouped into 4 contiguous case-study sections, each opening with its case-study
  brief (below), and every item is set inside its section's case.
- **Single-answer multiple-choice items only** — four options A–D, exactly one correct. This is a
  **deliberate divergence** from the real exam; see the note below.
- **No penalty for guessing** — an unanswered item scores as incorrect.
- Scaled score reported on the **100–1000** band; **pass = 720**; pass/fail designation, plus
  **percent correct per domain** on the report (informational — the pass/fail decision is the
  total scaled score alone).
- Untimed (the real exam allows 120 min; this mock does not enforce or report time).

The real exam is **criterion-referenced**: a candidate is measured against a fixed performance
standard set by a formal standard-setting study, not graded on a curve against other candidates.
Scaled scoring exists to equate forms of slightly different difficulty. Say so when explaining the
score — it is why 720 is a fixed bar and why "how did others do" is not a meaningful question.

## Item composition (what an assembled 60-item mock contains)

All **60 items are single-answer multiple-choice**: four options A–D, **exactly one is correct**,
the other three are plausible-but-wrong distractors. Guess rate 1 in 4. No item asks for more than
one response, so no item states a response count.

### Deliberate divergence from the real exam

The published guide gives the item format as *multiple-choice **and** multiple-response, with each
item stating how many responses to select*. **This mock serves single-answer items only.** That is a
decision taken for this plugin, not an oversight, and it has consequences worth naming:

- A candidate practising here **will not rehearse the multiple-response format**, which on the real
  exam is scored all-or-nothing — one right and one wrong scores the same as zero right. That is a
  distinct skill: classify every option rather than stop at the first strong one.
- Because single-answer items are the easier format, a score here is, if anything, **optimistic**
  relative to a real form containing multiple-response items. Treat 720 as the floor of readiness,
  not a comfortable margin.
- The README's fidelity table states this divergence plainly. Do not describe the mock as matching
  the guide's item format, and do not generate an item that asks for two or three responses — the
  state helper refuses any answer key that is not a single letter.

Everything else in this blueprint follows the published guide.

## Target candidate (calibrates difficulty)

A solution architect who designs and ships production applications with Claude, with roughly 6+
months of hands-on experience across:

- building agentic applications on the **Claude Agent SDK** — multi-agent orchestration, subagent
  delegation, tool integration, and lifecycle hooks;
- configuring **Claude Code** for team workflows — CLAUDE.md hierarchies, Agent Skills, MCP server
  integration, plan mode;
- designing **MCP** tool and resource interfaces that front backend systems;
- engineering prompts for reliable structured output — JSON schemas, few-shot examples, extraction
  patterns;
- managing context windows across long documents, multi-turn conversations, and multi-agent
  handoffs;
- integrating Claude into **CI/CD** for automated review, test generation, and PR feedback;
- making sound escalation and reliability calls — error handling, human-in-the-loop workflows,
  self-evaluation patterns.

They understand both the capabilities and the limits of large language models in production.
Items test **practical tradeoff judgment in production**, not trivia or API-parameter
memorization.

## Domains and weightings

The 60 items are distributed by these weights (rounded to sum exactly 60):

| Code | Domain                                     | Weight | Items / 60 |
| ---- | ------------------------------------------ | ------ | ---------- |
| D1   | Agentic Architecture & Orchestration       | 27%    | 16         |
| D2   | Tool Design & MCP Integration              | 18%    | 11         |
| D3   | Claude Code Configuration & Workflows      | 20%    | 12         |
| D4   | Prompt Engineering & Structured Output     | 20%    | 12         |
| D5   | Context Management & Reliability           | 15%    | 9          |

`16 + 11 + 12 + 12 + 9 = 60`.

## Scenarios (4 of 6 per attempt)

The six scenario settings are public, as are the backend tool names and targets they specify. The
frames below are our own framings of those settings — our prose, written for this plugin.

| Slug                     | Scenario                            | Primary domains | Frame (ours) |
| ------------------------ | ----------------------------------- | --------------- | ------------ |
| `customer-support`       | Customer Support Resolution Agent   | D1, D2, D5      | Agent SDK support agent handling returns, billing disputes, and account issues via MCP tools `get_customer`, `lookup_order`, `process_refund`, `escalate_to_human`; target 80%+ first-contact resolution — refunds move real money. |
| `code-generation`        | Code Generation with Claude Code    | D3, D5          | Team using Claude Code daily for generation, refactoring, debugging, docs; shared CLAUDE.md hierarchy, custom slash commands, path rules, skills; coaching on plan mode vs direct execution. |
| `multi-agent-research`   | Multi-Agent Research System         | D1, D2, D5      | Coordinator delegating to four subagents — web search, document analysis, synthesis, report generation — to produce comprehensive cited reports. |
| `developer-productivity` | Developer Productivity with Claude  | D2, D3, D1      | Agent SDK tooling for exploring unfamiliar codebases, understanding legacy systems, generating boilerplate, automating repetitive work; built-in tools (Read, Write, Bash, Grep, Glob) plus internal MCP servers. |
| `claude-code-ci`         | Claude Code for Continuous Integration | D3, D4       | Claude Code in CI/CD: automated review, test generation, PR feedback; non-interactive runs, machine-parseable output, actionable findings with minimal false positives. |
| `structured-extraction`  | Structured Data Extraction          | D4, D5          | Pipeline extracting records from unstructured documents (invoices, contracts, reports), validating against JSON schemas, feeding downstream systems; high accuracy, graceful edge-case failure, limited human review. |

## Case-study briefs (copy verbatim into assembled exams)

Each chosen scenario's brief goes into its `[[CASE:<slug>]]` block in the attempt file —
`title:` and `brief:` exactly as written here (each brief is one logical line). The brief is shown
above every screen of that section, and every item in the section must be answerable from the
brief plus its own stem (an item may add detail, but must never contradict the brief).

- `customer-support` — **Customer Support Resolution Agent** — You architect a customer-support
  resolution agent built on the Claude Agent SDK. It handles high-ambiguity requests — returns,
  billing disputes, account problems — through MCP tools that reach your backend systems:
  `get_customer`, `lookup_order`, `process_refund`, and `escalate_to_human`. You are targeting
  80%+ first-contact resolution while still recognising the cases that belong with a human;
  refunds move real money, so policy enforcement and sound escalation weigh as heavily as speed.
- `code-generation` — **Code Generation with Claude Code** — Your team uses Claude Code every day
  for code generation, refactoring, debugging, and documentation. You own how it fits the
  development workflow — the CLAUDE.md hierarchy, custom slash commands, path-scoped rules, and
  skills — and you coach engineers on when plan mode earns its cost and when to go straight to
  direct execution.
- `multi-agent-research` — **Multi-Agent Research System** — You operate a research system built on
  the Claude Agent SDK in which a coordinator delegates to four specialised subagents: one
  searches the web, one analyses documents, one synthesises findings, and one generates the
  report. The system investigates topics and produces comprehensive, cited reports; subagents run
  with isolated context, and the coordinator owns routing, error handling, and synthesis quality.
- `developer-productivity` — **Developer Productivity with Claude** — You build
  developer-productivity tooling on the Claude Agent SDK: agents that help engineers explore
  unfamiliar codebases, make sense of legacy systems, generate boilerplate, and automate
  repetitive work. They combine the built-in tools (Read, Write, Bash, Grep, Glob) with MCP
  servers that reach internal systems, and you tune each agent's tool scope and descriptions to
  keep it reliable.
- `claude-code-ci` — **Claude Code for Continuous Integration** — You are wiring Claude Code into
  your CI/CD pipeline: automated code review on pull requests, generated test cases, and feedback
  posted back to the PR. Runs are non-interactive, output has to be machine-parseable, and the
  team expects findings actionable enough — with few enough false positives — that developers keep
  trusting them.
- `structured-extraction` — **Structured Data Extraction** — You are building a system that
  extracts structured records out of unstructured documents (invoices, contracts, reports),
  validates them against JSON schemas, and feeds downstream systems. Accuracy targets are high,
  edge cases must fail gracefully rather than fabricate, and human review capacity is limited.

---

## Syllabus — 30 task statements (self-authored generation guardrails)

The exam's objectives are indexed as **30 task statements** across the five domains — D1.1–D1.7,
D2.1–D2.5, D3.1–D3.6, D4.1–D4.6, D5.1–D5.6 — and items are written against them. The **numbering
and the competency each code covers are the published index**, so a candidate can cross-reference;
every word of description below is **ours**: our own enumeration of what a competent candidate
must be able to do, written from public Anthropic documentation and production experience.

Generated items must **test one task statement**, be tagged with its code and domain, and stay
strictly inside the in-scope list. Each domain's "common mistakes" list is our own catalog of
practitioner errors; they make natural distractors because real candidates hold these
misconceptions.

### D1 — Agentic Architecture & Orchestration (27% · 16 items)

**D1.1 — Drive the agentic loop from the API's `stop_reason` contract.**
Send a request and read `stop_reason`: `"tool_use"` → execute the requested tools, append their
results to conversation history, call again; `"end_turn"` → the model is done. Let the model choose
tools from well-described options rather than pre-configuring a decision tree, and reserve
hard-coded sequences for steps that must never vary.

**D1.2 — Orchestrate a coordinator over specialized subagents.**
Hub-and-spoke: the coordinator decomposes the task, decides which subagents a given query actually
needs, aggregates their results, and owns all inter-subagent communication so error handling and
observability sit in one place. Match pipeline depth to query complexity instead of always running
the full chain. Partition scope so subtopics don't overlap — and remember a decomposition that is
too narrow silently drops coverage nobody was assigned. Where synthesis reveals gaps, loop: re-scope
the search and analysis delegations and re-synthesize until coverage holds.

**D1.3 — Configure subagent invocation, context passing, and spawning.**
Subagents are spawned through the **`Task` tool**, so a coordinator's `allowedTools` must include
`"Task"` or it cannot delegate at all. Subagents start fresh — they inherit no conversation history
and share no memory between invocations — so everything one needs (prior findings, source metadata,
constraints, quality bars) must be passed explicitly in its prompt, structured so content stays
separable from metadata and attribution survives. Define each subagent type with an
**`AgentDefinition`**: description, system prompt, tool restrictions. Spawn independent subagents
concurrently by emitting **multiple `Task` calls in a single coordinator response**, not across
separate turns. State goals and quality criteria rather than step-by-step procedures, so subagents
can adapt.

**D1.4 — Enforce multi-step workflow order in code, and hand off cleanly.**
A programmatic prerequisite gate or hook that blocks a sensitive operation until its precondition
holds gives a deterministic guarantee; prompt instructions and few-shot examples only lower the
failure rate. When identity must be verified before money moves, prompt-level compliance is not
enough — block `process_refund` until `get_customer` has returned a verified customer ID. Decompose
a multi-concern request into distinct items, investigate them in parallel against shared context,
then synthesize one unified resolution. An escalation carries a **structured handoff summary** —
customer ID, root cause, amount, recommended action — because the human receiving it has not seen
the transcript.

**D1.5 — Apply Agent SDK hooks for interception and normalization.**
A **`PostToolUse`** hook intercepts tool results before the model sees them — the place to normalize
heterogeneous formats (Unix epochs, ISO 8601, numeric status codes) coming back from different MCP
tools. A hook on outgoing tool calls intercepts and blocks policy-violating actions (a refund over
the approval threshold) and redirects them to an alternative workflow such as human escalation.
Choose hooks over prompt instructions whenever a business rule requires guaranteed compliance
rather than probabilistic compliance.

**D1.6 — Choose a task-decomposition strategy that matches the workflow.**
Fixed sequential pipelines (prompt chaining) suit predictable multi-aspect work — analyze each file
on its own, then run a separate cross-file integration pass. Dynamic, adaptive decomposition — where
what you discover at each step generates the next subtask — suits open-ended investigation. For a
broad task like "add comprehensive tests to a legacy codebase", map the structure first, identify
high-impact areas, then build a prioritized plan that adapts as dependencies surface.

**D1.7 — Manage session state, resumption, and forking.**
Resume a named session with **`--resume <session-name>`** when continuity matters. Use
**`fork_session`** to branch independent explorations from one shared analysis baseline — comparing
two refactoring strategies without redoing the analysis. When prior tool results have gone stale
(the code changed underneath), starting fresh with a written structured summary beats resuming with
outdated state; if you do resume, tell the agent exactly which files changed so it re-analyzes those
rather than re-exploring everything.

Common mistakes worth testing: deciding loop exit by scanning assistant text or a sentinel phrase
instead of `stop_reason`; using an iteration cap as the primary stop condition; assuming subagents
see the parent's history; omitting `"Task"` from a coordinator's `allowedTools`; one mega-agent
holding every tool; prompt-only enforcement of order-sensitive, high-stakes steps; serial execution
of independent delegations; blaming a downstream subagent for a coordinator's too-narrow
decomposition.

### D2 — Tool Design & MCP Integration (18% · 11 items)

**D2.1 — Treat tool descriptions as the selection interface.**
The model picks tools by their descriptions; thin or interchangeable descriptions cause misrouting
between similar tools. A good description states purpose, input formats, example queries, edge
cases, and boundaries ("use X for …; use Y when …"). When two tools are confused, fix the
descriptions — or rename and split the tools — before adding routing machinery on top: rename an
overloaded `analyze_content` to something web-specific, or split a generic `analyze_document` into
purpose-specific tools with defined contracts. Also audit the system prompt: keyword-sensitive
instructions there can create unintended tool associations that override well-written descriptions.

**D2.2 — Return structured MCP errors the agent can recover from.**
Use the **`isError`** flag with structured fields — an error category (`transient` / `validation` /
`permission` / business-policy), a retryable boolean, and a human-readable explanation. Distinguish
transient faults (retry), validation errors (fix the input), business or policy rejections (do not
retry — explain to the customer or escalate), and permission failures. Mark policy violations
explicitly non-retryable with a customer-safe explanation. A subagent should recover locally from
transient faults and propagate only what it cannot resolve, carrying partial results and what was
attempted. A valid-but-empty result is **not** an error; a generic "operation failed" string strands
the caller and invites blind retries.

**D2.3 — Distribute tools across agents and configure `tool_choice`.**
Selection reliability degrades as the catalog grows — an agent holding 18 tools chooses worse than
one holding 4–5, and an agent given tools outside its specialization tends to misuse them (a
synthesis agent attempting web searches). Scope each agent to its role, and provide a narrow
cross-role tool only for a genuine high-frequency need (a scoped `verify_fact` for the synthesis
agent) while routing complex cases back through the coordinator. Prefer constrained,
purpose-specific tools over generic ones — replace a bare `fetch_url` with a `load_document` that
validates what it is given. Use **`tool_choice`** deliberately: `"auto"` lets the model answer in
text or call a tool; `"any"` forces some tool call; forced (`{"type": "tool", "name": …}`)
guarantees a specific tool runs first, with later steps handled in follow-up turns.

**D2.4 — Configure MCP servers into Claude Code and agent workflows.**
Project scope (**`.mcp.json`**, committed) is for shared team tooling; user scope
(**`~/.claude.json`**) is for personal and experimental servers — and both are available at once.
Reference credentials through **environment-variable expansion** (`${GITHUB_TOKEN}`), never literal
tokens in a committed file. Tools from every connected server are discovered at connection time and
offered together, so description quality decides adoption — a thin MCP description loses to a
built-in like Grep even when the MCP tool is more capable. Expose content catalogs (issue summaries,
doc hierarchies, database schemas) as **MCP resources** so agents browse instead of probing with
repeated exploratory calls. Reach for an existing community server for standard integrations and
reserve custom servers for team-specific workflows.

**D2.5 — Select the right built-in tool: Read, Write, Edit, Bash, Grep, Glob.**
Grep searches file *contents* (function names, error strings, import statements); Glob matches file
*paths and names* (`**/*.test.tsx`); Read and Write handle whole files; Edit makes targeted changes
by matching unique anchor text — and when that text isn't unique, Read + Write is the reliable
fallback. Build codebase understanding incrementally: Grep for entry points, then Read to follow
imports and trace flows, rather than bulk-reading everything upfront. To trace usage across wrapper
modules, first identify every exported name, then search each name across the codebase.

Common mistakes worth testing: two tools whose descriptions could describe each other; giving every
subagent the full catalog; returning empty results or generic strings for failures; treating a
no-match query as an error (or an access failure as "no results"); secrets hard-coded in shared MCP
config; building a keyword routing layer instead of fixing descriptions; reaching for Glob to search
file contents.

### D3 — Claude Code Configuration & Workflows (20% · 12 items)

**D3.1 — Place memory at the right level and keep it modular.**
The hierarchy is user-level (`~/.claude/CLAUDE.md`), project-level (committed `CLAUDE.md` or
`.claude/CLAUDE.md`), and directory-level files scoping a subtree. User-level instructions apply
only to that user and never reach teammates through version control — so "works for me, not for the
team" is almost always a placement bug. Keep CLAUDE.md lean with **`@import`** references to
external standards files, and split topic rules into **`.claude/rules/`** instead of growing one
monolith. **`/memory`** shows what actually loaded, which is how you diagnose inconsistent behavior
across machines.

**D3.2 — Create custom slash commands and skills, at the right scope.**
Project commands in **`.claude/commands/`** are version-controlled and arrive with clone or pull;
`~/.claude/commands/` stays personal. Skills live in **`.claude/skills/`** as `SKILL.md` with
frontmatter — **`context: fork`** runs the skill in an isolated subagent context so verbose output
(codebase analysis) or exploratory output (brainstorming) never pollutes the main conversation;
**`allowed-tools`** restricts what the skill may touch; **`argument-hint`** prompts the developer for
required parameters when they invoke it bare. For a personal variant of a team skill, put a
differently-named copy in `~/.claude/skills/` rather than editing the shared one. Choose by
frequency: always-loaded universal standards belong in CLAUDE.md; an occasional multi-step procedure
belongs in a skill.

**D3.3 — Scope conventions to file patterns with path-specific rules.**
A file in `.claude/rules/` with YAML frontmatter **`paths:`** glob patterns loads only when matching
files are touched, keeping irrelevant context and tokens out of every other session. This is the
right tool when a convention applies to a file *pattern* scattered across the tree — test files
living next to the code they test, everything under `terraform/**/*` — where per-directory
CLAUDE.md files can't reach and one monolith would be unmaintainable.

**D3.4 — Decide between plan mode and direct execution.**
Plan mode is for large-scale change, multiple valid approaches, architectural decisions, and
multi-file work: it lets you explore the codebase and design before committing, which is what
prevents expensive rework. Direct execution is for small, well-understood, well-scoped changes — a
single-file fix with a clear stack trace, one added validation check. The two combine naturally:
plan the migration, then execute the plan. Delegate verbose discovery to the **Explore subagent** so
a multi-phase task doesn't exhaust the main context.

**D3.5 — Iterate the way the tool works best.**
Concrete input/output examples beat prose whenever a description is being interpreted
inconsistently — two or three examples usually settle it. Write the test suite first (expected
behavior, edge cases, performance requirements), then iterate by feeding failures back. Use the
**interview pattern** — have Claude ask you questions before implementing — to surface
considerations you hadn't thought of (cache invalidation, failure modes) in unfamiliar domains.
Batch interacting problems into one detailed message; sequence independent ones.

**D3.6 — Run Claude Code in CI/CD.**
Use **`-p` / `--print`** for non-interactive mode so a job never hangs waiting on input, and
**`--output-format json`** with **`--json-schema`** so the pipeline reads fields instead of grepping
prose — that is what makes findings postable as inline PR comments. Supply project context through
committed CLAUDE.md: testing standards, fixture conventions, review criteria — which is also how you
stop test generation producing low-value tests. Review with a **fresh instance**, not the session
that wrote the code. On a re-run after new commits, pass prior findings and instruct Claude to report
only new or still-unaddressed issues; pass existing test files so generation doesn't duplicate
covered scenarios.

Common mistakes worth testing: team instructions trapped in a personal user-level file; one giant
CLAUDE.md doing everything; per-directory copies of a convention that wants a glob rule; a skill
where deterministic path-based loading was needed; interactive invocation inside CI; grepping prose
output for a keyword to gate a merge; the code-writing session reviewing its own output; switching
to plan mode only after complexity "emerges" when it was stated in the requirements.

### D4 — Prompt Engineering & Structured Output (20% · 12 items)

**D4.1 — Replace vague quality adjectives with explicit criteria.**
"Be conservative" and "report only high-confidence issues" do not measurably improve precision.
Define *which* findings to report and which to skip — bugs and security in, minor style and local
patterns out — with concrete code examples for each severity level so classification stays
consistent. False positives are contagious: one noisy category erodes trust in the accurate ones, so
disable that category outright while you fix its definition rather than leaving it live.

**D4.2 — Use few-shot examples to pin format and judgment.**
Two to four targeted examples are the most effective lever when detailed instructions still produce
inconsistent output. Show the exact output shape (location, issue, severity, suggested fix),
demonstrate the reasoning for choosing one action over a plausible alternative, and cover the
ambiguous cases explicitly — examples that distinguish an acceptable pattern from a genuine issue cut
false positives while still letting the model generalize to novel patterns rather than pattern-match
the listed ones. In extraction, examples spanning varied document structures (inline citations vs
bibliographies, narrative prose vs tables) are what fix empty or fabricated fields.

**D4.3 — Guarantee parseable output with tool use and JSON schemas.**
Schema-enforced tool input is the reliable route to structured output: it eliminates JSON *syntax*
errors — but not *semantic* ones, like line items that don't sum to the stated total or a value in
the wrong field. Choose `tool_choice` to match: `"any"` guarantees a tool call when several
extraction schemas exist and the document type is unknown; a forced named tool guarantees a specific
extraction runs before enrichment steps. Design schemas defensively: make a field optional or
nullable when the source may simply lack it, because a required non-nullable field leaves the model
no legal way to say "absent" and it will invent a value. Use enums with an `"other"` + detail-string
escape hatch and values like `"unclear"` for genuine ambiguity. Put format-normalization rules in
the prompt alongside a strict schema when source formatting is inconsistent.

**D4.4 — Build validation, retry, and feedback loops.**
On a validation failure, retry with the original document, the failed extraction, and the *specific*
validation errors in the prompt. Know the limit: retries fix format and structural problems, and
cannot conjure information that was never in the source — distinguish the two before spending the
call. Add companion fields that make self-checking possible: a `calculated_total` alongside a
`stated_total` to surface arithmetic discrepancies, a `conflict_detected` boolean for inconsistent
source data. Add a `detected_pattern` field to each finding so you can analyze *which* code
constructs developers keep dismissing and fix the prompt systematically.

**D4.5 — Design batch processing strategies.**
The **Message Batches API** trades latency for cost: roughly 50% cheaper, up to a 24-hour processing
window, no latency SLA, and no multi-turn tool calling inside a request. That makes it right for
non-blocking, latency-tolerant work — overnight reports, weekly audits, nightly test generation —
and wrong for anything a person or a merge is waiting on. Correlate requests and responses by
**`custom_id`**, resubmit only the failures (chunking a document that blew the context limit), and
work back from the SLA when setting submission cadence — a 24-hour window plus a 30-hour commitment
means submitting every few hours, not once daily. Pilot the prompt on a sample before the bulk run.

**D4.6 — Design multi-instance and multi-pass review architectures.**
A model reviewing its own output in the same session retains its generation reasoning and is less
likely to question its own decisions, so an **independent instance** with no prior context catches
what self-review instructions and extended thinking miss. For large diffs, split into focused
per-file passes for local issues plus a separate cross-file integration pass — a single mega-pass
dilutes attention and produces the tell-tale symptom of contradictory findings, flagging a pattern in
one file and approving identical code elsewhere. Have the model self-report confidence per finding to
route human attention, not to filter findings out.

Common mistakes worth testing: required schema fields forcing fabricated values; "don't hallucinate"
as a structural fix; retrying extraction of data the document never contained; batch APIs in blocking
workflows; grading your own homework in the same session; reaching for a larger context window to fix
an attention-dilution problem; requiring cross-run consensus and thereby suppressing real intermittent
findings.

### D5 — Context Management & Reliability (15% · 9 items)

**D5.1 — Preserve load-bearing facts across long interactions.**
Progressive summarization loses exactly what matters — amounts, dates, order numbers, statuses,
commitments made to the customer. Extract those into a structured **case-facts block** carried in
every prompt *outside* any summary, and keep a separate structured layer per issue in multi-issue
sessions. Trim verbose tool results to the relevant fields before they accumulate: an order lookup
returning 40+ fields when 5 matter is spending context on noise. Long-context recall favors the
beginning and end of the input — the **lost-in-the-middle** effect — so lead with key findings and
organize the rest under explicit section headers. Pass complete conversation history in subsequent
requests to keep coherence. Where a downstream agent has a tight context budget, have upstream agents
return structured key facts, citations, and relevance scores instead of prose and reasoning chains.

**D5.2 — Design escalation and ambiguity resolution.**
Escalate on observable triggers: the customer explicitly asks for a human, policy is silent or
ambiguous on what they're asking (a competitor price match when policy covers only own-site
adjustments), or no meaningful progress is possible. Encode those triggers with few-shot examples.
Honor an explicit request for a human *immediately*, without first attempting an investigation; when
frustration is expressed but the issue is squarely within capability, acknowledge it and offer to
resolve, escalating only if they reiterate. Sentiment and model self-reported confidence are
unreliable proxies for case complexity — an agent already overconfident on hard cases will not flag
them. On ambiguous identity, ask for additional identifiers rather than picking a match heuristically.

**D5.3 — Propagate errors across a multi-agent system.**
A failure report to the coordinator carries the failure type, what was attempted, any partial results,
and viable alternatives — enough for it to retry with a modified query, reroute, or proceed degraded.
Distinguish an access failure (timeout, needing a retry decision) from a valid empty result (the query
succeeded, nothing matched). Never collapse a failure into a generic status that hides the context;
never convert a failure into a fake success by returning empty results as OK; never abort the whole
run because one source failed. Carry **coverage annotations** into the synthesis — which findings are
well-supported and which topic areas have gaps because a source was unavailable.

**D5.4 — Manage context through large codebase exploration.**
Context degradation in a long session has a signature: answers turn inconsistent and start
referencing "typical patterns" instead of the specific classes discovered earlier. Counter it —
persist key findings to **scratchpad files** that survive context boundaries and reference them for
later questions; spawn subagents to answer specific questions ("find all test files", "trace the
refund flow's dependencies") while the main agent keeps only high-level coordination; summarize each
phase before starting the next and inject that summary into the next phase's initial context; run
**`/compact`** when verbose discovery output has filled the window. For crash recovery, have each
agent export state to a known location and have the coordinator load a **manifest** on resume and
inject it into agent prompts.

**D5.5 — Design human review workflows and calibrate confidence.**
A strong aggregate number hides segment failure: 97% overall can mean 99% on clean invoices and 60%
on scanned ones. Before reducing human review, analyze accuracy **by document type and by field**,
and verify the confidence threshold actually maps to an acceptable error rate — measure it with
**stratified random sampling** of high-confidence extractions, which also surfaces novel error
patterns. Have the model emit **field-level** confidence and calibrate the routing threshold against
a labeled validation set. Route low-confidence and ambiguous or self-contradictory documents to the
limited human reviewers first.

**D5.6 — Preserve provenance and handle uncertainty in multi-source synthesis.**
Attribution is destroyed at summarization time unless it is required as structured output and carried
through every stage: claim, source URL or document name, relevant excerpt, publication or collection
date. Require subagents to emit those mappings and require synthesis to merge rather than
re-attribute. When credible sources conflict, annotate the disagreement with attribution instead of
silently picking a value — and let document analysis pass conflicting values upward, annotated, for
the coordinator to reconcile. Dates matter: without them, temporal drift reads as contradiction.
Structure the report to separate well-established findings from contested ones, preserve each source's
original characterization and methodological context, and render each content type in its natural
form — financial data as tables, news as prose, technical findings as structured lists — rather than
flattening everything into one format.

Common mistakes worth testing: vague summaries that drop figures; sentiment-triggered escalation;
trusting self-reported confidence as a gate; investigating before honoring an explicit request for a
human; "search failed" with no actionable detail; empty-result-as-success; aborting a whole run on one
source failure; re-attributing citations after the fact; auto-approving on an aggregate accuracy
number; one uniform output format for every content type.

## Key concepts & exact identifiers (public product/API surface — use precise names)

- **Claude Agent SDK** — agentic loop; `stop_reason` (`"tool_use"`, `"end_turn"`);
  `AgentDefinition` (description, system prompt, tool restrictions); subagent spawning via the
  **`Task`** tool; **`allowedTools`** (must include `"Task"` to delegate); hooks — **`PostToolUse`**
  for result transformation, outgoing tool-call interception for policy enforcement; session resume
  and **`fork_session`**.
- **MCP** — servers, tools, resources; **`isError`**; structured error fields (`errorCategory`
  transient / validation / permission, `isRetryable`, human-readable description); tool descriptions
  and their effect on adoption; project scope **`.mcp.json`** (committed) vs user scope
  **`~/.claude.json`**; environment-variable expansion (`${GITHUB_TOKEN}`); resources as content
  catalogs.
- **Claude Code** — CLAUDE.md hierarchy (user / project / directory) and **`@import`**;
  **`.claude/rules/`** with YAML **`paths:`** globs; **`.claude/commands/`**; **`.claude/skills/`**
  with `SKILL.md` frontmatter — **`context: fork`**, **`allowed-tools`**, **`argument-hint`**; plan
  mode; direct execution; the **Explore subagent**; **`/memory`**; **`/compact`**; **`--resume`**.
- **Claude Code CLI** — **`-p`** / **`--print`**; **`--output-format json`**; **`--json-schema`**.
- **Claude API** — `tool_use` with JSON schemas; **`tool_choice`** (`"auto"`, `"any"`, forced
  `{"type":"tool","name":"…"}`); `stop_reason`; `max_tokens`; system prompts.
- **Message Batches API** — ~50% cost saving; up to a 24-hour window; no latency SLA; **`custom_id`**
  correlation; polling for completion; no multi-turn tool calling.
- **JSON Schema** — required vs optional; nullable; enums; `"other"` + detail-string patterns; strict
  mode eliminating syntax errors; syntax vs semantic validation.
- **Pydantic** — schema validation; semantic validation errors; validation-retry loops.
- **Built-in tools** — Read, Write, Edit, Bash, Grep, Glob — and their selection criteria.
- **Prompting & context** — few-shot prompting; prompt chaining; progressive summarization pitfalls;
  lost-in-the-middle / position effects; context extraction; scratchpad files; state manifests for
  crash recovery.
- **Confidence** — field-level confidence scores; calibration against labeled validation sets;
  stratified sampling for error-rate measurement.

## In-scope topics

Agentic loop implementation (`stop_reason` control flow, tool-result handling, termination);
multi-agent orchestration (coordinator-subagent patterns, task decomposition, parallel spawning,
iterative refinement); subagent context management (explicit passing, structured state persistence,
manifest-based crash recovery); tool interface design (descriptions, splitting vs consolidating,
naming to reduce ambiguity); MCP tool and resource design (resources for catalogs, tools for actions,
description quality); MCP server configuration (project vs user scope, env-var expansion,
multi-server simultaneous access); error handling and propagation (structured responses, transient vs
business vs permission, local recovery before escalation); escalation decision-making (explicit
criteria, honoring customer preference, policy-gap identification); CLAUDE.md configuration
(hierarchy, `@import`, `.claude/rules/` globs); custom commands and skills (scope, `context: fork`,
`allowed-tools`, `argument-hint`); plan mode vs direct execution; iterative refinement (I/O examples,
test-driven iteration, interview pattern, sequential vs batched fixes); structured output via
`tool_use` (schema design, `tool_choice`, nullable fields); few-shot prompting (ambiguous cases,
format consistency, false-positive reduction); batch processing (Batches API fit, latency tolerance,
failure handling by `custom_id`); context-window optimization (trimming tool output, structured fact
extraction, position-aware ordering); human review workflows (calibration, stratified sampling,
accuracy segmentation); information provenance (claim-source mappings, temporal data, conflict
annotation, coverage gaps).

## Out-of-scope topics (this mock does not generate items on)

Fine-tuning or training custom models; Claude API authentication, billing, or account management;
detailed implementation in specific languages or frameworks beyond what tool and schema
configuration needs; deploying or hosting MCP server infrastructure (networking, containers,
orchestration); Claude's internal architecture, training process, or model weights; Constitutional
AI, RLHF, or safety-training methodology; embedding models and vector-database internals; computer
use (browser or desktop automation); vision and image analysis; streaming API implementation or
server-sent events; rate limits, quotas, or pricing math; OAuth, key rotation, or auth protocol
detail; cloud-provider-specific configuration (AWS, GCP, Azure); performance benchmarking or model
comparison; prompt-caching implementation detail beyond knowing it exists; token-counting or
tokenization specifics.

## Few-shot anchors (reference-only)

The self-authored questions in `ccaf-question-bank.md` are the style, difficulty, and
explanation-tone anchors — **they are never served in an exam** (the bank is readable by any
candidate, so serving it would inflate scores; the state helper rejects bank questions at write
time). Generated items should match their shape without reusing their stems or options: a realistic
production scenario, one clearly-correct option, and three distractors a candidate with incomplete
knowledge would plausibly pick (build them from the common-mistake lists above). Explanations say
why the correct option is right **and** why each distractor is wrong. **Ignore the anchors' answer
positions** — they are lopsided toward A because each was written for content, and answer position
must be shuffled independently per attempt.

## Scoring

- Raw `correct` = count of items whose recorded answer equals the answer key. An unanswered item is
  incorrect.
- `scaled = 100 + 15 × correct` (this is `100 + round(correct ÷ 60 × 900)`; since `900 ÷ 60 = 15`
  exactly, no rounding is needed). Range: 0 correct → 100, 60 correct → 1000.
- **Pass iff `scaled ≥ 720`**, i.e. **≥ 42 of 60** correct (42 → 730 PASS; 41 → 715 FAIL).
- Always report a per-domain breakdown — correct / total **and percent** per D1–D5, matching what
  the real score report shows — and state that domain percentages are diagnostic only: the pass/fail
  decision is the total scaled score.
- Always state the estimate disclaimer: this linear mapping is not Anthropic's proprietary equating
  curve.
