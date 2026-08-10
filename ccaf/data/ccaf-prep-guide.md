# CCAF — Preparation Guide

Companion to `ccaf-blueprint.md`. The blueprint is the *content* authority — what gets tested and
how a mock is assembled. This file is the *preparation* authority: how to get ready, what to build
with your own hands, and the certification logistics a candidate needs before booking.

All prose here is **self-authored** for this plugin. The certification facts (fee, validity,
delivery, retake and recertification rules) are the program's published policies, restated in our
own words; the study routes and exercises are ours, written from public Anthropic documentation and
our own production experience.

Read by:
- `ccaf-tutor` (`/ccaf:prepare`) — to recommend a study route and assign hands-on exercises.
- `ccaf-exam` / `ccaf-practice` — only for the post-result guidance and logistics facts. Never for
  item content; that comes from the blueprint.

---

## Study routes

Pick the route that matches where the candidate is, not the one that covers the most ground.

| Route | When it fits | Path |
| ----- | ------------ | ---- |
| **Full sweep** | First exposure, or a mock below ~600 | D1 → D2 → D3 → D4 → D5 in order. Later domains lean on earlier ones: D5's error propagation only makes sense once D1's coordinator model is solid. |
| **Weak-domain drill** | A mock in the 600–719 band with one or two soft domains | The weak domain's task statements only, then `/ccaf:practice` on that domain, then a fresh mock. |
| **Format hardening** | Content is solid but multiple-response items are costing points | Practise choose-two and choose-three reasoning specifically: for each item, decide the status of *every* option rather than hunting for one winner. |
| **Pre-booking pass** | A mock at 720+, sitting the exam soon | One pass over the anti-pattern lists in each domain's "common mistakes", plus one hands-on exercise in the softest domain. Do not re-study what is already solid. |

## What to actually practise

Reading about these topics produces recognition; building them produces the judgment the exam
tests. Each line below is a thing to *do*, mapped to the task statements it exercises.

- **Run a real agentic loop.** Implement the loop by hand against the API — dispatch on
  `stop_reason`, execute the requested tools, append results, iterate — with error handling and
  session management. Then delegate: spawn a subagent and pass it context explicitly. *(D1.1, D1.3,
  D1.7)*
- **Configure Claude Code properly for one real project.** A committed CLAUDE.md with a real
  hierarchy, `@import`s to standards files, path-scoped rules under `.claude/rules/`, a skill with
  frontmatter options set, and at least one MCP server wired in. *(D3.1, D3.2, D3.3, D2.4)*
- **Write tool descriptions that survive ambiguity.** Build two deliberately similar tools, watch
  the model misroute between them, then fix it with descriptions alone. Add structured error
  returns with categories and retryable flags and confirm the agent's recovery behavior changes.
  *(D2.1, D2.2)*
- **Build an extraction pipeline end to end.** `tool_use` with a JSON schema, a validation-retry
  loop, deliberately nullable fields, and a batch run through the Message Batches API. *(D4.3,
  D4.4, D4.5)*
- **Do the prompt-engineering work.** Write few-shot examples for genuinely ambiguous cases; replace
  a vague quality instruction with explicit report/skip criteria and measure the false-positive
  change; split one large review into per-file plus integration passes. *(D4.1, D4.2, D4.6)*
- **Fight a context window on purpose.** Extract structured facts out of verbose tool output, keep a
  scratchpad across a long session, and delegate exploration to subagents to stay under budget.
  *(D5.1, D5.4)*
- **Decide escalations deliberately.** Write the trigger list — explicit request, policy gap,
  no-progress — with examples, and design a human-review routing workflow driven by calibrated
  confidence rather than raw model self-report. *(D5.2, D5.5)*

## Hands-on exercises

Four self-contained builds. Each one is worth more than an hour of reading, and each ends in
something observable — a behavior that changed, or a failure you can reproduce. The tutor can assign
any of these when a candidate wants to consolidate a domain.

### Exercise 1 — A multi-tool agent that knows when to stop and when to hand off

*Exercises: D1.1, D1.4, D1.5, D2.1, D2.2, D5.2 — anchor scenario: `customer-support`.*

