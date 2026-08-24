# Searching Microsoft Teams without silently losing half the data

Two things here are counter-intuitive and have each broken a real brief.

## 1. Date filters silently exclude every channel

`chat_message_search` has two code paths, and which one runs depends entirely on whether
you pass a date filter:

| | Covers | Notes |
|---|---|---|
| **No date filters** | 1:1 chats, group chats, meeting chats, **and Teams channels** | Microsoft Graph full-text search. Relevance-ranked, not chronological. |
| **`afterDateTime` / `beforeDateTime` set** | chats only — **channels are not covered at all** | A per-chat scan of up to 50 chats. Sometimes returns a Graph 429 partial-results note. |

A sweep that only uses date filters will never see a single channel post. At Incubyte that
means missing recognition posts, company announcements, and anything else that lives in a
team rather than a chat.

### Run both passes

**Pass A first** — no date filters. Several queries, keep the recent hits. This is the
cheap pass and the only one that reaches channels.

**Pass B second** — `afterDateTime` set to two days ago. Guarantees recency in chats.
Tolerate a partial-results note; use what came back.

Then merge, deduplicate by message id, and filter to your window by `createdDateTime`
yourself. Do not trust the search to have done that.

### Pass A queries that work

- The person's own full name, and their first name — for a "where you were tagged" section
- `Empuls` — the recognition bot; the richest source of who was thanked
- One or two very broad words (`the`, `we`) — catches recent channel traffic that keyword
  queries miss entirely
- Client and project names taken from today's calendar

### Telling a channel result from a chat result

A channel message carries a **`channelUri`** field, and its `chatId` ends `@thread.tacv2`.
Chats have no `channelUri`. Use this rather than guessing from the topic.

### Channels known to exist in the Incubyte tenant

Reachable only via Pass A:

| Team ID | Channel ID | What lives there |
|---|---|---|
| `0640b07f-99f7-4a7e-94db-4beb765fda75` | `19:fU7ADQPSFcHpBaVjT60ST72bZ8J982F9ftHofFe9rTE1@thread.tacv2` | Appreciation, peer bonuses, work anniversaries, birthdays |
| `c86edb63-f864-446b-8286-33d78feb285a` | `19:06d8de482c5749f2907540b2ff865462@thread.tacv2` | Peer bonuses |
| `9ca94e25-0b96-4996-bf82-dfc4f7b11650` | `19:9d91a22468b9484d8cb352d781496f35@thread.tacv2` | General announcements |

This list is a starting point, not a boundary — Pass A reaches every channel the person is
a member of, and different people are in different teams.

## 2. Prefer the returned `webUrl` over any link you build yourself

Pass A returns a correct, ready-made deep link on **every** result, for channels and chats
alike. Use it verbatim. It is always better than constructing one.

Only when `webUrl` is null or absent, construct:

```
https://teams.microsoft.com/l/message/{urlencoded chatId}/{messageId}?tenantId=05b07524-f2af-411a-b5a9-a5fee6228712&context=%7B%22contextType%22%3A%22chat%22%7D
```

URL-encode the chatId (`:` → `%3A`, `@` → `%40`); leave the messageId plain.

**`tenantId` and `context` are not optional.** Drop them and Teams resolves the link as a
*channel* link, finds no matching team, and shows "Hmmm… can't find that team" on every
single item. This was verified live in a browser — the bare form fails, the parameterised
form resolves.

Opening a valid Teams link in a browser shows the "Stay better connected with the Teams
desktop app" interstitial before handing off to the desktop app. That is normal, not a
failure.

Incubyte tenant ID: `05b07524-f2af-411a-b5a9-a5fee6228712`

## 3. Finding messages where someone was tagged

Search their full name and their first name on Pass A, then **exclude results whose
`from.email` is their own address**. The search index matches their own messages and the
quoted text inside their replies, so without that filter roughly half the results are the
person quoting themselves.

For each real tag, note who tagged them, where, what is wanted, and whether they have
already answered in that thread.

## Other source formats

- **Outlook mail and calendar** — use the `webLink` value the search returns, unchanged.
- **Close** — `https://app.close.com/lead/{lead_id}/`
- **All hrefs** — escape every `&` as `&amp;` so the attribute parses.
