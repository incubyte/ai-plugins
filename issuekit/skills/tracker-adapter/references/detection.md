# Detection rules

Run this at session start. Output is a 4-tuple of `(tracker, chat, doc, log)`. Cache for the session.

## Pattern table

Match against the full tool name (everything after the `mcp__` prefix family). Patterns use `*` as a wildcard. Match on **suffix**, not on the full prefix — the prefix varies based on which MCP plugin the user installed, and matching by suffix tolerates that variance.

| Pattern | Category | Adapter value |
|---|---|---|
| `*__getJiraIssue` | tracker | `jira` |
| `*__editJiraIssue` | tracker | `jira` (confirms write surface) |
| `*__wit_get_work_item` | tracker | `azure-devops` |
| `*__wit_update_work_item` | tracker | `azure-devops` (confirms write surface) |
| `*__slack_search_public` | chat | `slack` |
| `*__slack_search_public_and_private` | chat | `slack` |
| `*__teams_search_messages` | chat | `teams` |
| `*__searchConfluenceUsingCql` | doc | `confluence` |
| `*__search_wiki` | doc | `azure-wiki` |
| `*__wiki_search` | doc | `azure-wiki` |
| `*__search_datadog_logs` | log | `datadog` |

If a category has no match, set the value to `none`. The verb-plugin handles graceful degradation (e.g. skipping the Slack-search step when `chat == none`).

## Multi-tracker tiebreak

When both `*__getJiraIssue` and `*__wit_get_work_item` match, the session has access to two trackers. Resolve as follows when the verb-plugin needs to act on a specific issue:

1. **URL inference.** If the issue reference contains:
   - `dev.azure.com` or `*.visualstudio.com` → `tracker=azure-devops`
   - `*.atlassian.net` → `tracker=jira`
2. **Key shape inference** (when only a bare key is provided, no URL):
   - Matches `^[A-Z][A-Z0-9_]+-\d+$` (e.g. `PROJ-123`, `RLI-42`) → `tracker=jira`
   - Pure numeric (`12345`) with no URL → ambiguous; fall through.
3. **One-time ask.** When still ambiguous, call `AskUserQuestion` with options "azure-devops" / "jira". Cache for the session only — do not persist to `.claude/tracker-policy.json`. The next session may have a different intent.

## Single-tracker case

If only one of the two tracker patterns matches, that tracker is the resolved value. No further check needed. URLs that point at the other tracker should still be accepted — the verb-plugin can return an error explaining the missing MCP, but detection does not change.

## MCP prefix drift

User-supplied MCPs surface tools under different prefixes depending on how the server is registered:
- `mcp__azure_devops__wit_get_work_item`
- `mcp__ado__wit_get_work_item`
- `mcp__plugin_<user-supplied-name>__wit_get_work_item`

Suffix matching (`*__wit_get_work_item`) tolerates every variant. Do not hardcode the prefix.

## Announcement format

After detection completes, the agent prints one line at the start of the session:

```
tracker=azure-devops chat=teams doc=azure-wiki log=datadog
```

Use literal `none` for missing categories. This line is visible in the trace and serves as the verification anchor for the dry-run tests.

## Session refresh

Detection runs **once per session**. If the user enables a new MCP mid-conversation, the change does not take effect until the next session. Do not silently re-detect — the caching saves repeated tool-introspection cost and keeps verb behavior consistent through the run.
