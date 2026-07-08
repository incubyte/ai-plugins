# Bee

Bee is a Claude Code plugin that brings spec-driven engineering discipline to AI-assisted development — automatically scaling process to match the task.

**Why this exists.** Incubyte is a 140+ engineer software consultancy built on eXtreme Programming and software craftsmanship. We noticed AI coding tools are fast but undisciplined — they skip specs, ignore architecture, and produce code without tests. Bee encodes the engineering discipline our team practices daily into a plugin any developer can use with Claude Code.

**What makes it different.** Bee is process-aware, not just code-aware. It triages every task by size and risk, then navigates you through exactly the right amount of rigor — a typo gets fixed immediately, a payment flow gets a full spec, architecture review, and verification. No other Claude Code plugin delivers triage → spec → architecture → code → test → verify → review as one coherent workflow.

**What you get.** 10 commands, 27 specialist agents, design system awareness, session resume, and artifacts that capture _why_ things were built — not just _what_. From onboarding new devs to migrating legacy systems to coaching your AI workflow habits.

> The developer is the driver. Claude Code is the car. Bee is the GPS.

Bee doesn't enforce process — it suggests. The developer always has final say.

## The Workflow

For features and epics, Bee navigates you through these phases:

```
"Tell me what we're working on"
         |
         v
   [ TRIAGE ]        Assess size + risk. Route to the right workflow.
         |
         v
   [ CONTEXT ]       Read the codebase. Understand patterns, conventions,
         |            and design system signals.
         v
   [ TIDY ]          (Optional) Clean up the area before building. Separate commit.
         |
         v
   [ DESIGN ]        (When UI involved) Produce a design brief from the existing
         |            design system or interview for greenfield projects.
         v
   [ DISCOVERY ]     (When needed) Explore requirements when scope is uncertain.
         |
         v
   [ SPEC ]          Interview the developer. Build testable, design-aware
         |            acceptance criteria.
         v
   [ ARCHITECTURE ]  Evaluate options when warranted. Most tasks: follow existing patterns.
         |
         v
   For each slice:
   [ CODE ]  -->  [ TEST ]  -->  [ VERIFY ]  -->  [ next slice ]
         |
         v
   [ REVIEW ]        Full picture. Risk-aware ship recommendation.
```

### Design Awareness

Bee detects UI signals in the codebase — frontend frameworks, Tailwind configs, CSS custom properties, component libraries, design tokens. When UI work is detected:

- **Existing design system**: Bee extracts the color palette, typography, spacing, component patterns, and accessibility constraints into a design brief (`.claude/DESIGN.md`). All downstream work is constrained to the existing system — no invented colors, no off-system components.
- **Greenfield**: Bee interviews the developer about visual preferences (mood, brand colors, reference sites, logo) and proposes a cohesive design direction grounded in accessibility and design principles.

The design brief is a project-level artifact. It's created once and referenced by every subsequent UI task, so the project maintains a consistent visual language.

### Collaboration Loop

After discovery, spec, design brief, and architecture documents are produced, you can review them in your editor. Add `@bee` inline comments to request changes. Mark `[x] Reviewed` at the bottom to proceed. Type `check` when you're ready for Bee to re-read, or just keep chatting — Bee won't block the conversation while you review.

### Session Resume

Close your terminal mid-feature? No problem. Bee persists progress in `.claude/bee-state.local.md`. Next time you run `/bee:sdd`, it picks up exactly where you left off — including design brief status, discovery doc path, current phase, and slice progress.

## Install

On Copilot CLI and Claude Code run this and you're good to go:

```bash
# Add the Incubyte marketplace
/plugin marketplace add incubyte/claude-plugins

# Install Bee
/plugin install bee@incubyte-plugins
```

> Make sure to restart your tool after installing the plugin

### Cursor Support

Cursor doesn’t support Claude-style plugins. To use Bee in Cursor on this machine:

1. **Symlink** Bee into Cursor’s config (so any project can use it):
   ```bash
   ln -snf /path/to/repo/claude-plugins/bee/.cursor/ ~/.config/Cursor/bee
   ```
