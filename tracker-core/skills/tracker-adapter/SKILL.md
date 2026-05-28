---
name: tracker-adapter
description: "Auto-detects the active issue-tracker MCP and exposes an abstract verb surface that works across Azure DevOps and Jira. Routes reads (getIssue, searchIssues, ...) and writes (addComment, transition, updateFields, ...) through the vendor adapter resolved at session start. Loads policy from .claude/tracker-policy.json with lazy-prompt fallback. Owns the diff-and-confirm gate that every write batch must pass."
metadata:
  author: Taha Bikanerwala
tools: Read, AskUserQuestion
---

# Tracker Adapter

A verb dispatcher that lets `incident-postmortem` and `issue-triage` work against any supported issue tracker without naming a specific MCP tool in their agent prompts.

## Setup (run once per session)

Before serving any verb call, the caller must run the bootstrap sequence below and cache the results for the rest of the session.

1. **Detect the available MCPs.** Read `references/detection.md` and scan the available tool names for each pattern. Set:
   - `tracker ∈ {azure-devops, jira, none}`
   - `chat ∈ {slack, teams, none}`
   - `doc ∈ {confluence, azure-wiki, none}`
   - `log ∈ {datadog, none}`
2. **Resolve multi-tracker ambiguity.** If two trackers are detected, inspect the issue URL or key the caller passed in:
   - URL containing `dev.azure.com` or `visualstudio.com` → azure-devops
   - Key matching `[A-Z][A-Z0-9_]+-\d+` (e.g. `PROJ-123`) → jira
   - Numeric-only ID with no URL → ask once via `AskUserQuestion`, cache for the session only (do not persist).
3. **Bootstrap identity.** Call `whoAmI()` (see `references/verbs.md`). The adapter implementations are in `adapters/<tracker>/`. Cache `{trackerUser, defaultProject, defaultTeam}` and the chat user (if a chat backend was detected).
4. **Load policy.** Read `.claude/tracker-policy.json` if it exists. Merge with shipped defaults from `references/policy-schema.md`. Track which keys are unset; do not lazy-prompt yet.
5. **Legacy config migration warning.** If any of the legacy paths exists, read forward once and print a one-time warning:
   - `.claude/azure-incident-postmortem.config.json`
   - `.claude/azure-issue-triage.config.json`
   - `.claude/jira-issue-triage.config.json`
   - `.claude/jira-bug-triage.config.json`

   Warning: "Found legacy config at `<path>`. Read for this session. To stop this warning, translate the values into `.claude/tracker-policy.json` and delete the legacy file. Lazy prompts will offer to persist any missing keys."

If `tracker == none`, stop and tell the caller. The caller cannot proceed without a tracker MCP.

Announce the detection result at the start of the session:

```
tracker=<tracker> chat=<chat> doc=<doc> log=<log>
```

## Calling convention

The caller invokes verbs by name; this skill routes the call to the resolved adapter.

- Verb contracts live in `references/verbs.md`. Each verb declares input, output, and which adapter file implements it.
- Adapter implementations live in `adapters/<tracker>/{tools, search, writes, body-format, states, mentions}.md`. The adapter file names map 1:1 to the verb categories.
- Reads chain freely. Writes must pass through the diff-and-confirm gate (see below).
- Markdown body input is normalized through `references/body-format.md` and the per-adapter `body-format.md` before any write call.

## Lazy-prompt rule

When a verb needs a policy value (state name, severity scheme, escalation contact, skip-labels, triaged-label, output_directory, archetype_assignment_after_triage) and the value is unset:

1. Read the question text from `references/policy-schema.md` for that key.
2. Call `AskUserQuestion` with the question and the documented option set.
3. Cache the answer in session memory.
4. Offer to persist by appending to `.claude/tracker-policy.json`. If the user accepts, write the file with two-space indent and sorted top-level keys. If they decline, keep the answer in session memory only.

Never ask the same policy question twice in a session.

## Diff-and-confirm gate

Every batch of writes must pass through the gate before any write verb fires. Read `references/diff-and-confirm.md` for the exact format.

The gate is **always on**. There is no `--dry-run` flag — declining at the gate is the dry run.

- The verb-plugin builds the batch as a list of `{verb, target, before, after}` tuples.
- This skill renders the batch as a markdown table and calls `AskUserQuestion` once.
- On confirmation, the skill replays each tuple as a sequential write call.
- On decline, the skill returns without firing any write.

The gate is a hard boundary. Writes cannot bypass it, even for "small" updates like a label append.

## Verb surface (summary)

See `references/verbs.md` for the full schemas. Quick reference:

**Reads:** `getIssue`, `getIssueHistory`, `getIssueComments`, `searchIssues`, `getIssueTypeSchema`, `linkedPullRequests`, `getCurrentSprint`, `whoAmI`, `resolveUser`, `mention`.

**Writes:** `assign`, `transition`, `updateFields`, `addComment`, `addLabel`, `removeLabel`, `linkIssue`, `linkPullRequest`.

## Adapter file map

| Adapter file | Contains |
|---|---|
| `adapters/<tracker>/tools.md` | MCP tool-name allowlist and known prefix variants for that tracker. |
| `adapters/<tracker>/search.md` | Query-language builder (WIQL for AzDO, JQL for Jira). |
| `adapters/<tracker>/writes.md` | Payload shapes for write verbs (JSON Patch for AzDO, edit/transition for Jira). |
| `adapters/<tracker>/body-format.md` | Markdown subset rules and conversion notes for that tracker. |
| `adapters/<tracker>/states.md` | State-graph quirks and the abstract-state → vendor-state mapping rules. |
| `adapters/<tracker>/mentions.md` | How `@[userRef]` projects to the vendor's mention syntax. |

## Constraints

- **Read-only by default.** Every write verb is gated; reads need no confirmation.
- **No vendor names in verb arguments.** A verb-plugin must never write `System.Title` or `fields.summary` as a literal — the verb dispatcher owns the projection.
- **One detection pass per session.** Do not rerun detection mid-flow; if the MCP surface changed, the user is expected to start a new session.
- **No invented verbs.** If a verb-plugin needs something not in `verbs.md`, surface it back to the caller; do not improvise.
