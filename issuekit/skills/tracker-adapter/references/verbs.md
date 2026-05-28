# Verb contracts

Every verb takes a normalized input and returns a normalized output. The adapter file under `adapters/<tracker>/` implements the actual MCP tool calls.

Markdown bodies are the universal authoring format. The reserved token `@[userRef]` produces a mention; the adapter projects it to AzDO `<a data-vss-mention="...">` or a Jira mention as appropriate.

## Type aliases

```
IssueId       = string                  // "1234" or "PROJ-1234"; vendor-defined
UserRef       = opaque                  // returned by resolveUser; valid for assign/mention/comment
Issue         = {
  id, url, title, body, type, state, severity, assignee, reporter,
  created, updated, resolved, labels, parent, customFields, raw
}
Revision      = { at, by, field, from, to }
Comment       = { at, by, body, url }       // body is markdown
IssueSummary  = { id, url, title, state, type }
PRRef         = { url, title, state, mergedAt }
Sprint        = { id, name, start, end }    // or null
```

## Reads

### `whoAmI()`
**In:** none
**Out:** `{ trackerUser: UserRef, defaultProject: string, defaultTeam: string|null }`
**Implements:** AzDO `core_list_projects` + `wit_my_work_items`; Jira `getAccessibleAtlassianResources` + `atlassianUserInfo`.

