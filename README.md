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

### [Jira Issue Triage](jira-issue-triage/) — End-to-End Jira Triage Subagent

Paste any Jira ticket URL (Bug, Incident, Feature, Task, or Spike) and the agent triages it end-to-end: assigns to you, transitions to investigating, runs the matching investigation skill, drafts the assessment comment, refines title and description, applies the triaged label, and DMs a one-line summary on Slack.

- Archetype-aware workflow (Bug, Incident, Feature, Task, Spike)
- Bundles four skills: `issue-investigator`, `requirements-investigator`, `jira-ticket-refiner`, `prose-style`
- Phase 3 confirmation gate, preview every change before it lands in Jira
- Graceful degradation when Slack or Datadog MCP servers are missing
- Two slash commands:
  - `/jira-issue-triage:setup`: first-time configuration wizard
  - `/jira-issue-triage:investigate-and-refine <TICKET>`: one-shot investigate + refine + post; skips severity, transitions, sprints, labels, and Slack DM

Entry point: paste a Jira URL and ask the agent to triage it (subagent: `jira-issue-triage`)

### [Azure Issue Triage](azure-issue-triage/) — End-to-End Azure DevOps Triage Subagent

Sibling of `jira-issue-triage` for Azure DevOps Boards. Paste any work-item URL (Bug, Incident, User Story, Feature, Task, or Spike) and the agent triages it end-to-end: assigns, runs the matching investigation skill, refines `System.Title` and `System.Description`, posts an archetype-appropriate comment, writes severity + SLA-driven due date on Bug/Incident, places User Story / Feature / Task / Spike into the team's active sprint, prompts for story-point estimates, links Azure Repos pull requests, routes high-severity escalations to Microsoft Teams, and falls back to the reporter's EM when the reporter is deactivated.

- Archetype-aware across all six archetypes (Bug, Incident, User Story, Feature, Task, Spike)
- Bundles four skills: `azure-issue-investigator`, `azure-requirements-investigator`, `azure-work-item-refiner`, `prose-style`
- Phase 3 confirmation gate before any write
- Graceful degradation when Microsoft Teams or Datadog MCP servers are missing
- Two slash commands:
  - `/azure-issue-triage:setup`: first-time configuration wizard
  - `/azure-issue-triage:investigate-and-refine <work-item URL or ID>`: one-shot investigate + refine + post; skips severity, transitions, sprints, story points, PR linking, and Teams summary

