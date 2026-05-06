# Title Guide

Read this when you reach Step 6 of the workflow. Skip it on earlier steps.

## Why the Title Matters More Than the Description

The title is the highest-leverage piece of text on a work item. It shows up in:

- Board cards and backlog list views.
- Azure DevOps search results.
- Teams unfurls when the work-item URL is pasted.
- Email notifications and digest summaries.
- Sprint planning exports and burndown charts.
- The sidebar of any work item that links to this one.

A good title lets a teammate decide whether to open the work item without clicking through. A vague title forces them to open it just to find out, every time.

## Rules

1. **Name the area.** The product surface, system, service, or component. `SSO`, `Billing API`, `Resident Portal`, `CI Pipeline`, `Email Templates`, `Visitor Management`.
2. **State the problem or goal.** What is broken, what needs to happen, or what question is being investigated.
3. **Add the differentiator.** If there are ten SSO work items in the project, the title for this one says what makes it specific.
4. **Stay under 80 characters.** AzDO truncates long titles on board and list views. Aim for 60 to 75 characters in the rewritten title; treat 80 as the hard ceiling.
5. **Strip the generic words.** Titles that read `Bug`, `Issue`, `Broken`, `Request`, `Needs Fix`, or just a feature name with no verb carry no information and trip the differentiator rule.

## Pattern

Use this base pattern. Add modifiers when the work item warrants them.

```
{Area}: {specific problem or goal}
```

Customer-specific bug:

```
{Area} + {Customer}: {specific problem}
```

Incident:

```
P{n}: {Area} {short problem statement}
```

Spike:

```
Spike: {Area} {question to answer}
```

The colon is the structural separator. Avoid em dashes and spaced hyphens here as in the body.

## Examples by Archetype

Each example shows the original title, then the rewritten title.

### Bugs

| Original | Rewritten |
|----------|-----------|
| `VMS issues` | `VMS: Visitor notifications not sending for scheduled visits` |
| `SSO broken` | `SSO + Cushman Wakefield: Azure AD login fails with 401` |
| `Missing Templates` | `Email Templates: Missing after property onboarding for Brookfield` |
| `Login bug` | `Resident Portal: Login redirect loops on Safari iOS` |

### Features and User Stories

| Original | Rewritten |
|----------|-----------|
| `Bulk invite` | `Resident Portal: Add bulk-invite flow for move-in events` |
| `Dashboard updates` | `Analytics Dashboard: Add occupancy trend chart to property overview` |
| `Better filters` | `Lease Search: Add filter for lease end date and tenant status` |

### Tasks

| Original | Rewritten |
|----------|-----------|
| `Update Jest` | `CI: Migrate Jest config from v28 to v30` |
| `Clean up old code` | `Billing Service: Remove deprecated v1 payment processor adapter` |
| `Bump deps` | `Resident Portal: Upgrade Next.js from 14 to 15 and resolve breaking changes` |

### Incidents

| Original | Rewritten |
|----------|-----------|
| `Payments down` | `P1: Payment processing failing for all US properties` |
| `Site slow` | `P2: Resident Portal page load times above ten seconds during peak hours` |
| `Email outage` | `P2: Outbound notification emails delayed by SES throttling` |

### Spikes and Investigations

| Original | Rewritten |
|----------|-----------|
| `SSO research` | `Spike: Evaluate SSO providers for multi-tenant SAML support` |
| `Performance investigation` | `Spike: Profile and identify bottleneck in lease renewal flow` |
| `Mobile push spike` | `Spike: Compare FCM and APNs for in-app notifications` |

## When to Keep the Original

If the original title already follows the pattern, says the area clearly, and would not gain anything from a rewrite, leave it alone. The rule is to make the title better, not to rewrite for its own sake. The preview should still show the title even when unchanged so the user can confirm.