2. **Add the Bee rule** — copy `.cursor/bee-workflow.mdc` into your project’s `.cursor/rules/`, or add it as a User rule in **Settings → Rules, Skills, Subagents** (see **cursor-integration/README.md**).

Then in any project you can say **bee-sdd**, **bee discover**, or **bee review** in chat to start the same workflows.

## Usage

### `/bee:sdd` — The Main Event

**What it is:** Spec-driven development that codifies engineering discipline as a command. Works with or without a pre-built spec. Code first, test after — per slice. Architecture advisor establishes testable structure, slice-coder writes production code, slice-tester writes tests, sdd-verifier gates quality.

**Why it matters:** AI writes better code when it has clear targets. A 10-minute spec means the AI doesn't guess your requirements. Verification after each slice means nothing ships untested. After shipping, Bee offers a walkthrough of what was built — files, core logic, tests, and key decisions — so you understand the code you now own. Bee makes that the path of least resistance.

**How it works:** Tell it what you want to build, or pass a spec path. Bee assesses size and risk, then navigates you through exactly the right amount of process — no more, no less.

| Task size            | What Bee does                                         |
| -------------------- | ----------------------------------------------------- |
| Typo / config fix    | Just fixes it                                         |
| Small bug / UI tweak | Quick confirmation, then builds                       |
| New feature          | Spec, architecture, code, test, verify, review        |
| Epic / new subsystem | Breaks into shippable phases, full workflow per phase |

```
/bee:sdd add user authentication
```

Or pass a pre-built spec to skip straight to building:

```
/bee:sdd docs/specs/feature.md
```

Or start without a task — Bee asks what you're working on:

```
/bee:sdd
```

Picks up where you left off across sessions. Close your terminal mid-feature, come back later, it resumes.

**Working with Bee during SDD:**

Bee produces documents along the way — discovery docs, specs, architecture recommendations. After each one, you review it in your editor. Two things to know:

1. **`@bee` annotations** — Add `@bee` followed by your comment on any line you want changed (e.g., `@bee this AC is too vague`). Type `check` in the chat and Bee reads your annotations, makes the changes, and leaves a comment card showing what it did.

2. **`[x] Reviewed`** — Every doc ends with a `[ ] Reviewed` checkbox. Mark it `[x] Reviewed` when you're happy with the doc to move to the next phase. Unresolved comment cards don't block — it's a trust-based gate.

You're never locked in. Ask questions, go off-topic, or push back at any point — Bee won't block the conversation while you review.

### `/bee:start` — Dynamic, plan-driven orchestration

```
/bee:start add rate limiting to the API
/bee:start docs/specs/feature-spec.md
```

A cost/risk-aware sibling of `/bee:sdd`. Where `/bee:sdd` runs a fixed agent loop at fixed models, the plan-driven chain — **`/bee:start` → `/bee:spec-writer` → `/bee:planner` → `/bee:plan-implementer`** — matches effort and cost to risk. `/bee:start` is the only command most people ever type; it routes through the chain automatically.

1. **`/bee:start` triages and routes** — classifies the work into a bucket (debug / bug-fix / small / larger / brainstorm / exploratory / artifact pointer) and a *process tier*: **quick-fix** (direct change, handled right there — bugs test-first), **standard** (plan, no spec → planner), or **full** (spec + plan → spec-writer). HIGH-risk or high-risk-surface changes are always floored to **full**. Runs a design probe for UI work, caps elicitation at 2 questions (overflow routes to `/bee:discover`), and passes a structured `ROUTED FROM` note downstream. Stateless — it reads and routes, never writes.
2. **`/bee:spec-writer` authors the spec** (full tier) via the spec-builder agent — intent only, no tiers or routing — runs the collaboration loop, and hands off. Re-runnable to revise or extend a spec.
3. **`/bee:planner` authors the plan** once, on the strongest model — and is **re-runnable against the same spec to revise a plan**. The plan is a prescriptive artifact at `docs/plans/[feature]-plan.md` that carries, per slice: design intent, structure (names + signatures, never bodies), collaborators, control-flow shape, a decided test strategy, craft-skill standards to honor, a **build tier** (`best` / `excellent` / `fast`), and verifiable quality checks. Technical unknowns are researched at plan time (WebFetch/WebSearch), never punted to the executor. Hard floors are marked as the final authoring step.
4. **`/bee:plan-implementer` executes** — one **slice-builder** spawn per slice (plan-specified tests red → code green → scoped run → commit, in one warm context; the scoped green run is the slice gate), each at the slice's planned tier with a **one-way escalation ratchet**. Then, once at end-of-spec: a single parallel review pass over the whole diff (the risk-aware `reviewer` plus plan-selected `review-*` dimensions — never a per-slice fleet, floors enforced at ≥ `excellent`), the full-suite gate, and one browser-verification pass for UI specs (findings close only on re-verification). Point it at any plan directly: `/bee:plan-implementer docs/plans/feature-plan.md`.