Requires the Azure DevOps MCP server. See [Configure Azure DevOps MCP](#configure-azure-devops-mcp) below before first run.

Entry point: paste an Azure DevOps work-item URL and ask the agent to triage it (subagent: `azure-issue-triage`)

### [Azure Incident Postmortem](azure-incident-postmortem/) — Blameless Postmortem Generator

Paste an Azure DevOps incident work-item URL and the agent gathers evidence from Microsoft Teams threads, related work items, Datadog logs, and Azure Repos pull-request merges; reconstructs a chronological timeline with evidence tags; pauses for review; then writes a Google-SRE-style blameless postmortem (summary, impact, timeline, root cause, contributing factors, what went well/wrong, action items, lessons learned, references). Read-only on AzDO in v0.1.0.

- Three bundled skills: `incident-timeline-builder`, `postmortem-writer`, `prose-style`
- Phase 3 confirmation gate before document generation
- Optional save to a configured output directory
- One slash command: `/azure-incident-postmortem:setup`

Requires the Azure DevOps MCP server. See [Configure Azure DevOps MCP](#configure-azure-devops-mcp) below before first run.

Entry point: paste an Azure DevOps incident URL and ask the agent for a postmortem (subagent: `azure-incident-postmortem`)

## Install

Add the marketplace once, then install the plugins you want:

```
/plugin marketplace add incubyte/ai-plugins

/plugin install bee@incubyte-plugins
/plugin install learn@incubyte-plugins
/plugin install discovery@incubyte-plugins
/plugin install jira-issue-triage@incubyte-plugins
/plugin install azure-issue-triage@incubyte-plugins
/plugin install azure-incident-postmortem@incubyte-plugins
```

After installing the Jira plugin, run `/jira-issue-triage:setup` once to write `.claude/jira-issue-triage.config.json` (Jira base URL, project keys, severity field, etc.).

After installing either Azure plugin, run its `:setup` command and read [Configure Azure DevOps MCP](#configure-azure-devops-mcp) below.

## Configure Azure DevOps MCP

Both Azure plugins (`azure-issue-triage` and `azure-incident-postmortem`) need the official Microsoft Azure DevOps MCP server, [`@azure-devops/mcp`](https://github.com/microsoft/azure-devops-mcp), to read work items, run WIQL queries, post comments, and look up pull requests.

Each plugin ships its own `.mcp.json` so they don't share state. The two server names are deliberately distinct so both plugins can be enabled at once without collision:

| Plugin | MCP server name | Tool prefix |
|---|---|---|
| `azure-issue-triage` | `azure-devops-triage` | `mcp__azure_devops_triage__*` |
| `azure-incident-postmortem` | `azure-devops-postmortem` | `mcp__azure_devops_postmortem__*` |

### The shipped config is Rolai-shaped

Read this before installing. Both `.mcp.json` files are hardcoded to the Rolai dev workflow:

```json
{
  "mcpServers": {
    "azure-devops-triage": {
      "type": "stdio",
      "command": "bash",
      "args": [
        "-c",
        "export AZURE_DEVOPS_PAT=$(dotenvx get AZURE_DEVOPS_PAT -f server/.env) && npx -y @azure-devops/mcp rolaillc"
      ]
    }
  }
}
```

Three assumptions are baked in:

1. Organization slug is `rolaillc`.
2. PAT lives in `server/.env` (relative to the Claude Code launch directory), encrypted with [dotenvx](https://dotenvx.com/), with a matching `.env.keys` available for decryption.
3. `dotenvx` is on `PATH`.

If you work at Rolai with the standard `server/.env` + `.env.keys` setup, the plugin is plug-and-play. Run it as installed.

### If you're not at Rolai: override the MCP locally

Override by registering an MCP server with the same name at the project root, which takes precedence over the plugin-shipped file.

1. Create a Personal Access Token in Azure DevOps with at least these scopes: Work Items (Read & Write), Code (Read), Wiki (Read), Identity (Read).

2. Create `.mcp.json` at the root of your project (the directory you launch Claude Code from), one server entry per plugin you've installed:

   ```json
   {
     "mcpServers": {
       "azure-devops-triage": {
         "type": "stdio",
         "command": "npx",
         "args": ["-y", "@azure-devops/mcp", "YOUR_ORG_SLUG"],
         "env": {
           "AZURE_DEVOPS_PAT": "YOUR_PAT_HERE"
         }
       },
       "azure-devops-postmortem": {
         "type": "stdio",
         "command": "npx",
         "args": ["-y", "@azure-devops/mcp", "YOUR_ORG_SLUG"],
         "env": {
           "AZURE_DEVOPS_PAT": "YOUR_PAT_HERE"
         }
       }
     }
   }
   ```

   Replace `YOUR_ORG_SLUG` with the slug from your AzDO URL (`https://dev.azure.com/<slug>`) and `YOUR_PAT_HERE` with the token. Only include the server names for plugins you've installed.

3. Don't commit `.mcp.json` if it contains a literal PAT. Add it to `.gitignore`, or read the PAT from your shell environment instead:

   ```json
   "env": { "AZURE_DEVOPS_PAT": "${AZURE_DEVOPS_PAT}" }
   ```

   and export `AZURE_DEVOPS_PAT` from your shell rc file.

4. Reload Claude Code. Both plugin agents should pick up your override on next launch.

### Optional MCP servers

Both Azure plugins gracefully degrade if these are missing, so you don't need them to get started:

- **Microsoft Teams MCP server.** Used for Phase 1 evidence search and (in `azure-issue-triage`) the Phase 10 summary message. No first-party server exists yet. Community options include [InditexTech/mcp-teams-server](https://github.com/InditexTech/mcp-teams-server) and [msfeldstein/MCP-MS-Teams](https://github.com/msfeldstein/MCP-MS-Teams).
- **Datadog MCP server.** Used for log search on Bug/Incident archetypes and during incident postmortem evidence gathering. The agent skips Datadog steps silently if it's not registered.

Add either to the project `.mcp.json` alongside the Azure DevOps entries.

## License

See individual plugin directories for license details.
