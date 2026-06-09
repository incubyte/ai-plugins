# CCAF Mock Exam — Seed Question Bank

The 12 official sample questions from the CCAF exam guide, transcribed verbatim with their
official correct answers and explanations. These are **authoritative** (invariant 4.6): never
rewrite, re-key, or paraphrase. They seed assembled exams as anchors and are also the few-shot
style reference for generated questions.

Each entry: stable `id`, `source: official`, `domain` (D1–D5), `scenario` slug, `stem`, four
`options`, the `correct` letter, and the official `explanation`. The assembler may shuffle option
order at serve time (invariant 4.5); the `correct` letter here refers to the option text, not a
fixed position.

```yaml
questions:
  - id: official-01
    source: official
    domain: D1
    scenario: customer-support
    stem: >-
      Production data shows that in 12% of cases, your agent skips get_customer entirely and
      calls lookup_order using only the customer's stated name, occasionally leading to
      misidentified accounts and incorrect refunds. What change would most effectively address
      this reliability issue?
    options:
      A: Add a programmatic prerequisite that blocks lookup_order and process_refund calls until get_customer has returned a verified customer ID.
      B: Enhance the system prompt to state that customer verification via get_customer is mandatory before any order operations.
      C: Add few-shot examples showing the agent always calling get_customer first, even when customers volunteer order details.
      D: Implement a routing classifier that analyzes each request and enables only the subset of tools appropriate for that request type.
    correct: A
    explanation: >-
      When a specific tool sequence is required for critical business logic (like verifying
      customer identity before processing refunds), programmatic enforcement provides
      deterministic guarantees that prompt-based approaches cannot. Options B and C rely on
      probabilistic LLM compliance, which is insufficient when errors have financial
      consequences. Option D addresses tool availability rather than tool ordering, which is not
      the actual problem.

  - id: official-02
    source: official
    domain: D2
    scenario: customer-support
    stem: >-
      Production logs show the agent frequently calls get_customer when users ask about orders
      (e.g., "check my order #12345"), instead of calling lookup_order. Both tools have minimal
      descriptions ("Retrieves customer information" / "Retrieves order details") and accept
      similar identifier formats. What's the most effective first step to improve tool selection
      reliability?
    options:
      A: Add few-shot examples to the system prompt demonstrating correct tool selection patterns, with 5-8 examples showing order-related queries routing to lookup_order.
      B: Expand each tool's description to include input formats it handles, example queries, edge cases, and boundaries explaining when to use it versus similar tools.
      C: Implement a routing layer that parses user input before each turn and pre-selects the appropriate tool based on detected keywords and identifier patterns.
      D: Consolidate both tools into a single lookup_entity tool that accepts any identifier and internally determines which backend to query.
    correct: B
    explanation: >-
      Tool descriptions are the primary mechanism LLMs use for tool selection. When descriptions
      are minimal, models lack the context to differentiate between similar tools. Option B
      directly addresses this root cause with a low-effort, high-leverage fix. Few-shot examples
      (A) add token overhead without fixing the underlying issue. A routing layer (C) is
      over-engineered and bypasses the LLM's natural language understanding. Consolidating tools
      (D) is a valid architectural choice but requires more effort than a "first step" warrants
      when the immediate problem is inadequate descriptions.

  - id: official-03
    source: official
    domain: D5
    scenario: customer-support
    stem: >-
      Your agent achieves 55% first-contact resolution, well below the 80% target. Logs show it
      escalates straightforward cases (standard damage replacements with photo evidence) while
      attempting to autonomously handle complex situations requiring policy exceptions. What's
      the most effective way to improve escalation calibration?
    options:
      A: Add explicit escalation criteria to your system prompt with few-shot examples demonstrating when to escalate versus resolve autonomously.
      B: Have the agent self-report a confidence score (1-10) before each response and automatically route requests to humans when confidence falls below a threshold.
      C: Deploy a separate classifier model trained on historical tickets to predict which requests need escalation before the main agent begins processing.
      D: Implement sentiment analysis to detect customer frustration levels and automatically escalate when negative sentiment exceeds a threshold.
    correct: A
    explanation: >-
      Adding explicit escalation criteria with few-shot examples directly addresses the root
      cause: unclear decision boundaries. This is the proportionate first response before adding
      infrastructure. Option B fails because LLM self-reported confidence is poorly calibrated —
      the agent is already incorrectly confident on hard cases. Option C is over-engineered,
      requiring labeled data and ML infrastructure when prompt optimization hasn't been tried.
      Option D solves a different problem entirely; sentiment doesn't correlate with case
      complexity, which is the actual issue.

  - id: official-04
    source: official
    domain: D3
    scenario: code-generation
    stem: >-
      You want to create a custom /review slash command that runs your team's standard code
      review checklist. This command should be available to every developer when they clone or
      pull the repository. Where should you create this command file?
    options:
      A: In the .claude/commands/ directory in the project repository
      B: In ~/.claude/commands/ in each developer's home directory
      C: In the CLAUDE.md file at the project root
      D: In a .claude/config.json file with a commands array
    correct: A
    explanation: >-
      Project-scoped custom slash commands should be stored in the .claude/commands/ directory
      within the repository. These commands are version-controlled and automatically available to
      all developers when they clone or pull the repo. Option B (~/.claude/commands/) is for
      personal commands that aren't shared via version control. Option C (CLAUDE.md) is for
      project instructions and context, not command definitions. Option D describes a
      configuration mechanism that doesn't exist in Claude Code.

  - id: official-05
    source: official
    domain: D3
    scenario: code-generation
    stem: >-
      You've been assigned to restructure the team's monolithic application into microservices.
      This will involve changes across dozens of files and requires decisions about service
      boundaries and module dependencies. Which approach should you take?
    options:
      A: Enter plan mode to explore the codebase, understand dependencies, and design an implementation approach before making changes.
      B: Start with direct execution and make changes incrementally, letting the implementation reveal the natural service boundaries.
      C: Use direct execution with comprehensive upfront instructions detailing exactly how each service should be structured.
      D: Begin in direct execution mode and only switch to plan mode if you encounter unexpected complexity during implementation.
    correct: A
    explanation: >-
      Plan mode is designed for complex tasks involving large-scale changes, multiple valid
      approaches, and architectural decisions — exactly what monolith-to-microservices
      restructuring requires. It enables safe codebase exploration and design before committing
      to changes. Option B risks costly rework when dependencies are discovered late. Option C
      assumes you already know the right structure without exploring the code. Option D ignores
      that the complexity is already stated in the requirements, not something that might emerge
      later.

  - id: official-06
    source: official
    domain: D3
    scenario: code-generation
    stem: >-
      Your codebase has distinct areas with different coding conventions: React components use
      functional style with hooks, API handlers use async/await with specific error handling, and
      database models follow a repository pattern. Test files are spread throughout the codebase
      alongside the code they test (e.g., Button.test.tsx next to Button.tsx), and you want all
      tests to follow the same conventions regardless of location. What's the most maintainable
      way to ensure Claude automatically applies the correct conventions when generating code?
    options:
      A: Create rule files in .claude/rules/ with YAML frontmatter specifying glob patterns to conditionally apply conventions based on file paths
      B: Consolidate all conventions in the root CLAUDE.md file under headers for each area, relying on Claude to infer which section applies
      C: Create skills in .claude/skills/ for each code type that include the relevant conventions in their SKILL.md files
      D: Place a separate CLAUDE.md file in each subdirectory containing that area's specific conventions
    correct: A
    explanation: >-
      Option A is correct because .claude/rules/ with glob patterns (e.g., **/*.test.tsx) allows
      conventions to be automatically applied based on file paths regardless of directory
      location — essential for test files spread throughout the codebase. Option B relies on
      inference rather than explicit matching, making it unreliable. Option C requires manual
      skill invocation or relies on Claude choosing to load them, contradicting the need for
      deterministic "automatic" application based on file paths. Option D can't easily handle
      files spread across many directories since CLAUDE.md files are directory-bound.

  - id: official-07
    source: official
    domain: D1
    scenario: multi-agent-research
    stem: >-
      After running the system on the topic "impact of AI on creative industries," you observe
      that each subagent completes successfully, but the final reports cover only visual arts,
      completely missing music, writing, and film production. The coordinator's logs show it
      decomposed the topic into "AI in digital art creation," "AI in graphic design," and "AI in
      photography." What is the most likely root cause?
    options:
      A: The synthesis agent lacks instructions for identifying coverage gaps in the findings it receives from other agents.
      B: The coordinator agent's task decomposition is too narrow, resulting in subagent assignments that don't cover all relevant domains of the topic.
      C: The web search agent's queries are not comprehensive enough and need to be expanded to cover more creative industry sectors.
      D: The document analysis agent is filtering out sources related to non-visual creative industries due to overly restrictive relevance criteria.
    correct: B
    explanation: >-
      The coordinator's logs reveal the root cause directly: it decomposed "creative industries"
      into only visual arts subtasks (digital art, graphic design, photography), completely
      omitting music, writing, and film. The subagents executed their assigned tasks correctly —
      the problem is what they were assigned. Options A, C, and D incorrectly blame downstream
      agents that are working correctly within their assigned scope.

  - id: official-08
    source: official
    domain: D5
    scenario: multi-agent-research
    stem: >-
      The web search subagent times out while researching a complex topic. You need to design how
      this failure information flows back to the coordinator agent. Which error propagation
      approach best enables intelligent recovery?
    options:
      A: Return structured error context to the coordinator including the failure type, the attempted query, any partial results, and potential alternative approaches.
      B: Implement automatic retry logic with exponential backoff within the subagent, returning a generic "search unavailable" status only after all retries are exhausted.
      C: Catch the timeout within the subagent and return an empty result set marked as successful.
      D: Propagate the timeout exception directly to a top-level handler that terminates the entire research workflow.
    correct: A
    explanation: >-
      Structured error context gives the coordinator the information it needs to make intelligent
      recovery decisions — whether to retry with a modified query, try an alternative approach, or
      proceed with partial results. Option B's generic status hides valuable context from the
      coordinator, preventing informed decisions. Option C suppresses the error by marking failure
      as success, which prevents any recovery and risks incomplete research outputs. Option D
      terminates the entire workflow unnecessarily when recovery strategies could succeed.

  - id: official-09
    source: official
    domain: D2
    scenario: multi-agent-research
    stem: >-
      The synthesis agent frequently needs to verify specific claims while combining findings.
      Currently it returns control to the coordinator, which invokes the web search agent, then
      re-invokes synthesis — adding 2-3 round trips and 40% latency. 85% of these verifications
      are simple fact-checks (dates, names, statistics) while 15% require deeper investigation.
      What's the most effective approach to reduce overhead while maintaining reliability?
    options:
      A: Give the synthesis agent a scoped verify_fact tool for simple lookups, while complex verifications continue delegating to the web search agent through the coordinator.
      B: Have the synthesis agent accumulate all verification needs and return them as a batch to the coordinator at the end of its pass, which then sends them all to the web search agent at once.
      C: Give the synthesis agent access to all web search tools so it can handle any verification need directly without round-trips through the coordinator.
      D: Have the web search agent proactively cache extra context around each source during initial research, anticipating what the synthesis agent might need to verify.
    correct: A
    explanation: >-
      Option A applies the principle of least privilege by giving the synthesis agent only what it
      needs for the 85% common case (simple fact verification) while preserving the existing
      coordination pattern for complex cases. Option B's batching approach creates blocking
      dependencies since synthesis steps may depend on earlier verified facts. Option C
      over-provisions the synthesis agent, violating separation of concerns. Option D relies on
      speculative caching that cannot reliably predict what the synthesis agent will need to
      verify.

  - id: official-10
    source: official
    domain: D3
    scenario: claude-code-ci
    stem: >-
      Your pipeline script runs `claude "Analyze this pull request for security issues"` but the
      job hangs indefinitely. Logs indicate Claude Code is waiting for interactive input. What's
      the correct approach to run Claude Code in an automated pipeline?
    options:
      A: Add the -p flag: claude -p "Analyze this pull request for security issues"
      B: Set the environment variable CLAUDE_HEADLESS=true before running the command
      C: Redirect stdin from /dev/null
      D: Add the --batch flag: claude --batch "Analyze this pull request for security issues"
    correct: A
    explanation: >-
      The -p (or --print) flag is the documented way to run Claude Code in non-interactive mode.
      It processes the prompt, outputs the result to stdout, and exits without waiting for user
      input — exactly what CI/CD pipelines require. The other options reference non-existent
      features (CLAUDE_HEADLESS environment variable, --batch flag) or use Unix workarounds that
      don't properly address Claude Code's command syntax.

  - id: official-11
    source: official
    domain: D4
    scenario: claude-code-ci
    stem: >-
      Currently real-time Claude calls power two workflows: (1) a blocking pre-merge check that
      must complete before developers can merge, and (2) a technical debt report generated
      overnight. Your manager proposes switching both to the Message Batches API for its 50% cost
      savings. How should you evaluate this proposal?
    options:
      A: Use batch processing for the technical debt reports only; keep real-time calls for pre-merge checks.
      B: Switch both workflows to batch processing with status polling to check for completion.
      C: Keep real-time calls for both workflows to avoid batch result ordering issues.
      D: Switch both to batch processing with a timeout fallback to real-time if batches take too long.
    correct: A
    explanation: >-
      The Message Batches API offers 50% cost savings but has processing times up to 24 hours with
      no guaranteed latency SLA. This makes it unsuitable for blocking pre-merge checks where
      developers wait for results, but ideal for overnight batch jobs like technical debt reports.
      Option B is wrong because relying on "often faster" completion isn't acceptable for blocking
      workflows. Option C reflects a misconception — batch results can be correlated using
      custom_id fields. Option D adds unnecessary complexity when the simpler solution is matching
      each API to its appropriate use case.

  - id: official-12
    source: official
    domain: D4
    scenario: claude-code-ci
    stem: >-
      A pull request modifies 14 files. Your single-pass review analyzing all files together
      produces inconsistent results: detailed feedback for some files but superficial comments for
      others, obvious bugs missed, and contradictory feedback — flagging a pattern as problematic
      in one file while approving identical code elsewhere in the same PR. How should you
      restructure the review?
    options:
      A: Split into focused passes: analyze each file individually for local issues, then run a separate integration-focused pass examining cross-file data flow.
      B: Require developers to split large PRs into smaller submissions of 3-4 files before the automated review runs.
      C: Switch to a higher-tier model with a larger context window to give all 14 files adequate attention in one pass.
      D: Run three independent review passes on the full PR and only flag issues that appear in at least two of the three runs.
    correct: A
    explanation: >-
      Splitting reviews into focused passes directly addresses the root cause: attention dilution
      when processing many files at once. File-by-file analysis ensures consistent depth, while a
      separate integration pass catches cross-file issues. Option B shifts burden to developers
      without improving the system. Option C misunderstands that larger context windows don't
      solve attention quality issues. Option D would actually suppress detection of real bugs by
      requiring consensus on issues that may only be caught intermittently.
```

## Domain coverage of the seed bank

| Domain | Seed questions |
| ------ | -------------- |
| D1     | official-01, official-07 |
| D2     | official-02, official-09 |
| D3     | official-04, official-05, official-06, official-10 |
| D4     | official-11, official-12 |
| D5     | official-03, official-08 |

Scenarios covered by seeds: `customer-support`, `code-generation`, `multi-agent-research`,
`claude-code-ci` (4 of 6). The two uncovered scenarios — `developer-productivity`,
`structured-extraction` — are filled entirely by generated questions when selected.
