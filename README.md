# Incubyte Claude Plugins

A collection of Claude Code plugins by [Incubyte](https://incubyte.co).

## Plugins

### [Bee](bee/) — AI Development Workflow Navigator

Spec-driven development that scales process to match the task. Triages by size and risk, then navigates you through the right workflow: triage, context gathering, spec, architecture, code, test, verify, review.

- 10 commands, 26 specialist agents
- Session resume across conversations
- Design system awareness for UI work
- Collaboration loop with `@bee` inline annotations

Entry point: `/bee:sdd`

### [Learn](learn/) — Build to Learn

Learn any technology by building real projects. Claude guides you step-by-step — you write every line of code yourself.

- Project-based curriculum generation
- Adaptive pacing by skill level
- Progress tracking across sessions
- Knowledge checks with quizzes

Entry point: `/learn:start`

### [Second Brain](second-brain/) — Personal Knowledge Wiki

Builds a compounding wiki from raw documents. Drop articles into `clippings/`, ingest them into an Obsidian-compatible wiki with cross-references, then query your knowledge base with synthesized answers and citations.

- Parallel ingestion with delta detection
- Structured pages: concepts, entities, summaries
- Obsidian-compatible `[[wikilinks]]` and YAML frontmatter
- Presentation generation from answers

Entry point: `/second-brain:ingest`

### [Discovery](discovery/) — End-to-End Product Discovery

Take a raw product idea through ten guided phases and walk away with a structured PRD. Pushes back on vague metrics, refuses to write PRDs for ideas that should die.

- 10 phases (context → scope → competition → journeys → wireframes → mockups → epics → tech → metrics → GTM → assembly)
- Resumable across sessions via `discovery-state.md`
- Kill-gate evaluation — willing to recommend not pursuing
- Forces measurable user goals and structured non-goals
- Revision mode for post-delivery edits

Entry point: `/discovery:start`

### [Jira Issue Triage](jira-issue-triage/) — End-to-End Jira Triage Subagent

Paste any Jira ticket URL (Bug, Incident, Feature, Task, or Spike) and the agent triages it end-to-end: assigns to you, transitions to investigating, runs the matching investigation skill, drafts the assessment comment, refines title and description, applies the triaged label, and DMs a one-line summary on Slack.

- Archetype-aware workflow (Bug, Incident, Feature, Task, Spike)
- Bundles four skills: `issue-investigator`, `requirements-investigator`, `jira-ticket-refiner`, `prose-style`
- `/jira-issue-triage:setup` wizard for first-time configuration
- Phase 3 confirmation gate — preview every change before it lands in Jira
- Graceful degradation when Slack or Datadog MCP servers are missing

Entry point: paste a Jira URL and ask the agent to triage it (subagent: `jira-issue-triage`)

## Install

```bash
# Add the Incubyte marketplace
/plugin marketplace add incubyte/ai-plugins

# Install a plugin
/plugin install bee@incubyte-plugins
/plugin install learn@incubyte-plugins
/plugin install discovery@incubyte-plugins
/plugin install jira-issue-triage@incubyte-plugins
```

## License

See individual plugin directories for license details.
