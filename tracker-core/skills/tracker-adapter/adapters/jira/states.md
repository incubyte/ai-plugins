# Jira — state graph

Jira workflows are project-specific. The same status name can mean different things in different projects, and the transition graph is configurable per workflow. The adapter resolves abstract state names against the live transitions for the specific issue.

## Workflow basics

Each issue has a current `status` and a set of available transitions from that status. Each transition has:

```
{ id: "<numeric-id>", name: "<display-name>", to: { name: "<target-status>" } }
```

The adapter cannot transition by status name alone — it must look up the transition ID first.

## Resolution flow

For `transition(id, abstractStateName)`:

1. Read `policy.states.<abstractStateName>` → the configured transition name (e.g. `"Under Investigation"`).
2. Call `getTransitionsForJiraIssue(issueIdOrKey)` → returns the available transitions.
3. Match by `transition.name` exact (case-sensitive).
4. If no exact match, retry case-insensitive substring (`"investig"` matches `"Under Investigation"`).
5. If still no match, lazy-prompt with the list of available transitions.
6. Call `transitionJiraIssue(issueIdOrKey, transitionId)`.

## Common transition names by abstract state

| Abstract name | Common Jira transition names |
|---|---|
| `investigating` | `Under Investigation`, `Triaging`, `In Progress`, `Start Progress`, `Begin Triage` |
| `waiting_reply` | `Waiting for Reply`, `Need Info`, `Awaiting Customer`, `Customer Reply Required` |
| `backlog` | `Backlog`, `To Do`, `Open`, `Reopen` |
| `done` | `Done`, `Closed`, `Resolve`, `Complete` |

These are common defaults, not guaranteed. The policy file must specify the exact transition name the team uses.

## Status categories

Jira groups statuses into three categories:

| Category | Meaning |
|---|---|
| `new` | unstarted (Backlog, To Do, Open) |
| `indeterminate` | in progress |
| `done` | terminal |

The adapter uses the category as a sanity check. If `policy.states.investigating` resolves to a transition that lands in category `new`, warn the user — that's likely a misconfiguration.

## Workflow inconsistency

Two issues in the same project can have different available transitions if they're at different statuses. Always call `getTransitionsForJiraIssue` per issue. Cache only within the lifetime of a single batch.

## Transition with fields

Some Jira transitions require setting fields as part of the transition (e.g., a "Resolution" field on the `Resolve` transition). The MCP exposes this via the transition's `fields` array. The adapter:

- If the transition has required fields and the verb did not provide them, lazy-prompt the user to supply each.
- Pass the values in the `fields` parameter of `transitionJiraIssue`.

If the transition's `fields` array is empty, no extra fields are sent.

## State changes outside the transition graph

The adapter never tries to "set status directly" via `editJiraIssue` with `fields.status` — Jira ignores that field on edit. State changes are always through `transitionJiraIssue`.
