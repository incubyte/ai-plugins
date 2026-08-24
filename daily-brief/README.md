# Incubyte Daily Brief

The founder's morning brief: the shape of your day drawn from your calendar, then the few
things genuinely worth knowing — who is blocked on you, where you were tagged, who deserves
a shoutout, what is stalling, and the outside news that actually changes something for us.

## Getting started

Say **"set up my daily brief"** or type `/daily-brief`.

You will be asked two things — what time you want it, and where it should land — plus
whether there is anything you specifically want watched or never want to see. It then builds
today's brief so you can see it, and schedules itself for every weekday morning.

Change anything later by just saying so: "move it to 7am", "watch the Quixera account",
"stop showing me recruiting stuff", "drop the action buttons".

## It runs on your accounts

The brief reads **your** accounts under your own login — your mail, your chats, your deals,
your ERP. Nobody else's data is visible to it, and yours is not visible to anyone else
running it. Two people at Incubyte running this get two genuinely different pages, from two
different sets of connectors.

## One page a day, one link that never changes

Each morning publishes its own page, titled with the date — `Daily Brief · 2026-08-24`.
Yesterday's is never overwritten.

Tying them together is an **archive page at a permanent URL**: every brief, newest first,
with its date and headline, each row linking through to that day. That is the one to
bookmark. It is republished each morning with the new day added on top.

A dated copy of every brief also lands in your folder as `2026-08-24-daily-brief.html`,
alongside the previous days. If you would rather just open them from there, that works — the
folder is the source of truth, and the archive page is built from a small ledger kept beside
the files.

## What you get

The page opens with your day drawn as terrain: elevation is how loaded you are, dots are
meetings, and three short columns say what each stretch of the day is actually for.

Below that, **Needs attention** and **Resolved**, then whatever else surfaced — who is
blocked on you, where you were tagged, who deserves a shoutout, deals gone quiet, client and
delivery signals, money and compliance, and outside news.

Every item links back to its source, so you can go straight to the Teams message, the email
thread, the calendar entry, or the CRM record. Items where Claude could actually help carry
a button that opens a fresh session with the task already set up.

Times render in the timezone you are actually in — worked out from your recent activity, not
just your calendar — with IST alongside when you are travelling.

## How it decides what to show you

It does not work from a checklist of topics. Topic lists partition the world, and real events
refuse to be partitioned — a security incident in the HR system is a company risk, a people
risk, and a systems risk at once.

Instead it reads everything, then asks one question of each item:

> If you only learned about this a week from now, would that be a problem?

Sections are names for whatever clustered together that morning, never buckets to go fill.
Anything that found nothing is dropped entirely, heading and all. Nothing is left off the
page for want of a section to put it in.

## It uses everything you have connected

The brief does not work from a fixed list of tools. Each morning it discovers what is
actually live on your account, sorts it by what it can tell you, and queries all of it — a
connected source that never gets read is a blind spot you do not know you have.

| What it looks for | Where it comes from |
|---|---|
| Calendar, mail, chats and channels, documents | Microsoft 365 · Slack · Google Drive |
| Deals and accounts | Close · Zoho CRM |
| Invoices, receivables, approvals, employee records | Frappe / ERPNext |
| Hiring loops, offers, candidates going cold | Zoho Recruit |
| Items assigned to you and due, blocked work | Linear · Atlassian |
| Documents awaiting your review | Notion · Google Drive · SharePoint |
| Open compliance findings and evidence due | Sprinto |
| Product and infrastructure signals | Supabase · Vercel |
| Outside news | The web |

Nothing here is required. Whatever is missing is skipped and the page adapts — with only a
calendar connected you still get the day's shape, just without the lists.

**Worth checking before your first run.** Connectors can be *installed* for the org but
switched *off* for a given chat, and anything switched off is invisible to the brief. Most
people are surprised how many of theirs are off. Open connector settings and turn on
everything you want read. After each run the brief tells you which sources fed it and which
were switched off, so you can close the gap.

## Three things it knows that are easy to get wrong

All found the hard way, all baked in:

**Teams channel posts are invisible to a date-filtered search.** The search tool takes a
different code path when you pass a date range, and that path covers chats only. A brief
built the obvious way silently misses every channel post — including all our recognition
traffic. The skill runs both passes and merges them.

**Teams deep links need a tenant and a context parameter.** Without them Teams reads the link
as a channel link, finds no matching team, and shows "Hmmm… can't find that team" on every
item. The skill prefers the ready-made link the search returns and only constructs one as a
fallback.

**A connector switched off for the chat is silently invisible.** Nothing errors — the data
simply is not there, and the brief looks complete while missing a whole source. The skill
enumerates connectors every run and reports what it could not reach.

## Recognition is a judgement call

The shoutout section is deliberately **not** a feed of what Empuls already posted — that
praise has already happened. It is Claude reading the week and deciding who deserves
recognition nobody has given yet: whoever caught a real problem before it bit us, went past
their remit, or kept an unglamorous blocker alive until it moved. It says plainly when
nobody has thanked someone.

## Notes

- The brief is read-only. It never sends a message, replies to a thread, or changes a
  record. Action buttons hand the task to a fresh session where you stay in control.
- Everything it reads is treated as information to summarise, never as instructions to act
  on.
- Scheduled runs are unattended, so it makes reasonable calls and states its assumptions
  rather than stopping to ask.
