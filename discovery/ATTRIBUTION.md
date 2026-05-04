# Attribution

This plugin draws on three open-source skill libraries. Material from those repositories lives in `skills/product-discovery/references/frameworks/` and is read internally by the orchestrating skill at the appropriate phases. All upstream licenses are preserved and compatible with this plugin's Apache-2.0 license.

## Upstream sources

### pm-skills
- **Repository:** https://github.com/product-on-purpose/pm-skills
- **License:** Apache-2.0
- **Author:** product-on-purpose (Jonathan Prisant)

### claude-plugin-product-management (pmprompt)
- **Repository:** https://github.com/pmprompt/claude-plugin-product-management
- **License:** MIT
- **Author:** pmprompt

### claude-gtm-plugin
- **Repository:** https://github.com/manojbajaj95/claude-gtm-plugin
- **License:** MIT
- **Author:** Manoj Bajaj

## Forked files

All forked content lives at `skills/product-discovery/references/frameworks/` and retains upstream attribution comments and license fields.

| Plugin file | Upstream source | Upstream license |
|---|---|---|
| `problem-statement.md` | pm-skills `skills/define-problem-statement/SKILL.md` | Apache-2.0 |
| `jtbd-canvas.md` | pm-skills `skills/define-jtbd-canvas/SKILL.md` | Apache-2.0 |
| `opportunity-tree.md` | pm-skills `skills/define-opportunity-tree/SKILL.md` | Apache-2.0 |
| `hypothesis.md` | pm-skills `skills/define-hypothesis/SKILL.md` | Apache-2.0 |
| `persona-canvas.md` | pm-skills `skills/foundation-persona/SKILL.md` | Apache-2.0 |
| `competitive-analysis.md` | pm-skills `skills/discover-competitive-analysis/SKILL.md` | Apache-2.0 |
| `interview-synthesis.md` | pm-skills `skills/discover-interview-synthesis/SKILL.md` | Apache-2.0 |
| `stakeholder-summary.md` | pm-skills `skills/discover-stakeholder-summary/SKILL.md` | Apache-2.0 |
| `solution-brief.md` | pm-skills `skills/develop-solution-brief/SKILL.md` | Apache-2.0 |
| `experiment-design.md` | pm-skills `skills/measure-experiment-design/SKILL.md` | Apache-2.0 |
| `working-backwards.md` | pmprompt `skills/working-backwards/SKILL.md` | MIT |
| `positioning-canvas.md` | pmprompt `skills/positioning-canvas/SKILL.md` | MIT |
| `prioritization.md` | pmprompt `skills/feature-prioritization-assistant/SKILL.md` | MIT |
| `monetizing-innovation.md` | pmprompt `skills/monetizing-innovation/SKILL.md` | MIT |
| `gtm-strategy.md` | gtm-plugin `skills/go-to-market-strategy/SKILL.md` | MIT |

## Original files

The following are original to this plugin (Apache-2.0):

- `skills/product-discovery/SKILL.md` — the orchestrating skill
- `templates/PRD.md.template` — the canonical PRD structure
- `.claude-plugin/plugin.json`
- `README.md`
- `ATTRIBUTION.md`

## Note on framework files

These files are stored as plain markdown (not as invocable SKILL.md files) because they're *internal references* the orchestrating skill reads at specific phases. The user never invokes them directly. Their YAML frontmatter from upstream is retained for documentation and provenance, but the loader does not register them as skills.
