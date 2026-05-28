# Azure DevOps — `searchIssues` → WIQL

Build a WIQL query from the normalized `SearchQuery` input and call `wit_query_by_wiql`.

## Skeleton

```
SELECT [System.Id], [System.Title], [System.State], [System.WorkItemType]
FROM WorkItems
WHERE [System.TeamProject] = '<project>'
  <conjuncts>
ORDER BY [System.CreatedDate] DESC
```

## Conjunct mapping

| Input field | WIQL fragment |
|---|---|
| `keywords` | `AND ([System.Title] CONTAINS WORDS '<kw>' OR [System.Description] CONTAINS WORDS '<kw>')` — one CONTAINS WORDS clause per token; AND between tokens |
| `project` | `AND [System.TeamProject] = '<project>'` (overrides the default) |
| `scope` (area path) | `AND [System.AreaPath] UNDER '<scope>'` |
| `types` | `AND [System.WorkItemType] IN ('Bug','Issue',...)` |
| `states` | `AND [System.State] IN ('Active','New',...)` |
| `dateWindow.from` | `AND [System.CreatedDate] >= '<iso-date>'` |
| `dateWindow.to` | `AND [System.CreatedDate] <= '<iso-date>'` |
| `limit` | append `ORDER BY [System.CreatedDate] DESC` (WIQL has no row limit; trim client-side after the result returns) |

## Quoting and escaping

- Single quotes in user input → double them: `O'Brien` → `O''Brien`.
- Wildcards in `CONTAINS WORDS` → not supported. Use `CONTAINS` (no `WORDS`) for substring match, but it's much slower; prefer `CONTAINS WORDS` and accept full-token matches.
- Date literals use ISO-8601: `'2026-04-29T00:00:00Z'`. Timezone in the input is honored; default to UTC.

## Common patterns

### Recent issues in an area
```
SELECT [System.Id], [System.Title], [System.State]
FROM WorkItems
WHERE [System.TeamProject] = 'MyProject'
  AND [System.AreaPath] UNDER 'MyProject\Mobile App'
  AND [System.CreatedDate] >= '2026-04-22'
ORDER BY [System.CreatedDate] DESC
```

### Look-alike duplicates
```
SELECT [System.Id], [System.Title], [System.State]
FROM WorkItems
WHERE [System.TeamProject] = 'MyProject'
  AND ([System.Title] CONTAINS WORDS 'notification'
       OR [System.Description] CONTAINS WORDS 'notification')
  AND [System.State] <> 'Closed'
ORDER BY [System.CreatedDate] DESC
```

### Reporter activity check
```
SELECT [System.Id], [System.Title], [System.CreatedDate]
FROM WorkItems
WHERE [System.TeamProject] = 'MyProject'
  AND [System.CreatedBy] = '<descriptor>'
ORDER BY [System.CreatedDate] DESC
```

## Limit handling

WIQL has no row-limit clause. The MCP tool returns the first N matches (server-side default ~200). If the input `limit` is smaller, trim the result client-side. If the result is exactly the server cap, append a one-line warning to the caller: `result truncated at server cap; refine the query`.

## Empty results

Return an empty array. Do not retry with a broadened query — the caller is responsible for deciding whether to broaden.