1. Define three or four MCP tools with descriptions detailed enough to differentiate them: purpose,
   input formats, example calls, boundaries. Make at least two of them genuinely similar in
   function, so the descriptions are the only thing keeping selection reliable.
2. Implement the agentic loop yourself. Branch on `stop_reason` — execute and continue on
   `"tool_use"`, present the final response on `"end_turn"`. Resist adding an iteration cap as the
   stop condition; add it only as a runaway backstop, and notice the difference.
3. Give every tool a structured error return — category (transient / validation / permission /
   policy), a retryable flag, a human-readable explanation. Then force each error type and confirm
   the agent retries the transient one, corrects the validation one, and *explains* the policy one
   instead of retrying it.
4. Add a hook that intercepts outgoing tool calls and blocks one that violates a business rule — an
   amount over a threshold — redirecting to an escalation path. Verify it holds even when you
   prompt the model to bypass it. That gap between "the prompt said no" and "the code said no" is
   the whole point of D1.4.
5. Send a message containing two unrelated problems. Verify the agent decomposes them, handles each,
   and returns one coherent resolution rather than answering only the first.

### Exercise 2 — Claude Code configured for a team, not for you

*Exercises: D3.1, D3.2, D3.3, D3.4, D2.4 — anchor scenario: `code-generation`.*

1. Put universal coding and testing standards in a committed project-level CLAUDE.md. Then verify
   from a *second* checkout — or a teammate's machine — that they load. Use `/memory` to see what
   actually loaded rather than assuming.
2. Add two `.claude/rules/` files with different `paths:` globs — one for a directory-bound area,
   one for a pattern that is scattered across the tree (test files sitting beside their sources).
   Edit a matching file and a non-matching file and confirm the rules load conditionally.
3. Create a project skill whose output is verbose — a codebase survey — and set `context: fork`.
   Run it and confirm the survey output never lands in your main conversation. Add `allowed-tools`
   to fence what it can touch, and `argument-hint` so invoking it bare prompts you.
4. Configure a shared MCP server in `.mcp.json` with `${ENV_VAR}` expansion for its credential, and a
   personal experimental server in `~/.claude.json`. Confirm both sets of tools are offered at once,
   and that nothing secret is in the committed file.
5. Run three tasks of escalating shape — a single-file fix with a clear stack trace, a
   multi-file migration, a feature with several defensible designs — and note where plan mode paid
   for itself and where it was overhead. That felt difference is what D3.4 asks about.

### Exercise 3 — An extraction pipeline that refuses to fabricate

*Exercises: D4.3, D4.4, D4.5, D5.5 — anchor scenario: `structured-extraction`.*

1. Define an extraction tool whose JSON schema mixes required and optional fields, includes an enum
   with an `"other"` + detail-string escape hatch, and makes genuinely-absent information nullable.
   Feed it documents missing those fields and confirm you get nulls rather than invented values.
   Then make one field required and non-nullable and watch it fabricate — that contrast is D4.3.
2. Wrap it in a validation-retry loop that sends back the document, the failed extraction, and the
   specific validation error. Keep a tally of which failures retries actually fix (format,
   structure) versus which they never will (the information simply is not in the source).
3. Add few-shot examples spanning structurally different documents — a table-driven invoice and a
   narrative one, inline citations and a bibliography — and measure whether empty-field rates drop.
4. Run a hundred documents through the Message Batches API. Correlate results by `custom_id`,
   resubmit only failures with a fix applied (chunk the one that exceeded the context limit), and
   work out what submission cadence a 30-hour commitment would require given a 24-hour window.
5. Have the model emit per-field confidence. Route the low-confidence and self-contradictory
   documents to review, then check accuracy *segmented by document type and field* — not just the
   aggregate. Find the segment the aggregate was hiding.

### Exercise 4 — A research pipeline, then break it on purpose

*Exercises: D1.2, D1.3, D5.3, D5.6, D2.3 — anchor scenario: `multi-agent-research`.*

1. Build a coordinator that delegates to at least two subagents. Include `"Task"` in its
   `allowedTools`. Pass each subagent its inputs *explicitly in its prompt* — then try omitting them
   and watch the subagent report it received nothing. That failure is worth reproducing once.
