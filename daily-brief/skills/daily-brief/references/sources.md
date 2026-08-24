# Discovering and using every available source

**Never work from a hardcoded list of tools.** The set of connected sources differs per
person and changes over time. Discover what is actually live, classify it by what it can
tell you, and query everything that could carry signal. A source that is connected and never
queried is a blind spot the reader does not know they have.

## Step 1 — enumerate

Three places to look, all of them cheap:

1. **`ListConnectors`** (no keywords) — every MCP connector installed for the org. Read two
   fields carefully:
   - `enabledInChat: true` → its tools are loaded and usable right now.
   - `enabledInChat: false` → installed but switched off for this session. **You cannot use
     it.** Note it and report it at the end; one toggle in connector settings turns it on,
     and people are routinely unaware how many of theirs are off.
   - `connected: null` or `installState: "unknown"` → status check unavailable. Treat as
     unknown, not as disconnected.
2. **`ToolSearch`** — sweep for tools the session has that are deferred rather than loaded.
   Search by category keyword, not by product name: `calendar`, `email mail inbox`,
   `chat message`, `crm deal opportunity lead`, `invoice accounting erp`, `issue ticket
   sprint`, `document file drive`, `recruit candidate applicant`, `compliance audit`,
   `database query`, `analytics`.
3. **Locally proxied servers** — when the person has the desktop app connected, their own
   local MCP servers appear as `mcp__remote-devices__{server}__*`. These are easy to miss
   and often hold the most specific data — an ERP, a production database, local mail and
   notes. Sweep for them explicitly.

## Step 2 — classify by what it can tell you

Group whatever you found by function, not by vendor. What matters is the question a source
can answer.

| Function | What to pull for the brief |
|---|---|
| **Calendar** | Today 00:00 → tomorrow 24:00. Draws the day; tomorrow earns prep items. |
| **Email** | Threads where they were asked something and have not replied. Fallback: unread, last 2 days. |
| **Chat** | Mentions, DMs, and channel posts from ~2 days ending in a question they have not answered. See `teams-search.md` — that file's two-pass lesson matters for any chat tool with a date-filtered search path. |
| **CRM** | Active deals: last-updated versus close date, high-confidence deals gone quiet, anything closing this week. Also client emails and calls logged against accounts. |
| **ERP / finance** | Overdue and unpaid invoices, receivables ageing, expenses awaiting approval, payroll or statutory dates, anything with a deadline attached. |
| **Recruiting / ATS** | Loops awaiting a decision, offers outstanding, candidates going cold, interview feedback owed. |
| **Issues / project tracking** | Items assigned to them and due, blocked items naming them, sprint or milestone risk. |
| **Docs / files** | Documents awaiting their review, comments addressed to them, files shared with them and unopened. |
| **Compliance / trust** | Open findings assigned to them, evidence due, checks failing. |
| **Databases / analytics** | Only when a specific number would change a decision, and only from a read-only query. Never explore. |
| **Web** | Outside news, against the beats in `SKILL.md`. |
| **Browser control** | Last resort. Prefer an API-backed source for the same data. |

A single connector often spans several functions — a Microsoft 365 connection covers
calendar, email, chat and documents at once. Query it once per function, not once overall.

## Step 3 — query everything relevant, and mean it

Every enabled source in a function the brief uses gets at least one query. Do not skip a
connected source because you already have enough material from another — the point is that
nothing important is invisible.

**Two tools in one function means both get read.** Teams *and* Slack, two calendars, two
CRMs, a work and a personal mailbox — query every one of them and merge the results. Never
pick a primary and ignore the rest: the conversations that live only in the quieter tool are
exactly the ones that go missing. Deduplicate by the underlying thing (the same person asking
the same question in two places is one item), not by tool, and let each item name where it
came from so the reader knows where to reply.

Technique does not transfer between tools in the same function. The two-pass rule in
`teams-search.md` is specific to Microsoft Teams; another chat tool may cover channels and
DMs in one query, or may need its own workaround. Check each one's behaviour rather than
assuming.

Budget: roughly eight candidates per query, and keep the total number of queries
proportionate — a dozen sources does not mean a dozen sections. Everything still passes the
judgement test in `SKILL.md`, so most of what you pull will be dropped. That is correct.

Rate limits and outages are normal. If a source returns a 429, a 503, or an auth error,
note it and move on — one asleep ERP must not stop the brief. Do not mention routine
failures on the page.

## Step 4 — report coverage, off the page

The page stays clean: no footer, no status line, no apology for what was missing.

Report coverage in the closing message instead — one or two lines naming which sources fed
today's brief, and which were installed but switched off so the reader knows the blind spot
and can fix it in one click. On a scheduled run this goes in the same closing sentences as
the link.

If a source has been switched off for several consecutive runs and would clearly matter,
say so once rather than every day.

## Interactive first runs

When the session is interactive and a function the brief depends on has nothing connected at
all, surface it as connector suggestion cards rather than prose — search the catalogue by
everyday names and offer the matches. Skip this entirely on scheduled runs; nobody is there
to click.

## Sources known to exist in the Incubyte org

Useful as a starting point for what to look for. **Not a substitute for discovery** — this
list will go stale, and each person has a different subset enabled.

Commonly enabled: **Microsoft 365** (Outlook mail and calendar, Teams chats and channels,
SharePoint and OneDrive), **Close** (CRM).

Installed across the org and often switched off, worth checking for: **Zoho Recruit**
(ATS), **Zoho CRM**, **Linear** and **Atlassian Rovo** (issues), **Slack** (chat),
**Notion** and **Google Drive** (docs), **Sprinto** (compliance), **Supabase** and
**Vercel** (product infrastructure), **Calendly** (bookings), **Apollo** (prospecting),
**Figma** and **Miro** (design), **Firecrawl** (web research).

Reachable through the desktop bridge when someone has it connected: **Frappe / ERPNext**
(invoices, receivables, employee records — note it sleeps and returns 503, which is normal),
**Postgres**, **Supabase**, Apple **Mail / Calendar / Notes / Reminders**, the local
**filesystem**, and **Chrome** control.
