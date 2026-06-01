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
- Kill-gate evaluation, willing to recommend not pursuing
- Forces measurable user goals and structured non-goals
- Revision mode for post-delivery edits

Entry point: `/discovery:start`

### [Tracker Core](issuekit/) — Shared Adapter Layer

Auto-detects the active issue-tracker MCP (Azure DevOps, Jira) and exposes an abstract verb surface (`getIssue`, `addComment`, `transition`, `linkIssue`, ...). Declared as a dependency by `incident-postmortem` and `issue-triage`; Claude Code auto-installs it when you install either verb-plugin. Ships no MCP, no agent, no slash command — it's a library.

- Pattern-matches available tool names at session start; routes verbs to the resolved adapter
- Converts canonical markdown to vendor format (AzDO HTML or Jira ADF/markdown)
- Reads `.claude/tracker-policy.json`; lazy-prompts for missing keys and offers to persist the answer
- Owns the diff-and-confirm gate the verb-plugins use to batch writes

Entry point: pulled in transitively by the verb-plugins; no direct user invocation.

### [Incident Postmortem](incident-postmortem/) — Blameless Postmortem Generator

Paste an incident URL (Azure DevOps or Jira) and the agent gathers evidence from chat (Slack/Teams), the tracker, Datadog logs, and merged pull requests; reconstructs a chronological timeline with evidence tags; pauses for review; then writes a Google-SRE-style blameless postmortem.

- Two bundled skills: `incident-timeline-builder`, `postmortem-writer`
- Phase 3 confirmation gate before document generation
- Optional save to a configured output directory
- One slash command: `/incident-postmortem:run <URL or ID>`

Auto-installs `issuekit`.

Entry point: `/incident-postmortem:run <URL or ID>`

### [Issue Triage](issue-triage/) — End-to-End Triage Subagent

Paste any issue URL (Azure DevOps or Jira; Bug, Incident, Story, Feature, Task, or Spike) and the agent triages it end-to-end: assigns to you, transitions to investigating, runs the matching investigation skill, refines title and description, posts an assessment comment, sets severity + due date or sprint + story points, links related work, applies the triaged label, and posts a summary to the configured chat channel.

- Two bundled skills: `issue-refiner`, `requirements-investigator` (uses `issuekit:issue-investigator` for Bug/Incident)
- **Single always-on diff-and-confirm gate at Phase 3.** The diff is the dry-run.
- Graceful degradation when chat/doc/log MCPs are missing
- Two slash commands:
  - `/issue-triage:run <URL or ID>` — full workflow
  - `/issue-triage:investigate-and-refine <URL or ID>` — lightweight subset (no severity, transitions, sprints, comments, labels, or escalation)

Auto-installs `issuekit`.

Entry point: `/issue-triage:run <URL or ID>`

## Install

Add the marketplace once, then install the plugins you want:

```
/plugin marketplace add incubyte/ai-plugins

/plugin install bee@incubyte-plugins
/plugin install learn@incubyte-plugins
/plugin install discovery@incubyte-plugins
/plugin install incident-postmortem@incubyte-plugins
/plugin install issue-triage@incubyte-plugins
```

`incident-postmortem` and `issue-triage` declare `issuekit` as a dependency; Claude Code auto-installs it. Install `issuekit` directly only if you want the shared verb surface for some other purpose.

## Configure your MCPs

Plug-and-play in this suite = **`issuekit` + a verb-plugin + your own MCPs.** No plugin bundles a `.mcp.json`; you bring whatever you have.

### Required: at least one tracker MCP

- **Azure DevOps:** the official Microsoft Azure DevOps MCP server, [`@azure-devops/mcp`](https://github.com/microsoft/azure-devops-mcp).
- **Jira:** the Atlassian remote MCP (or a community Jira MCP that exposes the same tool surface).

Register the MCP at the user level (in `~/.claude.json`) or project level (in `.mcp.json` at your repo root). Example AzDO entry:

```json
{
  "mcpServers": {
    "azure-devops": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@azure-devops/mcp", "YOUR_ORG_SLUG"],
      "env": { "AZURE_DEVOPS_PAT": "${AZURE_DEVOPS_PAT}" }
    }
  }
}
```

Replace `YOUR_ORG_SLUG` with the slug from your AzDO URL (`https://dev.azure.com/<slug>`) and export `AZURE_DEVOPS_PAT` from your shell. PAT needs at least: Work Items (Read & Write), Code (Read), Wiki (Read), Identity (Read).

`issuekit` matches on tool-name **suffix** (`*__wit_get_work_item`, `*__getJiraIssue`, etc.), so it doesn't matter how the MCP is registered — pick whatever name you like.

When both an AzDO MCP and a Jira MCP are present, `issuekit` resolves the active tracker per-issue by inspecting the URL/key the user pastes.

### Optional MCPs the agents use opportunistically

| MCP | Used by | Behavior when missing |
|---|---|---|
| Slack or Teams | Both verb-plugins (chat search, escalation channel post) | Chat-search step skips silently; channel post falls back to inline summary |
| Confluence or Azure Wiki | Both verb-plugins (runbook / design-doc search) | Doc-search step skips silently |
| Datadog | Both verb-plugins (log search) | Log step skips silently |

No plug-in mention of an unavailable backend appears in any output.

## License

MIT
