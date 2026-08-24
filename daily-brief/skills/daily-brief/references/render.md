# Rendering the page

A single self-contained HTML file. Two full-bleed bands meeting at a hard edge: the top is
the visual anchor, the bottom is the lists. Content sits in a 860px column inside each.

If the Anthropic `morning` skill is present in the session, invoke it instead — it carries
this same design plus a bundled display font. Everything below is the fallback.

## Top band — the visual anchor

**Day-date line** — small, uppercase, ink-soft, above the headline:
`Monday · August 24 2026 · Eastern time`. Name the timezone here.

**Headline** — one serif line, spoken like a friend handing over the day. If one thing
genuinely makes today distinct, name that; otherwise name the shape. Never both.

Classify the day from the calendar alone — HEAVY (five or more hours in meetings, or a
cluster of three back-to-back) · NORMAL · OPEN (one short meeting at most). This sets the
headline's tone and the terrain's vertical scale.

**The drawing** — one SVG about 840×170. A single unbroken terrain stroke, edge to edge,
where elevation is load. A calm day flattens to still water; never invent mountains. No
card, no fill, no border.

Meetings are dots sitting *on* the line, radius 6–13 by weight. Optional or unanswered
meetings are grey and weightless. A genuine overlap is two hollow circles intersecting,
filled with the page background — the only hollow dots on the page.

At most one supporting motif per act: a sun for open creative time, a half-risen sun for a
pre-dawn start, a crescent moon for a late finish, birds for room to breathe, a flag for a
deadline. Clay is rationed to one accent across the whole drawing.

To keep dots exactly on the curve, generate the path through your points with a
Catmull-Rom-to-Bezier conversion and place each dot at its own control point.

**Acts** — three left-aligned columns under the drawing with faint hairline dividers. Each
stacks a bold time range over one sentence earned from the actual calendar. Uppercase the
AM/PM on the trailing time, and on the leading time when the range crosses noon:
"9:30 AM – 1 PM", "1 – 3:30 PM", "3:30 PM onward". When a second timezone is shown, it goes
on its own line under the range in grey.

## Bottom band — the lists

Needs attention first, then Resolved below it, then any sections — single column, full
width, never side by side. Each has a small uppercase system-sans heading, then per item:

1. Bold linked title, ten words or fewer
2. One sentence, with the source phrase carrying the link — underlined in ink-soft, no
   colour change
3. Faint grey numerals down the left

Numbered markers are honest here only because these are ranked lists; if a section is not
ranked, they still read as an index rather than a sequence, which is fine.

## Colour

| Token | Value | Used for |
|---|---|---|
| bg | `#FCFCFB` | bottom band, page ground |
| wash | `#F9F9F7` | top band |
| ink | `#2E2C27` | headline, headings, titles, terrain stroke, dots |
| ink-soft | `#6B6A63` | body, act sentences, day-date |
| ink-grey | `#B4B3A8` | numerals, grey dots |
| hairline | `#E4E3DC` | act dividers |
| line | `#E1E1DF` | the edge between bands |
| clay | `#C6613F` | buttons, and at most one drawing accent |
| clay-hover | `#AE5133` | button hover |

Define the full palette as tokens on bare `:root` and set `color-scheme: light`. This design
commits deliberately to one light, papery world, so it does not need a dark variant — but
`body` must set an explicit background from a token, or the page borrows whatever ground the
host paints behind it.

## Type

A serif for the headline only, around 40px (30px below 640px) — Fraunces if you can embed it
as a base64 woff2 data URI, otherwise `Georgia, serif`. Never fetch from Google Fonts: the
stylesheet host resolves but the font-file host is blocked, so the failure appears only
after the CSS step has apparently succeeded.

Everything else uses the system stack: `-apple-system, "Segoe UI", sans-serif`. Never
italic. Give the headline `text-wrap: balance`, and uppercase labels a touch of
letter-spacing.

## Buttons

Solid clay fill and border, `border-radius: 8px` (never a pill), padding `9px 16px`, system
sans 500 at 13px, background-coloured text, no arrow or icon. Nothing else on the page is a
button, badge, or filled label. Give links a visible `:focus-visible` outline.

## Responsive

One media query at 640px: acts stack vertically in order, hairlines become horizontal
rules, the drawing stays full width above. Nothing clips, and the body never scrolls
sideways.

## Verify before delivering

Screenshot the finished file with the preinstalled Chromium and look at the image. Launch
with an explicit `executablePath` — a bare launch looks for a browser revision that is not
installed and suggests an install that must not be run.

```
node -e "const{chromium}=require('playwright');(async()=>{const b=await chromium.launch({executablePath:'/opt/pw-browsers/chromium'});const p=await b.newPage({viewport:{width:960,height:1400}});await p.goto('file://<abs path>');await p.waitForTimeout(600);await p.screenshot({path:'brief.png',fullPage:true});await b.close();})();"
```

Check: day-date above headline · one unbroken stroke with every dot on it · three acts ·
serif on the headline only · both lists sharing one style · every item title linked where a
URL exists · buttons only when the exact phrase rode in with the prompt · every href https
and every ampersand escaped · no chips, cards, badges, footer, or timestamp · no act
restating a list item · below 640px nothing clipped.
