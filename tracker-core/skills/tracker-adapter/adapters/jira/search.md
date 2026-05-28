# Jira — `searchIssues` → JQL

Build a JQL query from the normalized `SearchQuery` input and call `searchJiraIssuesUsingJql`.

## Skeleton

```
project = "<projectKey>"
  AND <conjuncts>
ORDER BY created DESC
```

## Conjunct mapping

| Input field | JQL fragment |
|---|---|
| `keywords` | `AND text ~ "<keywords>"` — quote the whole phrase; JQL's `text` field searches summary, description, and comments |
| `project` | `AND project = "<key>"` (overrides default) |
| `scope` | `AND component = "<scope>"` or `AND labels = "<scope>"` (caller passes a component name or a label; adapter picks based on which the project recognizes — query schema first) |
| `types` | `AND issuetype in (<comma-quoted list>)` |
| `states` | `AND status in (<comma-quoted list>)` |
| `dateWindow.from` | `AND created >= "<yyyy-MM-dd>"` |
| `dateWindow.to` | `AND created <= "<yyyy-MM-dd>"` |
| `limit` | pass through to the MCP call as `maxResults` |

## Quoting and escaping

- JQL strings use double quotes. Escape `"` as `\"` and `\` as `\\`.
- Wildcards in `text ~` use Lucene syntax: `*foo*` for substring, `foo*` for prefix. Default to substring on user input.
- Date literals use `yyyy-MM-dd` for date-only or full ISO for date-time. Default to date-only at UTC.

## Common patterns

### Recent issues in a component
```
project = "RLI"
  AND component = "Mobile App"
  AND created >= "2026-04-22"
ORDER BY created DESC
```

### Look-alike duplicates
```
project = "RLI"
  AND text ~ "notification*"
  AND status != Closed
ORDER BY created DESC
```

### Reporter activity check
```
project = "RLI"
  AND reporter = "<accountId>"
ORDER BY created DESC
```

### Current-sprint check
```
sprint in openSprints() AND project = "RLI"
```

## Limit handling

The Atlassian MCP takes `maxResults` directly (default ~50, max ~100 per request). When the input `limit` exceeds the max, page using `nextPageToken` if the MCP exposes it; otherwise return the first page with a warning: `result truncated at <n>; refine the query or set a smaller limit`.

## Special operators

- `sprint in openSprints()` — open sprints only.
- `sprint in closedSprints()` — closed.
- `parentEpic = "RLI-1234"` — direct children of an epic.
- `issueLinkType = "Duplicate"` — issues with duplicate links.

## Empty results

Return an empty array. Do not retry with a broadened query.

## JQL parse errors

The MCP returns a 400 with a `errorMessages` array. Surface the error verbatim with the parsed JQL string. Do not auto-correct.
