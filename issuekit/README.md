# issuekit

Shared adapter layer for issue-tracker plugins in this marketplace. `incident-postmortem` and `issue-triage` both depend on it.

This plugin ships **no** MCP, **no** agent, and **no** slash command. It is a library of skills and reference files that the verb-plugins invoke.

## What it provides

- **Auto-detection.** Pattern-matches the available MCP tool surface and classifies the active tracker (Azure DevOps, Jira), chat backend (Slack, Teams), doc backend (Confluence, Azure Wiki), and log backend (Datadog).
- **Abstract verb surface.** One contract for both vendors: `getIssue`, `getIssueHistory`, `getIssueComments`, `searchIssues`, `getIssueTypeSchema`, `linkedPullRequests`, `getCurrentSprint`, `whoAmI`, `resolveUser`, `mention`, `assign`, `transition`, `updateFields`, `addComment`, `addLabel`, `removeLabel`, `linkIssue`, `linkPullRequest`.
- **Body-format conversion.** Verb-plugins author in markdown with the reserved token `@[userRef]` for mentions. The adapter projects that down to AzDO HTML or Jira-flavored markdown before writing.
- **Policy schema.** Reads `.claude/tracker-policy.json`; lazy-prompts for any missing key at the moment it's needed; offers to persist the answer.
- **Diff-and-confirm contract.** A single batched diff format that both verb-plugins reuse to gate every write.
- **Two utility skills:** `prose-style` (writing-style audit/rewrite) and `issue-investigator` (Bug/Incident orientation report).

## What it does NOT provide

- No MCP server. Bring your own: the official `@azure-devops/mcp`, the Atlassian MCP, or any sibling that exposes the same tool surface.
- No agent. The verb-plugins own agent prompts.
- No slash command. Missing policy keys are lazy-prompted on first use and optionally persisted to `.claude/tracker-policy.json`.

## Install

You don't install this directly — it's declared as a `dependencies` entry on `incident-postmortem` and `issue-triage`, so Claude Code auto-installs it whenever you install either verb-plugin. To install it on its own:

```
/plugin install issuekit@incubyte-plugins
```

You also need at least one tracker MCP (`@azure-devops/mcp` or the Atlassian MCP) configured at the user or project level. See each verb-plugin's README for the chat/doc/log MCPs it can use opportunistically.

## Plug-and-play contract

**Plug-and-play in this suite = `issuekit` + a verb-plugin + your own MCPs.** No bundled `.mcp.json`, no hardcoded org names. The tracker-adapter skill pattern-matches available tool names at session start and routes verbs to the right adapter.

## Detection rules

See [`skills/tracker-adapter/references/detection.md`](skills/tracker-adapter/references/detection.md) for the full table. Quick reference:

| Tool name pattern | Adapter |
|---|---|
| `*__getJiraIssue` / `*__editJiraIssue` | Jira |
| `*__wit_get_work_item` / `*__wit_update_work_item` | Azure DevOps |
| `*__slack_search_*` | Slack |
| `*__teams_search_messages` | Teams |
| `*__searchConfluenceUsingCql` | Confluence |
| `*__search_wiki` / `*__wiki_search` | Azure Wiki |
| `*__search_datadog_logs` | Datadog |

Multi-tracker tiebreak: infer from the issue reference. `PROJ-123` → Jira; `dev.azure.com/...` → Azure DevOps; bare numeric ID with both detected → one-time `AskUserQuestion`.

## Verb reference

See [`skills/tracker-adapter/references/verbs.md`](skills/tracker-adapter/references/verbs.md) for the full input/output schemas.

## Supported adapters

| Adapter | Read | Write | Body format |
|---|---|---|---|
| Azure DevOps | yes | yes | HTML |
| Jira | yes | yes | Markdown (server converts to ADF); custom rich-text fields take raw ADF |

GitHub Issues, Linear, and Shortcut are not implemented but the verb surface is sized to accommodate them — adding one is writing a new directory under `skills/tracker-adapter/adapters/`.
