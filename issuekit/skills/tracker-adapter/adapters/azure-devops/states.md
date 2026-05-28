# Azure DevOps — state graph

AzDO state names depend on the process template (Agile, Scrum, CMMI, Basic) and on per-org customization. The adapter resolves the abstract policy state names against the live state graph for the work-item type.

## Process template defaults

| Process | Issue types | Common states |
|---|---|---|
| **Agile** | Bug, User Story, Feature, Task, Epic, Issue, Test Case | `New`, `Active`, `Resolved`, `Closed`, `Removed` (with `Reason` carrying nuance like `Investigating`, `Fixed`, `Awaiting Customer`) |
| **Scrum** | Bug, Product Backlog Item, Feature, Task, Epic, Impediment, Test Case | `New`, `Approved`, `Committed`, `Done`, `Removed` |
| **CMMI** | Bug, Requirement, Change Request, Risk, Issue, Review, Task, Test Case | `Proposed`, `Active`, `Resolved`, `Closed` (with detailed CMMI-specific reasons) |
| **Basic** | Issue, Task, Epic | `To Do`, `Doing`, `Done` |

The adapter does not assume a process template. It always queries the live schema.

## Live schema query

For a given issue type, call `wit_get_work_item_type(processName, workItemTypeName)` and read the `states[]` array. Each entry is `{ name, color, category }`. Categories are vendor-canonical:

| Category | Meaning |
|---|---|
| `Proposed` | initial state |
| `InProgress` | work underway |
| `Resolved` | work complete, awaiting verification |
| `Completed` | terminal success |
| `Removed` | terminal cancel |

The adapter uses categories to validate policy state names. If `policy.states.investigating` resolves to a state whose category is `Proposed`, warn — that's likely a misconfiguration.

## Abstract state mapping

| Abstract name | Common AzDO state | Typical reason |
|---|---|---|
| `investigating` | `Active` (Agile), `Committed` (Scrum), `Active` (CMMI) | `Investigating` |
| `waiting_reply` | `Active` (Agile) | `Awaiting Customer` |
| `backlog` | `New` (Agile/CMMI), `Approved` (Scrum) | — |
| `done` | `Closed` (Agile/CMMI), `Done` (Scrum/Basic) | `Fixed`, `Completed as Designed`, etc. |

Policy values are vendor-specific strings. The user owns the mapping. The adapter:

1. Reads `policy.states.<abstractName>`.
2. Validates against the live schema for the work-item type.
3. If invalid, lazy-prompts with the schema's valid states as options.

## Reason field

Many AzDO states require a `System.Reason` value that's specific to the state's transition source. The adapter accepts a `Reason: <value>` suffix in the policy state string:

```json
{ "states": { "investigating": "Active; Reason: Investigating" } }
```

If no reason is supplied, the adapter does not write `System.Reason`, and AzDO uses the default reason for that state transition.

## State change without state field rewrite

When the work item is already in the target state, the adapter skips the transition (avoids redundant audit entries). If `Reason` differs, the adapter still writes `Reason`.

## Identity bootstrap dependency

State transitions require `System.ChangedBy` to be set automatically by the server based on the calling identity. Confirm `whoAmI()` resolved successfully before any transition. If identity is unknown, abort the batch with a clear error.