Models are referenced only by capability tier — the `best`/`excellent`/`fast` → concrete-model mapping lives in exactly one place, the **`model-tiers`** skill, so the workflow adapts as the model lineup moves without touching any agent or command. Specs carry intent only; the plan carries the *how*. The merged **slice-builder** agent belongs to this chain only; `/bee:sdd` and its slice-coder → slice-tester loop are untouched.

### Standalone Commands

```
/bee:discover
```

A PM persona that interviews you (or synthesizes from meeting transcripts) and produces a client-shareable PRD. Works standalone for early-stage requirement exploration, or let `/bee:sdd` invoke it automatically when decision density is high.

```
/bee:review
```

Standalone code review with hotspot analysis, tech debt prioritization, and developer coaching. Independent of the build workflow — no spec or triage needed. Point it at a file, directory, or PR.

```
/bee:qc
/bee:qc 42
```

Quality coverage analysis — finds hotspots (high-churn × high-complexity × many-author files), inventories existing tests, and produces a prioritized test plan at `docs/specs/qc-plan.md`. Follows the test pyramid: unit tests first, integration where necessary. When code isn't testable, proposes specific refactoring. Full codebase mode produces a plan; PR mode (`/bee:qc <PR-id>`) auto-executes refactoring and test creation with verification at every step.

```
/bee:architect
```

Architectural health assessment grounded in domain language. Compares how a product describes itself (README, docs, website, marketing copy) against how the code is structured. Produces an assessment report with domain vocabulary mapping, boundary analysis, and runnable ArchUnit-style boundary tests — some passing (documenting good boundaries) and some intentionally failing (flagging architecture leaks).

```
/bee:onboard
```

Interactive developer onboarding for existing projects. Analyzes the codebase and delivers an adaptive walkthrough — architecture, entry points, domain concepts, tribal knowledge, dragons, and how to run/test/deploy. Adapts to the developer's role, experience level, and focus area. Includes MCQ knowledge checks.

```
/bee:migrate /path/to/legacy /path/to/new-app
```

Analyze a legacy and new codebase to produce a prioritized, independently-shippable migration plan. Reads both codebases, interviews you about goals, and writes a plan where each unit is a clean PR. Read-only — produces a plan, not code.

```
/bee:coach
```

Analyze your Claude Code sessions and get actionable coaching insights — workflow adoption, prompt quality, session efficiency, and code quality signals. Tracks trends over time.

```
/bee:help
```

Interactive guided tour of all Bee commands. Adapts to your project context — if Bee has already produced specs or state files, it shows what's been done. If it's a fresh project, it suggests where to start.

## How It Works

Bee assesses every task on two axes — **size** and **risk** — then recommends the right workflow.

### Size

| Size    | What it looks like                   | Bee's approach                                      |
| ------- | ------------------------------------ | --------------------------------------------------- |
| TRIVIAL | Typo, config change, one-liner       | Fix it immediately                                  |
| SMALL   | Single-file bug, UI tweak            | Quick confirmation, then build                      |
| FEATURE | New endpoint, new screen, multi-file | Spec, architecture, code, test, verify, review      |
| EPIC    | New subsystem, cross-cutting concern | Discovery, phased delivery, full workflow per phase |

### Risk

