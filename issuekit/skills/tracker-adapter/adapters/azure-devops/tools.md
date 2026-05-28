# Azure DevOps — tool allowlist

The adapter calls the tools below. Suffix-match against the available tool surface; prefix varies by which MCP is installed.

## Read tools

| Verb | Tool (suffix) | Notes |
|---|---|---|
| `whoAmI` | `__core_list_projects`, `__wit_my_work_items` | run both to confirm reachability and resolve identity |
| `getIssue` | `__wit_get_work_item` | call with `expand: "all"` |
| `getIssueComments` | `__wit_list_work_item_comments` | separate fetch even when `expand: "all"` was used |
| `getIssueHistory` | derived from `__wit_get_work_item` revisions | no separate call |
| `searchIssues` | `__wit_query_by_wiql` | adapter builds the WIQL — see `search.md` |
| `getIssueTypeSchema` | `__wit_get_work_item_type` | for severity option enums and required fields |
| `linkedPullRequests` | `__repo_list_pull_requests_by_repo_or_project`, plus walk `relations[]` from `__wit_get_work_item` | combine both sources |
| `getCurrentSprint` | `__work_list_team_iterations` | `timeframe: "current"` |
| `resolveUser` | `__core_get_identity_ids` | best-effort; returns the AzDO descriptor |

## Write tools

| Verb | Tool (suffix) | Notes |
|---|---|---|
| `assign` | `__wit_update_work_item` | JSON Patch on `/fields/System.AssignedTo` |
| `transition` | `__wit_update_work_item` | patch `/fields/System.State` (and optionally `/fields/System.Reason`) |
| `updateFields` | `__wit_update_work_item` | one patch document; one `op: add` per field |
| `addComment` | `__wit_add_work_item_comment` | HTML body |
| `addLabel` / `removeLabel` | `__wit_update_work_item` | patch `/fields/System.Tags` (semicolon-delimited string) |
| `linkIssue` | `__wit_update_work_item` | patch `/relations/-` with `rel` from the kind map |
| `linkPullRequest` | `__wit_update_work_item` | patch `/relations/-` with `rel: "ArtifactLink"` + `vstfs://` URL |

## Known prefix variants

The same tool surfaces under different prefixes depending on how the user registered the MCP server. Treat all of these as the same tool; the adapter matches on the suffix.

- `mcp__azure_devops__*`
- `mcp__ado__*`
- `mcp__plugin_<user-installed-name>__*`

Never hardcode the prefix in a verb-plugin prompt. The dispatcher resolves it.

## Optional tools (used when present)

These tools are not part of the verb surface but are called opportunistically by the verb-plugins when present:

- `__search_wiki` — used by the issue-investigator skill when `doc == azure-wiki`.
- `__teams_search_messages`, `__teams_read_thread` — used when `chat == teams`.

## Tools NOT used

The adapter does **not** call the following, even though they exist in the AzDO MCP surface:

- `__wit_create_work_item` — issue creation is out of scope for the triage/postmortem verbs.
- `__pipelines_*` — out of scope.
- `__advsec_*` — out of scope.

If a future verb needs one of these, add it explicitly to the verbs list, not as an inline tool call.
