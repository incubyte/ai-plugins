# Jira — tool allowlist

The adapter calls the tools below. Suffix-match against the available tool surface; prefix varies by which Atlassian MCP is installed.

## Read tools

| Verb | Tool (suffix) | Notes |
|---|---|---|
| `whoAmI` | `__getAccessibleAtlassianResources`, `__atlassianUserInfo` | run both; cloudId comes from the first, accountId/email from the second |
| `getIssue` | `__getJiraIssue` | call with `responseContentFormat: "markdown"` |
| `getIssueComments` | inlined in `__getJiraIssue` payload (`comment` field) | no separate call |
| `getIssueHistory` | not implemented | returns empty array + warning |
| `searchIssues` | `__searchJiraIssuesUsingJql` | adapter builds the JQL — see `search.md` |
| `getIssueTypeSchema` | `__getJiraIssueTypeMetaWithFields` | used for severity auto-discovery |
| `linkedPullRequests` | walk `issuelinks` + smart-link metadata from `__getJiraIssue` | no separate call; the Atlassian MCP does not always expose dev-status |
| `getCurrentSprint` | `__searchJiraIssuesUsingJql` with `sprint in openSprints() AND project = <key>` | extract sprint name from first hit |
| `resolveUser` | `__lookupJiraAccountId` | returns `accountId`; cache per session |
| `transition` (lookup step) | `__getTransitionsForJiraIssue` | resolves transition name → transitionId |

## Write tools

| Verb | Tool (suffix) | Notes |
|---|---|---|
| `assign` | `__editJiraIssue` | `fields.assignee.accountId` or `null` |
| `transition` (action step) | `__transitionJiraIssue` | takes the transitionId from the lookup |
| `updateFields` | `__editJiraIssue` | one call; `contentFormat: "markdown"` for body |
| `addComment` | `__addCommentToJiraIssue` | `contentFormat: "adf"` with a JSON-stringified ADF document |
| `addLabel` / `removeLabel` | `__editJiraIssue` | `update.labels: [{ add: ... }]` or `{ remove: ... }` |
| `linkIssue` | `__createIssueLink` | `link_type: "Duplicate"` or `"Relates"`; parent is set via `editJiraIssue.fields.parent` |
| `linkPullRequest` | no-op | Jira auto-links from PR description or branch name containing the issue key |

## Known prefix variants

- `mcp__plugin_atlassian_atlassian__*` (the most common Atlassian MCP plugin)
- `mcp__atlassian__*`
- `mcp__claude_ai_Atlassian_Rovo__*` (claude.ai's Rovo connector)
- `mcp__plugin_<user-installed-name>__*`

Suffix matching tolerates all of them.

## Optional tools (used when present)

- `__searchConfluenceUsingCql` — used by the issue-investigator skill when `doc == confluence`.
- `__slack_search_public_and_private`, `__slack_read_thread` — used when `chat == slack`.

## Tools NOT used

- `__createJiraIssue` — issue creation is out of scope.
- `__deleteJiraIssue` — never.
- `__getPagesInConfluenceSpace`, page-write tools — out of scope.