| Risk     | Examples                       | Effect on workflow                                            |
| -------- | ------------------------------ | ------------------------------------------------------------- |
| LOW      | Internal tool, easy to revert  | Lighter spec, simpler verification                            |
| MODERATE | User-facing, business logic    | Standard spec, thorough verification, team review recommended |
| HIGH     | Payments, auth, data migration | Thorough spec, defensive verification, feature flag + QA      |

## Artifacts Produced

| Artifact       | Location                                   | Purpose                                           |
| -------------- | ------------------------------------------ | ------------------------------------------------- |
| Design Brief   | `.claude/DESIGN.md`                        | Project-level visual constraints for UI work      |
| Specs          | `docs/specs/[feature]-spec.md`             | Requirements with acceptance criteria             |
| Discovery Docs | `docs/specs/[feature]-discovery.md`        | Problem statement, hypotheses, milestone map      |
| ADRs           | `docs/adrs/NNN-[decision].md`              | Architecture decisions with rationale             |
| State          | `.claude/bee-state.local.md`               | Session resume tracking                           |

These artifacts are knowledge capture — when a new developer joins, they can read the specs, discovery docs, and design brief to understand not just what was built, but why and how.

## Agents

Bee ships with 27 specialist agents:

| Agent                       | Role                                                                         |
| --------------------------- | ---------------------------------------------------------------------------- |
| `quick-fix`                 | Handle trivial fixes end-to-end                                              |
| `context-gatherer`          | Read codebase — patterns, conventions, and design system signals             |
| `tidy`                      | Clean up the area before building                                            |
| `design-agent`              | Produce a design brief from existing design systems or greenfield interviews |
| `discovery`                 | PM persona that interviews users and produces a client-shareable PRD         |
| `spec-builder`              | Interview developer, write testable and design-aware specs                   |
| `architecture-advisor`      | Evaluate architecture options, YAGNI check                                   |
| `architecture-impl-advisor` | SDD architecture advisor — establishes testable structure                     |
| `slice-coder`               | Code a single slice per spec and architecture                                |
| `slice-tester`              | Write tests for a completed slice                                            |
| `sdd-verifier`              | SDD quality gate — test quality, AC validation, pattern checks               |
| `slice-builder`             | Merged build agent for one plan slice — tests red → code green → commit (plan-driven chain only) |
| `tdd-planner-onion`         | Outside-in TDD for onion/hexagonal architecture (used by ping-pong)          |
| `tdd-planner-mvc`           | Layer-by-layer TDD for MVC codebases (used by ping-pong)                     |
| `tdd-planner-cqrs`          | Split command/query TDD for CQRS systems (used by ping-pong)                 |
| `tdd-planner-event-driven`  | Contract-first TDD for event-driven systems (used by ping-pong)              |
| `tdd-planner-simple`        | Straightforward test-implement-verify (used by ping-pong)                    |
| `verifier`                  | Post-slice quality gate (used by ping-pong)                                  |
| `reviewer`                  | Final review with ship recommendation                                        |
| `browser-verifier`          | Browser-based AC verification via Chrome MCP                                 |
| `domain-language-extractor` | Extract domain vocabulary; flag vocabulary drift                             |
| `architecture-test-writer`  | Generate runnable ArchUnit-style boundary tests                              |
| `onboard`                   | Interactive developer onboarding                                             |
| `qc-planner`                | Synthesize review outputs into a prioritized test plan                       |
| `review-code-quality`       | SRP, DRY, YAGNI, naming review                                               |
| `review-coupling`           | Import dependencies, change amplifiers                                       |
| `review-tests`              | Test quality, coverage gaps                                                  |
| `review-behavioral`         | Git hotspots, temporal coupling                                              |
| `review-team-practices`     | Commit messages, PR review substance                                         |
| `review-org-standards`      | Project CLAUDE.md conventions                                                |
| `review-ai-ergonomics`      | LLM-friendliness review                                                      |
| `recap`                     | Walk through what was built — files, core logic, tests, decisions            |

## Skills

Shared reference knowledge that agents draw on. Skills are imported via frontmatter — agents declare which skills they need, and the content is preloaded at startup.