### `getIssue(id: IssueId)`
**Out:** `Issue` (body in markdown; `customFields` is an opaque map of vendor-specific keys for the caller's use)
**Implements:** AzDO `wit_get_work_item` with `expand: "all"`; Jira `getJiraIssue` with `responseContentFormat: "markdown"`.

### `getIssueHistory(id: IssueId)`
**Out:** `Revision[]` sorted oldest-first
**Implements:** AzDO derives from the work-item revision payload (`wit_get_work_item` already returns it); Jira not currently implemented — return empty array and log a warning.

### `getIssueComments(id: IssueId)`
**Out:** `Comment[]` sorted oldest-first, body in markdown
**Implements:** AzDO `wit_list_work_item_comments`; Jira inlines the `comment` field on `getJiraIssue`.

### `searchIssues(query: SearchQuery)`
```
SearchQuery = {
  keywords?: string,
  project?: string,
  scope?: string,            // AzDO area path; Jira component or label
  types?: string[],
  states?: string[],
  dateWindow?: { from?: ISO, to?: ISO },
  limit?: number             // default 25
}
```
**Out:** `IssueSummary[]`
**Implements:** AzDO `wit_query_by_wiql` (the adapter builds the WIQL); Jira `searchJiraIssuesUsingJql` (the adapter builds the JQL).

### `getIssueTypeSchema(type: string)`
**Out:** `{ fields: FieldSpec[], severityOptions: string[], requiredFields: string[] }`
**Implements:** AzDO `wit_get_work_item_type`; Jira `getJiraIssueTypeMetaWithFields`. Severity auto-discovery (`Severity Level` → `Severity` → `Bug Severity` → `priority`) happens here for Jira.

### `linkedPullRequests(id: IssueId, window?: { from?, to? })`
**Out:** `PRRef[]`
**Implements:** AzDO walks the `relations` array for `ArtifactLink`+`vstfs:///Git/PullRequestId/...` URLs, plus `repo_list_pull_requests_by_repo_or_project` filtered by branch-name mentioning `AB#<id>`; Jira walks `issuelinks` and any "remote links" plus PRs that smart-link to the issue key (queried via the Atlassian dev-status API if exposed, otherwise empty).

### `getCurrentSprint(team?: string)`
**Out:** `Sprint | null`
**Implements:** AzDO `work_list_team_iterations` with `timeframe: "current"`; Jira `searchJiraIssuesUsingJql` with `sprint in openSprints() AND project = <key>` then extract the sprint name from the first result.

### `resolveUser(query: { email?: string, name?: string })`
**Out:** `UserRef` (opaque)
**Implements:** AzDO `core_get_identity_ids` or descriptor lookup; Jira `lookupJiraAccountId`. Caches per session.

### `mention(userRef: UserRef)`
**Out:** `string` — the inline mention token to embed in a markdown body
**Implements:** AzDO returns `<a href="#" data-vss-mention="version:2.0,<unique-name>">@Display Name</a>`; Jira returns a Jira mention token. The body-format converter is responsible for keeping these intact through the markdown subset.

## Writes (gated)

Every write call is built into a `{verb, target, before, after}` tuple, batched, and rendered through `references/diff-and-confirm.md`. The user confirms once per batch.

### `assign(id: IssueId, user: UserRef | null)`
**Implements:** AzDO `wit_update_work_item` with `path: "/fields/System.AssignedTo"`; Jira `editJiraIssue` with `fields.assignee.accountId` or `fields.assignee: null`.

### `transition(id: IssueId, abstractStateName: "investigating" | "waiting_reply" | "backlog" | ...)`
**Implements:** Adapter maps the abstract name through policy (`policy.states.investigating` etc.) to either:
- AzDO: `wit_update_work_item` patch on `/fields/System.State` (+ `/fields/System.Reason` when policy specifies one).
- Jira: `getTransitionsForJiraIssue` → look up transition by name → `transitionJiraIssue`.

### `updateFields(id: IssueId, fields: { title?, body?, severity?, dueDate?, sprint?, storyPoints?, customFields? })`
**Implements:** AzDO single `wit_update_work_item` with one `op: add` per field, paths drawn from `adapters/azure-devops/writes.md`. Jira one `editJiraIssue` call with `fields` and (separately, when needed) any custom-field side-writes documented in `adapters/jira/writes.md`. Body conversion to HTML / ADF happens here.

### `addComment(id: IssueId, body: string)`
**Body is markdown.** Adapter converts.
**Implements:** AzDO `wit_add_work_item_comment` (HTML body); Jira `addCommentToJiraIssue` with `contentFormat: "adf"` and a JSON-stringified ADF document built from the markdown.

### `addLabel(id: IssueId, label: string)` / `removeLabel(id: IssueId, label: string)`
**Implements:** AzDO patches `/fields/System.Tags` (semicolon-delimited; adapter handles the append/remove logic); Jira `editJiraIssue` with `update.labels: [{ add: label }]` or `{ remove: label }`.

### `linkIssue(fromId: IssueId, toId: IssueId, kind: "duplicate-forward" | "related" | "parent")`
**Implements:** AzDO patches `/relations/-` with `rel` resolved through:
- `duplicate-forward` → `System.LinkTypes.Duplicate-Forward`
- `related` → `System.LinkTypes.Related`
- `parent` → `System.LinkTypes.Hierarchy-Reverse`

Jira `createIssueLink` with `link_type` resolved through:
- `duplicate-forward` → `Duplicate`
- `related` → `Relates`
- `parent` → uses `editJiraIssue` `fields.parent` (Jira treats parent as a field, not a link).

### `linkPullRequest(id: IssueId, prUrl: string)`
**Implements:**
- AzDO synthesizes `vstfs:///Git/PullRequestId/<projectId>%2F<repoId>%2F<prId>` from the URL and patches `/relations/-` with `rel: "ArtifactLink"`.
- Jira: no-op. Jira smart-links automatically when the PR description or branch name contains the issue key. The verb returns `linked: false, reason: "auto-link"` so the caller knows.

## Error handling

When a verb's underlying tool returns an error:

1. Reads: stop and tell the caller which call failed. Do not fabricate substitutes.
2. Writes: stop the batch on the first failure. Print which verb failed and what was written before it. Do not roll back successful writes — the user inspects the partial state and decides.

## Detection-time pre-checks

If `tracker == jira` and the policy requests AzDO-specific fields (`area_path_prefix`, `iteration_path_strategy`), warn once and ignore those keys. Same in reverse for `sprint_field_name`, `severity_field_name` when `tracker == azure-devops`.
