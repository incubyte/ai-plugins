# Discovery Plugin

End-to-end product discovery for [Claude Code](https://claude.com/product/claude-code) and [Claude Cowork](https://claude.com/product/cowork). Tell Claude to "start product discovery" and walk away with a fully-structured, PM-grade PRD.

The methodology is original; the framework references (15 files) are forked from three open-source PM skill libraries — see [`ATTRIBUTION.md`](./ATTRIBUTION.md).

## What it does

You say *"start product discovery for &lt;your idea&gt;"* (or any natural variant — no slash command). Claude runs a seven-phase flow as a guided interview:

| Phase | What happens |
|---|---|
| **0. Context** | Who's asking, why now, who reads the PRD, what's out of research scope |
| **1. Scope** | Problem framing with JTBD, user research input, scope, success metrics with validation, **assumptions inventory** |
| **2. Competition** | Competitor/substitute mapping + **kill-gate evaluation** — willing to recommend not pursuing |
| **3. User Journeys** | Happy path + critical edges, friction inventory, derived screen list |
| **4. Wireframes** | Text-based wireframes (ASCII or Mermaid) for the screens journeys imply |
| **5. GTM** | Positioning, ICP, **pricing with willingness-to-pay**, motion, channels, launch |
| **6. PRD Assembly** | Full PRD with **timeline-vs-scope reconciliation**; revision mode for post-delivery edits |

Each phase ends with a checkpoint where you confirm before moving on. The flow is **resumable** — stop mid-discovery, come back next week, pick up where you left off.

## What makes this different from a generic PRD writer

It pushes back. A generic PRD writer takes the input you give and produces the PRD. This skill:

- **Refuses vague success metrics.** "Users will love it" gets rewritten into measurable, baselined, time-bound, falsifiable form before being accepted.
- **Forces an assumptions inventory.** 5-10 things you're assuming, tagged risky/assumed/validated. The risky ones become the PRD's risks section.
- **Will recommend killing the idea.** Phase 2 ends with an explicit pursue/kill evaluation. If the evidence says don't proceed, the deliverable is a kill memo, not a PRD.
- **Reconciles timeline against scope.** Won't let you ship a 30-requirement PRD with a 6-week timeline without naming the conflict.
- **Pulls user research over PM intuition.** If you have customer interviews or support tickets, they take priority over your framing.

## Install

### Option 1: Git clone (works today, simplest)

```sh
git clone https://github.com/<YOUR_GITHUB_USERNAME>/discovery-plugin.git
cd discovery-plugin
```

Then in Claude Code, point the plugin loader at the cloned directory. The skill will load automatically and trigger on natural-language requests.

### Option 2: Claude Code plugin install (after publishing)

If you've published this as a plugin marketplace entry:

```sh
/plugin marketplace add <YOUR_GITHUB_USERNAME>/discovery-plugin
/plugin install discovery@<marketplace-name>
```

See the **Publishing** section below for how to set this up.

### Option 3: Skills CLI (broadest reach)

Anthropic's [Skills CLI](https://github.com/vercel-labs/skills) lets people install skills into any Claude-compatible tool:

```sh
npx skills add <YOUR_GITHUB_USERNAME>/discovery-plugin
```

Works automatically once the repo is public — no extra setup.

## How to use it

There's no command. Just say what you want:

- *"Start product discovery for an AI tool that helps teachers grade essays"*
- *"I have a product idea — walk me through discovery"*
- *"Build me a PRD from scratch for &lt;idea&gt;"*

Claude will:
1. Check for an existing `discovery-state.md` in the project root. If found, offer to resume. If not, start fresh.
2. Run the seven-phase interview, asking questions in batches of 2-3.
3. Produce the final PRD at `PRD.md` in the project root.

To resume an in-progress discovery, just say *"resume product discovery"* or open the project and Claude will pick it up automatically.

To revise after delivery: *"revise the success metrics section"* — the skill updates both `PRD.md` and `discovery-state.md` together.

## Files Claude produces

- **`PRD.md`** — the deliverable. A complete, structured PRD with wireframes and journeys inline as Mermaid.
- **`discovery-state.md`** — internal state file that tracks phase progress and captures answers. Edit it directly between sessions if you want; Claude reads it on resume.

That's it. No `competitive.md`, no `wireframes.md`, no separate files per phase.

## What's inside the plugin

```
discovery-plugin/
├── .claude-plugin/plugin.json
├── skills/
│   └── product-discovery/
│       ├── SKILL.md                          # the orchestrating skill (the methodology)
│       └── references/
│           └── frameworks/                   # 15 framework refs the skill reads internally
│               ├── problem-statement.md
│               ├── jtbd-canvas.md
│               ├── interview-synthesis.md
│               ├── working-backwards.md
│               ├── opportunity-tree.md
│               ├── hypothesis.md
│               ├── persona-canvas.md
│               ├── positioning-canvas.md
│               ├── competitive-analysis.md
│               ├── stakeholder-summary.md
│               ├── monetizing-innovation.md
│               ├── gtm-strategy.md
│               ├── solution-brief.md
│               ├── experiment-design.md
│               └── prioritization.md
├── templates/
│   └── PRD.md.template                       # canonical PRD structure
├── README.md
├── ATTRIBUTION.md
└── LICENSE                                   # Apache-2.0
```

The framework files are *internal* — Claude reads them when the appropriate phase calls for them (e.g., `competitive-analysis.md` during Phase 2, `monetizing-innovation.md` during Phase 5.3). You never invoke them directly.

---

## Publishing

This plugin is built to live in your personal GitHub. Three layers of distribution, each independent.

### Step 1: Push to GitHub (5 min, makes it usable today)

```sh
# from inside the unpacked plugin directory
git init
git add .
git commit -m "Initial discovery plugin v0.2.0"

# create the repo (gh CLI, or do it via web UI)
gh repo create <YOUR_GITHUB_USERNAME>/discovery-plugin --public --source=. --remote=origin --push
```

After this, anyone can install via Option 1 (git clone) above.

**Before pushing**, do a find-and-replace for `<YOUR_GITHUB_USERNAME>` across these files:
- `.claude-plugin/plugin.json` (two places)
- `README.md` (in install commands)

```sh
# replace <YOUR_GITHUB_USERNAME> with your actual username everywhere
grep -rl '<YOUR_GITHUB_USERNAME>' . | xargs sed -i 's/<YOUR_GITHUB_USERNAME>/your-actual-username/g'
```

### Step 2: Make it Claude-Code-installable as a marketplace plugin

Claude Code plugins install via a marketplace. You can run a personal marketplace from your own repo. Either:

**Option A — single-repo marketplace** (this repo IS the marketplace).

Add a marketplace manifest at `.claude-plugin/marketplace.json`:

```json
{
  "name": "<your-marketplace-name>",
  "owner": "<YOUR_GITHUB_USERNAME>",
  "plugins": [
    {
      "name": "discovery",
      "source": ".",
      "description": "End-to-end product discovery flow that produces a structured PRD."
    }
  ]
}
```

Users install with:
```sh
/plugin marketplace add <YOUR_GITHUB_USERNAME>/discovery-plugin
/plugin install discovery@<your-marketplace-name>
```

**Option B — multi-plugin marketplace** (a separate repo that hosts multiple plugins).

If you want to publish multiple plugins later, create a marketplace repo (`<YOUR_GITHUB_USERNAME>/claude-plugins`) with a manifest pointing at this and other plugin repos. More setup, but cleaner if you'll have a collection.

For now, Option A is simpler.

### Step 3: List on Skills CLI directory (broadest reach, optional)

The Skills CLI ([`npx skills`](https://github.com/vercel-labs/skills)) auto-discovers any GitHub repo with the right structure — yours already qualifies. Anyone can run `npx skills add <YOUR_GITHUB_USERNAME>/discovery-plugin` once the repo is public. No PR needed.

To get listed in the public skills.sh directory (more discoverable), submit your repo there once you're confident in the plugin.

### Distribution sequence I'd recommend

1. **Today:** Step 1 only. Push to a public repo, share the URL with people who want to try it.
2. **After 2-3 real engagements:** Step 2A. Add the marketplace manifest so installs are one command.
3. **After it's stable and used by 5+ people:** Step 3. Submit to skills.sh.

Don't skip step 1's pre-push find-and-replace — the placeholder username in plugin.json will break installs otherwise.

---

## Versioning

This plugin uses semver. Major changes (a new phase added, the SKILL.md restructured) are major version bumps; new framework references or template tweaks are minor; typo and clarification fixes are patch.

Current version: **0.2.0** — adds Phase 0 (Context), kill gate, assumptions inventory, user research input, metrics validation, journey-before-wireframes ordering, pricing in GTM, timeline reconciliation, and revision mode.

v0.1.0 was a 17-skill library which has been collapsed into this single orchestrating skill. The framework files from v0.1.0 are preserved as references inside this skill.

## Provenance

Fifteen framework reference files are forked from upstream, with full attribution preserved. The orchestrating skill, the PRD template, and the methodology that ties them together are original.

Distributed under Apache-2.0, compatible with both upstream license terms (Apache-2.0 and MIT). Upstream attribution is preserved in each file's frontmatter and at the top of `ATTRIBUTION.md`.

## License

Apache-2.0. See [`LICENSE`](./LICENSE).