- **clean-code** — SRP, DRY, YAGNI, naming, error handling
- **tdd-practices** — Red-green-refactor, outside-in, test quality
- **architecture-patterns** — When to use onion vs MVC vs simple
- **spec-writing** — Acceptance criteria, vertical slicing, adaptive depth
- **design-fundamentals** — Accessibility rules, typography, spacing, responsive breakpoints
- **debugging** — Systematic diagnosis: read before you change, assume nothing, trial and error is last resort
- **ai-workflow** — Why spec-first TDD produces better AI-generated code
- **collaboration-loop** — Inline review with `@bee` annotations
- **code-review** — Review methodology, hotspot analysis, coupling detection
- **ai-ergonomics** — Making code LLM-friendly
- **lsp-analysis** — LSP-enhanced dependency analysis, graceful degradation
- **browser-testing** — Chrome MCP tool reference, screenshot conventions

## Project Structure

```
bee/
├── .claude-plugin/
│   └── plugin.json               # Plugin manifest
├── commands/
│   ├── sdd.md                     # /bee:sdd orchestrator
│   ├── coach.md                   # /bee:coach session coaching insights
│   ├── architect.md              # /bee:architect architecture assessment
│   ├── discover.md               # /bee:discover standalone discovery
│   ├── help.md                    # /bee:help interactive guided tour
│   ├── migrate.md                 # /bee:migrate migration planning
│   ├── onboard.md                # /bee:onboard interactive developer onboarding
│   ├── qc.md                     # /bee:qc quality coverage analysis
│   └── review.md                 # /bee:review standalone code review
├── agents/
│   ├── quick-fix.md
│   ├── context-gatherer.md
│   ├── tidy.md
│   ├── design-agent.md
│   ├── discovery.md
│   ├── spec-builder.md
│   ├── architecture-advisor.md
│   ├── tdd-planner-onion.md
│   ├── tdd-planner-mvc.md
│   ├── tdd-planner-cqrs.md
│   ├── tdd-planner-event-driven.md
│   ├── tdd-planner-simple.md
│   ├── verifier.md
│   ├── reviewer.md
│   ├── browser-verifier.md
│   ├── domain-language-extractor.md
│   ├── architecture-test-writer.md
│   ├── onboard.md
│   ├── qc-planner.md
│   ├── review-code-quality.md
│   ├── review-coupling.md
│   ├── review-tests.md
│   ├── review-behavioral.md
│   ├── review-team-practices.md
│   ├── review-org-standards.md
│   └── review-ai-ergonomics.md
├── skills/
│   ├── clean-code/
│   ├── tdd-practices/
│   ├── architecture-patterns/
│   ├── spec-writing/
│   ├── design-fundamentals/
│   ├── debugging/
│   ├── ai-workflow/
│   ├── collaboration-loop/
│   ├── code-review/
│   ├── ai-ergonomics/
│   ├── lsp-analysis/
│   └── browser-testing/
├── docs/
│   ├── specs/                    # Generated specs, discovery docs, state
│   └── adrs/                    # Architecture Decision Records
├── CLAUDE.md                     # Bee personality + conventions
└── README.md
```

## Design Decisions

**Why `/bee:sdd` is a command, not an agent.** Claude Code subagents cannot spawn other subagents. Since the orchestrator delegates to 14 agents, it must run as a command in the main conversation context.

**Navigator, not enforcer.** Bee suggests the right process but never blocks. Say "just code it" and Bee asks one clarifying question, then proceeds.

**Risk flows downstream.** A HIGH risk triage means deeper specs, more defensive tests, and stricter review recommendations. LOW risk means lighter everything. The developer doesn't have to think about calibration — Bee handles it.

**Design is project-level, not task-level.** The design brief (`.claude/DESIGN.md`) is created once and persists across features. A TRIVIAL CSS fix and an EPIC redesign reference the same brief. This keeps the project visually consistent without re-deriving the design system every time.

**Design and discovery are independent.** Both consume the context-gatherer output, but neither blocks the other. Design triggers on UI involvement. Discovery triggers on decision density. A task can need both, one, or neither.

## License

MIT
