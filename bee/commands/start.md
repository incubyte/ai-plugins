---
description: Triage router and the first command to run when the user doesn't know which Bee command applies. Takes a description, classifies the work (bug / small feature / large feature / exploratory / existing artifact pointer), detects high-risk context, and recommends the right chain entry — brainstorm, discover, spec-writer, planner, plan-implementer, or skip Bee entirely. Use when the user runs /bee:start, says "kick off a feature", "I want to build X", "we need to fix Y", "where do I start", or describes work without picking a command themselves.
argument-hint: <description of what to build, fix, explore, or a URL/path to an existing discovery or spec>
allowed-tools: ["Read", "Glob", "Grep", "Bash(git:*)", "AskUserQuestion", "Skill", "Task"]
---

# /bee:start

Triage router. Takes a description, classifies the work, recommends the right chain entry point, then invokes the chosen command. The user's first interaction with Bee's plan-driven chain when they don't yet know which command to run.

## Operating principles

- **Closed questions ALWAYS go through `AskUserQuestion`.** No exceptions. Plain-text numbered questions are a defect. Before sending any message containing a question, classify each: closed (yes/no, choose-one, binary) → `AskUserQuestion`; open (the value is in the user's words) → text. Mixed messages send the open part as text and the closed part as a tool call in the same turn. If you find yourself writing `1. ... 2. ... 3. ...` as questions, stop — that is the failure mode.
- **At most 2 closed questions before routing.** If you need more elicitation, that's a discovery signal — invoke `/bee:discover` directly with what you have (Step 5). Even when the user's prompt explicitly asks for "clarifying questions," route to discover — discovery is where elicitation belongs, not start.
- **Silent routing within Bee; confirm only when bailing out.** brainstorm / discover / spec-writer / planner / plan-implementer are reversible — invoke directly via `Skill` with the structured context note from Step 7. Confirm only the "skip Bee, fix manually" path, which exits the chain.
- **Detect high-risk context once.** High-risk-surface detection drives whether trivial fixes get a spec or skip Bee entirely.
- **Stateless.** start records nothing; the routed-to command does its own state writes.

## Step 1: Read the description

Parse the user's argument for signal words and structure:

- **Debug/diagnose signals** — *"debug"*, *"why is this failing"*, *"diagnose"*, *"tests are broken"*, *"returns 500"*, *"getting an error"*, *"stack trace"*, *"flaky"*, *"intermittent"*, specific error messages or stack traces pasted directly, CI failure URLs.
- **Bug-fix signals** — *"fix"*, *"broken"*, *"not working"*, *"bug in"*, *"regression"*, specific symptom phrases (*"page 2 missing first item"*, *"login fails when..."*).
- **Small-feature signals** — *"add"*, *"build"*, with concrete scope (*"a button to..."*, *"an endpoint for..."*).
- **Larger-feature signals** — *"build a system"*, *"new product area"*, multiple actors mentioned, multi-stakeholder hints.
- **Brainstorm signals** — *"brainstorm"*, *"what are our options"*, *"how might we"*, *"what if we"*, *"help me think through"*, *"explore approaches"*, *"let's brainstorm"*, open-ended problem with no clear direction yet.
- **Exploratory signals** — *"explore"*, *"investigate"*, *"we're thinking about"*, *"figure out"*, *"research"*, no clear scope but has identifiable stakeholders or inputs to synthesize.
- **Pointer signals** — `https://...`, `docs/specs/...`, *"see the discovery doc at"*, *"per the spec at"*. The user has a starting artifact.

If a URL or file path is provided, that takes precedence — route to the next chain step from that artifact (Step 4 mapping).

## Step 2: Quick context scan

If running inside a repo (cap at ~5 reads — start is triage, not exploration):

- List `docs/specs/` for existing specs (informational — useful when recommending).
- Read `README.md`, `CLAUDE.md`, and one top-level build or dependency manifest if present (the project's primary manifest file — whatever format the stack uses). Note primary stack, frameworks, and major modules in 2-4 bullets. These bullets feed the **Codebase observations** field of the structured context note in Step 7 — so downstream commands don't redo this scan.

**Detect design state.** Classify as one of four states using stack-agnostic signals — look for the *role* each file plays, not the specific framework or filename:

- **Greenfield** — no repo at all, OR repo exists but contains no UI source files, no component library config, no design system files, no visual design docs.
- **Brownfield-no-system** — UI source files are present (any of: `components/`, `views/`, `screens/`, `pages/`, `templates/`, `assets/styles/`, `public/css/`, or similar), but no formal design doc and no authoritative token/theme file.
- **Brownfield-with-system** — `.claude/DESIGN.md` or `design.md` exists (at repo root or `/docs`), OR an authoritative theme/token/variable file is present and acts as the visual source of truth (any stack: CSS custom-properties file, `tokens.json`, `theme.*`, `styles/variables.*`, etc.).
- **Ambiguous** — mixed signals (UI code present, partial docs). Default to brownfield-no-system; surface the ambiguity in the context note.

**Detect UI-touching** from the description. Mark `yes` if the description contains words such as: screen, page, view, component, button, form, modal, dialog, dashboard, layout, navigation, UI, UX, frontend, app, interface, visual, design, style. Mark `no` if the description is exclusively about: API, backend, migration, job, worker, queue, CLI, script, infrastructure, data pipeline, or similar. When ambiguous, default to `yes`.

**Detect high-risk context.** Determine whether this change's blast radius touches a **designated high-risk category** — auth (authentication, login, session, tokens), security (crypto, secrets, input sanitization), authorization/guard (access control, permission checks, middleware guards), payment (billing, charges, provider integration), or migrations (schema/data). This drives the trivial-fix routing in Step 4 and the tier floor in Step 3.

**Detect RISK from description signals.** Risk is a second axis alongside the bucket. It flows downstream to every command — spec depth, plan-implementer retry budget, review depth.

| Risk | Signals |
|---|---|
| **LOW** | Internal tool, low traffic, easy to revert, no high-risk surface, dev / staging only |
| **MODERATE** | User-facing surface, moderate traffic, some business logic, no high-risk surface |
| **HIGH** | Payment flow, authentication / authorization, data migration, high-traffic endpoint, hard-to-revert change, third-party integration with no idempotency |

If the description has explicit risk signals (*"payment"*, *"login"*, *"migrate"*, *"production database"*), classify accordingly. If unclear, ask once via `AskUserQuestion` at Step 5.

Risk threads forward as a hint to the invoked command in Step 7.

## Step 3: Triage the process tier

START is the brain of the workflow. Before routing, classify the work into exactly one **process tier** — how much process the work warrants. The tier is authored here, on the strongest model (START always runs at the `best` tier per the `model-tiers` skill), so the single most consequential routing decision is made once, well, and up front. The tier flows forward into Step 6's routing and (for `standard` / `full`) into plan authorship.

The three tiers differ on two orthogonal switches — **(A)** is a human-readable spec written for intent sign-off, and **(B)** is a structured plan produced:

| Tier | Spec? | Plan? | What runs |
|---|---|---|---|
| **quick-fix** | no | no | Direct change. A **bug** is fixed test-first; a non-bug trivial change gets a test only when the logic warrants one (Step 6 quick-fix path). |
| **standard** | no | yes | The work is well-understood — no human intent sign-off needed — but the machine routing is authored and inspectable: slices, per-slice build tiers, test strategy. No feasibility pass, no hard floors. |
| **full** | yes | yes | Large / high-risk / high-risk-surface-touching work. Spec written before the plan is authored. Hard floors enforced; escalation ratchet live. |

**Classify deterministically at the floor, then by the bucket+risk signal:**

1. **Floor to `full`** when the change *touches a high-risk surface* OR is **HIGH** risk — regardless of size. The floor signal is whether **this change's blast radius touches a high-risk category** (auth / security / authorization / payment / migration surfaces actually in the diff), established per-change.
2. Otherwise, **`quick-fix`** when the bucket is *trivial-fix* or *small-feature* AND risk is **LOW** AND the change touches no high-risk surface.
3. Otherwise, **`standard`** — the default for ordinary small / large features at MODERATE risk that need machine routing but no human-readable spec.

```
flowchart:
  prompt / ticket ──► this change touches a high-risk surface OR HIGH risk?
                        │ yes ──► full
                        │ no
                        ▼
                      bucket + risk
                        │ trivial-fix/small AND LOW risk AND no high-risk touch ──► quick-fix
                        │ otherwise ──► standard
```

Surface the chosen tier and a one-line reason to the developer before any downstream work — *"Process tier: standard — small feature, MODERATE risk, no high-risk surface touched."* The tier name is threaded into the Step 7 context note as `Process tier: <tier>`.

## Step 3.5: Design probe gate

For **Small feature** and **Larger feature** buckets (detected in Step 1), run the design probe below before routing. Skip for all other buckets (debug, bug-fix, brainstorm, exploratory, pointer — those routes handle design themselves or don't need it).

The gate decision depends on the design state and UI-touching flag derived in Step 2:

| Design state | UI-touching | First spec? | Action |
|---|---|---|---|
| Greenfield | any | any | Run **full design probe** |
| Brownfield-no-system | yes | any | Run **extract-and-confirm probe** |
| Brownfield-no-system | no | — | Skip |
| Brownfield-with-system | yes | yes | Run **alignment check** (one `AskUserQuestion`) |
| Brownfield-with-system | yes | no | Skip — design system answers it |
| Brownfield-with-system | no | — | Skip |

"First spec" = `docs/specs/` is empty or does not exist (already checked in Step 2).

**Full design probe (greenfield).** Respect per-turn budget — one open question per turn, `AskUserQuestion` for all closed:

1. Open: *"Name two or three products whose look and feel you admire. What should this product learn from each?"*
2. `AskUserQuestion` — Density: *dense and information-rich / balanced / spacious and minimal*.
3. `AskUserQuestion` — Tone: *precise and clinical / professional and warm / playful and consumer / utilitarian*.
4. `AskUserQuestion` — Color mode: *light / dark / both / follow system*.
5. `AskUserQuestion` — Motion: *none / subtle / expressive*.
6. Open: *"In one word, what should a user feel the first time they use this?"*
7. `AskUserQuestion` — Accessibility floor: *WCAG AA / WCAG AAA / legally mandated minimum*.

**Extract-and-confirm probe (brownfield-no-system).** Read existing UI source files first, then:

1. Summarize the visual conventions you observed: dominant layout patterns, styling approach, color palette, type scale. Keep to 3-5 bullets. Describe in neutral terms — do not name specific libraries unless the user already has.
2. `AskUserQuestion` — Direction: *keep these conventions and formalize them / evolve in some areas (ask which) / stop drift, do not evolve*.
3. Open: *"What visual anti-patterns do you want explicitly banned going forward?"*

**Alignment check (brownfield-with-system, first spec).** One `AskUserQuestion`: *"I found a design system doc at [path]. Should new features follow it as-is, or has the direction evolved since it was written?"* Options: *follow as-is / it has evolved — let me explain / I'll update the design doc first*.

Capture probe answers in the context block under `Design direction` (see Step 7). If the probe was skipped, set `Design direction: none — probe skipped`.

The design probe questions count toward the 2-question elicitation cap only if elicitation is also needed for routing disambiguation (Step 5). When the bucket is already clear and only the probe runs, the cap does not apply to the probe itself.

## Step 4: Heuristic classification

Map description signals + high-risk context to a bucket:

| Bucket | Description signals | High-risk surface? | Route |
|---|---|---|---|
| Debug/diagnose | debug/diagnose, error message, stack trace, CI failure, *"why is this failing"* | either | quick-fix execution path (test-first reproduction) |
| Trivial fix (high-risk surface) | bug-fix, localized, user already knows the cause | yes | `/bee:spec-writer` (bug-fix mode) → `/bee:planner` → `/bee:plan-implementer` |
| Trivial fix (no high-risk surface) | bug-fix, localized, user already knows the cause | no | Skip Bee — suggest manual fix (confirm via `AskUserQuestion`) |
| Small feature | clear scope, single slice expected | either | tier-driven (Step 6) |
| Larger feature | clear scope, multi-slice / multi-stakeholder | either | `/bee:spec-writer` → `/bee:planner` → `/bee:plan-implementer` |
| Brainstorm | open-ended, no plan yet, *"brainstorm"*, *"options"* | either | `/bee:brainstorm` → `/bee:discover` |
| Exploratory | fuzzy, multi-stakeholder, *"explore"*, has inputs to synthesize | either | `/bee:discover` → `/bee:spec-writer` → `/bee:planner` → `/bee:plan-implementer` |
| Existing artifact (discovery doc) | user pointed at a discovery brief | either | `/bee:spec-writer` against that doc |
| Existing artifact (spec) | user pointed at a spec | either | `/bee:planner` (plan it) → `/bee:plan-implementer` |

If the heuristic is unambiguous, advance to Step 6. Otherwise Step 5.

## Step 5: Targeted elicitation (only if heuristic is unsure)

**Hard cap: 2 closed questions max.** If the heuristic from Step 4 is already unambiguous, skip Step 5 entirely. After 2 closed `AskUserQuestion` calls, if the route is still unclear, that's a discovery signal — proceed to Step 6 with bucket `exploratory` and silently invoke `/bee:discover` with the structured context note. Do not open a third question.

**Per-message check.** Before sending any message in this step, classify every question: closed → `AskUserQuestion`; open → text. Plain-text numbered question lists are a defect (the model's default tendency under user pressure — resist it).

Pick from these closed-question options for the disambiguating `AskUserQuestion` calls:

- *"Is this a bug fix or new functionality?"* — bug / feature / refactor / exploring.
- *"How big do you think it is?"* — single file / a few files / new module / new product area.
- *"Risk level?"* — low (internal, easy revert) / moderate (user-facing, some business logic) / high (payment, auth, migration, hard to revert).
- *"Do you have an existing discovery doc or spec already?"* — yes (with pointer) / no.

Skip questions the heuristic already answered. The goal is one or two questions, never a wall.

## Step 6: Choose and invoke the route

**The process tier (Step 3) drives the route; the bucket refines it.** Route by tier first:

- **quick-fix** → the **quick-fix execution path** below. No spec, no plan.
- **standard** → `/bee:planner` (it authors the plan, then hands to `/bee:plan-implementer`). No spec.
- **full** → `/bee:spec-writer` (it writes the spec, then hands to `/bee:planner`, which hands to `/bee:plan-implementer`).

START triages and routes; it does **not** author the spec or the plan itself. Those live in their own commands (`/bee:spec-writer`, `/bee:planner`) because a `Skill` handoff ends START's turn — START cannot run a step *after* it routes. The chain unfolds command-to-command: `start → spec-writer → planner → plan-implementer` (full); `start → planner → plan-implementer` (standard).

### quick-fix execution path

A `quick-fix` change is applied directly — no spec file, no plan file. Routing splits on whether the change is a bug. Both branches delegate to the **quick-fix** agent via Task at the `fast` tier (resolved via the `model-tiers` skill, passed explicitly as the Task `model` parameter — never inherit your own `best` session):

- **Bug** (Debug/diagnose or bug-fix bucket, or the user describes a defect): instruct the quick-fix agent with an explicit test-first instruction — **write a failing test that reproduces the bug before changing any code**, then make that test green. The bug is never patched without a reproducing test landing first.
- **Non-bug trivial change** (a small tweak the user already knows the shape of): the quick-fix agent applies the change directly. Add a test **only when the logic is non-trivial** — i.e. the change introduces or alters behavior a reader could get wrong. A pure rename, copy tweak, or config bump needs no test; a changed conditional or computed value does. State the test decision in one line when reporting.

For a trivial fix on no high-risk surface the user may still prefer the "skip Bee, fix manually" exit (confirm via `AskUserQuestion` as below).

### standard / full

Map the bucket from Step 4 (or `exploratory` if Step 5 hit the elicitation cap) to a route. Invoke the route's entry command via `Skill` directly with the structured context note from Step 7 — no intermediate confirmation. The single exception is the "skip Bee, fix manually" path: surface that one recommendation via `AskUserQuestion` (options: *Skip and fix manually / Route through Bee anyway*) because it exits the chain.

For multi-step routes, invoke only the **first** command. The chain unfolds naturally — discover's hand-off mentions spec-writer, spec-writer's mentions planner, etc.

## Step 6.5: Spec and plan are authored downstream (not in START)

START does **not** author the spec or the plan — it routes to the commands that do. This is deliberate: a `Skill` handoff ends START's turn, so any step placed *after* a handoff is unreachable. Spec authorship lives in `/bee:spec-writer`; plan authorship lives in `/bee:planner`. The plan is still authored **once, on the `best` tier** (planner runs at `best`) — just in its own command, not here.

The chain by tier:

- **quick-fix** — no spec, no plan; the quick-fix execution path above handles it directly.
- **standard** — `/bee:start` → `/bee:planner` → `/bee:plan-implementer`. Planner authors the plan from the triaged prompt + code context (no spec).
- **full** — `/bee:start` → `/bee:spec-writer` → `/bee:planner` → `/bee:plan-implementer`. spec-writer writes the spec, then hands to planner, which authors the plan and hands to plan-implementer.

Thread the triage signals forward in the Step 7 context note so planner (and spec-writer) inherit them: `Process tier`, `Risk`, `High-risk surface touched`. Planner re-derives them from the spec/code when invoked manually without a note. The plan artifact, its per-slice schema, the hard floors, and persistence to `docs/plans/` all live in `/bee:planner` — see that command.

## Step 7: Invoke the chosen command with the structured context note

Invoke via the `Skill` tool. The argument is a **structured prose block** — loose prose, not JSON; downstream commands read what they need without parsing a schema. Required format:

```
<user's original prompt verbatim>

---
ROUTED FROM /bee:start

Bucket: <bucket name from Step 4 table>
Process tier: <quick-fix | standard | full, from Step 3>
Risk: <LOW | MODERATE | HIGH>
High-risk surface touched by this change: <yes — category | no, from Step 3 floor check>
Codebase observations: <2-4 short bullets from Step 2's scan, if any; "none" if not in a repo>
Pointer: <URL or path if user provided one, else "none">
Design state: <greenfield | brownfield-no-system | brownfield-with-system | ambiguous | not-in-repo>
UI-touching: <yes | no>
Design direction: <summary of probe answers from Step 3.5, or "none — probe skipped">

Provisional elicitation questions (use, refine, or skip):
1. <Q1>
2. <Q2>
...
```

Rules:

- The block is required for every silent invocation. No exceptions.
- **Provisional elicitation questions** are the ones start *would* have asked if it kept asking — capture them here instead of asking the user. They land in discover (or whichever command is invoked) as a starting elicitation set, not a wall.
- The risk hint scales spec-writer's depth and plan-implementer's quality-check depth — propagate it accurately.
- **Design direction** carries the design probe answers forward so spec-writer and discover do not re-ask questions start already asked. When the probe was skipped, set it to `none — probe skipped` and let the downstream command decide whether to run its own probe.

For "skip Bee" routes (trivial fix on no high-risk surface, user picked "fix manually" in Step 6's `AskUserQuestion`): tell the user explicitly, suggest the manual-fix shape (which file, which test to add), then exit. Do not invoke a command, do not emit the context block.

## Rules

- **Render closed questions via `AskUserQuestion`** — yes/no, choose-one, binary. Plain-text numbered lists are a defect.
- **Cap elicitation (Step 5) at 2 closed questions.** Over the cap → invoke `/bee:discover` silently with the structured context block; do not ask a third. The design probe (Step 3.5) is separate and does not count toward this cap.
- **Invoke within-Bee routes silently** — brainstorm / discover / spec-writer / planner / plan-implementer all run directly via `Skill` with the structured context note. Only the "skip Bee, fix manually" path needs `AskUserQuestion` confirmation because it exits the system.
- **Detect high-risk context every run** — drives trivial-fix routing and the tier floor.
- **Routing is start's job; framing is the routed-to command's job** — never scope, frame, or pre-elicit on behalf of the downstream command. Capture provisional questions in the context block instead.
- **Read and triage, don't write.** start does not modify files and does not record state; the routed-to command does its own state writes.
- **One open question per turn.** Closed questions go through `AskUserQuestion` in the same turn.