2. Emit multiple `Task` calls in a single coordinator response and compare wall-clock against
   spawning them across turns.
3. Give subagents a structured output shape that separates content from metadata: claim, evidence
   excerpt, source name or URL, publication date. Then confirm the synthesis step *carries* those
   mappings rather than re-attributing claims afterward.
4. Make a subagent time out. Verify the coordinator receives failure type, attempted query, and
   partial results — enough to reroute or proceed degraded — and that the final report carries a
   coverage annotation naming what is missing. Then try the anti-patterns: return the timeout as an
   empty success, and abort the whole run. Both should feel obviously wrong once you have seen the
   structured version.
5. Feed it two credible sources with conflicting figures. The synthesis must present both with
   attribution and dates, not silently pick one — and the report should separate well-established
   findings from contested ones.

## Answering multiple-response items

25% of the real exam's items ask for more than one response, and the stem always states how many.
They punish a different habit than single-select items do:

- **Read the count first, then answer.** "Select TWO" changes the task from *find the best option*
  to *classify every option*. Candidates lose these by finding one strong answer and stopping.
- **Scoring is all-or-nothing.** One right and one wrong scores the same as zero right. There is no
  partial credit, so a coin-flip on the second pick costs the whole item.
- **Work by elimination, not attraction.** Decide the status of each option independently against the
  task statement being tested. The distractors are built from real practitioner misconceptions, so
  "sounds reasonable" is exactly the trap.
- **Watch for two answers that are the same idea.** If two options say substantially the same thing,
  usually neither is in the key — a well-built choose-two item wants two *distinct* correct actions.

## Registration, policies, and recertification

Program facts a candidate needs before booking. Restated in our own words; confirm against the
current official guide before relying on any of it, as program policy can change.

**Booking.** Registration runs through the Anthropic Partner Academy, and the exam itself is
delivered by Pearson VUE. Review the exam details and the certification terms on the Partner Academy
page, register and check out (partner-tier discounts apply at checkout), then create a Pearson VUE
account to schedule the session. Choose either online proctoring or a Pearson test centre. Cancel or
reschedule at least 24 hours ahead — inside that window the fee is forfeit, as it is for a no-show or
a late arrival beyond the permitted window.

**Cost and validity.** The exam fee is **$125 USD** per attempt. The credential is valid for **12
months** from the date it is awarded.

**Exam day.** Bring valid, unexpired, government-issued photo ID whose name matches the
registration exactly — name corrections go through certification support *before* scheduling. The
session is proctored: stay in view of the webcam if testing online, keep the workspace clear of
notes, books, phones, watches, headphones, and secondary monitors, don't communicate with anyone, and
don't capture or reproduce any exam content. Only what the proctor explicitly permits (scratch paper,
if offered) is allowed. Accommodations for documented needs are available but must be requested and
approved by Pearson VUE **before** scheduling. A confidentiality and non-disclosure agreement is
accepted at the start; declining it ends the session with no refund.

**If you don't pass.** Retakes are allowed after a waiting period that grows with each failure — 14
days after the first, 30 after the second, 90 after the third — with a maximum of four attempts per
rolling twelve months, per exam. Each attempt costs the full fee. That escalating wait is the real
argument for gating on a mock first: a failed attempt costs $125 and two weeks.

**Recertification.** Because the underlying technology moves quickly, the credential is
time-limited. Renewing on time means reviewing what has changed and completing a **free,
non-proctored** renewal assessment on the Partner Academy. If the credential lapses, the full exam at
the full fee is the only route back. If exam content changes substantially, holders may be required
to retake the full exam rather than take the renewal assessment.

**Appeals.** A decision — including a concern about a result — can be appealed to Pearson VUE support
within 14 days. The standard-setting outcome and the content of individual items are not appealable.

## Using this with the plugin

```
/ccaf:prepare   ──learn the task statements──►   /ccaf:practice   ──drill a weak domain──►   /ccaf:mock-exam
      ▲                                                                                            │
      └──────────────────────────── study what the breakdown flagged ◄────────────────────────────┘
```

Sit the real exam once a mock clears 720 with no domain badly trailing. A domain at 50% inside a
passing total is a coin-flip waiting to happen on a different form — the per-domain breakdown exists
to catch exactly that.
