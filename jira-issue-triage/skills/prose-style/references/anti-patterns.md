# Anti-Patterns Reference

Every pattern here is a tell. When a reader sees these, they know a model wrote it.

---

## Punctuation and Structure

**Em dash (—)**

> The system failed — causing a cascade of errors.

Fix: restructure. "The system failed, which caused a cascade of errors." Or split into two sentences.

**Spaced hyphen as separator ( - )**

> The fix is simple - just restart the service.

Fix: use a period or a comma. "The fix is simple: restart the service." Never use ` - ` as a clause separator.

**Parenthetical pile-ups**

> The approach (which has been validated by the team and is consistent with prior art) works well.

Fix: make it a sentence, or cut it. "The team validated this approach. It works well."

---

## Opener Patterns

Delete these outright. They add zero meaning and signal immediately that a model is talking.

- "Certainly!" / "Of course!" / "Absolutely!" / "Sure!"
- "Great question!"
- "I'd be happy to help with that."
- "I'll walk you through..."
- "Let me explain..."
- "I'm glad you asked."

Also cut soft openers that delay the answer:

- "It's worth noting that..." (just say it)
- "It's important to understand that..." (just say it)
- "Before we dive in..." (just dive in)
- "To answer your question..." (just answer it)

---

## The LLM Lexicon

These words appear in AI output at a rate that no human writer would match. When you see them, replace with plain language or cut.

| Word | Plain alternative |
|------|-------------------|
| delve | look, explore, dig into |
| leverage / harness | use |
| utilize | use |
| robust / solid / bulletproof | strong, reliable (or just describe what it does) |
| streamline | simplify, speed up |
| seamlessly / frictionlessly | smoothly, without friction (or just describe the integration) |
| comprehensive | thorough, complete, full |
| nuanced | specific, subtle, careful |
| elevate | improve, raise |
| foster | build, encourage, support |
| notably / significantly / meaningfully | (cut; vague intensifiers) |
| importantly | (cut; just say the thing) |
| furthermore / moreover | also, and |
| paradigm | model, approach, way of thinking |
| ecosystem | system, environment, tools |
| holistic | whole, full, end-to-end |
| innovative | new, better (or just describe it) |
| cutting-edge | new, recent (or just describe it) |
| synergy | (almost always cut) |
| empower | let, help, enable |
| facilitate | help, make possible |
| considerable / substantial | real, actual, large (or give the number) |
| impactful | useful, effective (or describe the impact specifically) |

**Near-synonym trap:** replacing a flagged word with its near-equivalent defeats the purpose. Common swaps to watch for:

- "solid" for "robust" (still a vague confidence signal)
- "frictionless" for "seamlessly" (same pattern, different word)
- "harness" for "leverage" (same verb, same tell)
- "considerable" for "significant" (both are vague intensifiers)
- "meaningful" for "impactful" (both dodge the actual number or effect)

When you catch yourself reaching for one of these, just describe the thing specifically instead.

---

## Sentence Structure

**"Here are X things to..."**

> Here are five ways to improve your API design.

Fix: just start with the first point, or use a plain statement. "Good API design comes down to a few things."

**Uniform bullet openers**

Every bullet starting "This allows...", "This ensures...", "This provides..." reads like a template. Vary the structure or collapse into prose.

**Passive voice hiding the actor**

> The issue was identified and resolved.

Fix: say who did what. "Engineering caught the issue and patched it Thursday."

**Stacked hedges**

> This may potentially be worth considering in some cases.

Fix: commit. "This is worth considering." Or cut the thought entirely if it is not strong enough to assert.

**Nominalization creep**

> The implementation of the feature resulted in an improvement of performance.

Fix: use verbs. "Implementing the feature improved performance."

---

## Conciseness Failures

**Leading with reasoning instead of the answer**

> Given the constraints of the system and the fact that the database is under heavy load, and considering that the current caching layer doesn't cover this query path, the answer is to add a cache.

Fix: "Add a cache. The database is under heavy load and this query path is not covered by the existing layer."

**Restating what was just said**

Ending a short response with "In summary..." or "To recap..." when the reader just read it. Cut.

**Filler transitions**

- "Moving on..." / "Next up..." / "Now let's look at..."
- "With that said..." / "That being said..."
- "At the end of the day..."

**Over-qualifying**

- "very", "quite", "really", "extremely", "incredibly" (cut unless the degree is meaningful)
- "somewhat", "a bit", "kind of" (usually softening a claim that should be stated plainly)

**Throat-clearing openers**

> In this section, we will explore the various factors that contribute to the overall performance of the system.

Fix: just start exploring. Or cut the section header and merge it into the previous section.

---

## Bullet Overuse

Bullets are for genuinely list-like things: steps, options, items. They are not for prose that happens to have multiple points.

**When bullets hurt:**

- A 2-sentence thought split into 4 single-line bullets loses context and rhythm.
- Bullets create artificial parallelism that flattens meaning.
- A response that is 80% bullets reads like a template, not a person.

**Heuristic:** if you could connect the bullets with "and", "but", or "because" and it reads naturally, write it as prose instead.
