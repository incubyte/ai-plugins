---
name: prose-style
description: 'Rewrites or audits prose to eliminate AI writing patterns and produce natural human writing. Use when the user says "AI slop", "sounds generated", "too formal", "write like a human", "fix the writing", "rewrite this", "clean up the prose", or asks for writing style guidance. Also apply proactively when generating documentation, Slack messages, Confluence pages, Jira ticket text, or any long-form prose output.'
metadata:
  author: Taha Bikanerwala
tools: Read
---

# Prose Style

Rewrite or audit text so it reads like a person wrote it. Strip the patterns that signal a model is talking: em dashes used as separators, opener phrases, LLM vocabulary, bullet sprawl where prose would do. The skill never invents content; it changes phrasing, structure, and word choice while every fact and claim from the input survives.

## Setup

**Read both reference files before doing anything else.** They contain the complete catalog and calibration examples needed to do this correctly.

1. Read `references/anti-patterns.md` for the full catalog of patterns to avoid, with corrections.
2. Read `references/examples.md` for before/after pairs that calibrate the difference between AI output and natural prose.

Do not proceed until both files are loaded.

## Calling Convention

The skill works two ways. When a user pastes text and asks for a rewrite or audit, run end to end. When the `jira-issue-triage` agent calls this skill, take the input the agent passes and return the cleaned version. The agent invokes the skill at two points in the workflow:

| Caller invocation point | Input the skill receives | Return value |
|-------------------------|--------------------------|--------------|
| Phase 2.5 (draft cleaning) | The drafted assessment comment, scope summary, or reporter follow-up question text (still in markdown shape, before ADF construction). | The same text with prose-style rules applied. The agent uses the cleaned text both for the Phase 3 preview shown to the user and as the source of the ADF nodes built in Phase 4a, 4b, or 4c. |
| Phase 5 (refinement cleaning) | The refined title and description produced by `jira-ticket-refiner`. | The same content with prose-style rules applied, ready for the Phase 5 user-facing preview. |

In both contexts, the skill never posts to Jira on its own. The agent owns the `addCommentToJiraIssue` and `editJiraIssue` calls.

- **One pass over the input.** Scan, flag, rewrite, verify. No iterative back-and-forth with the user unless asked.
- **Audit mode is read-only.** When the user asks to audit without rewriting, list violations grouped by category, one line each. Do not produce a rewrite.
- **No content invention.** The rewrite preserves every fact and claim from the input. It changes phrasing, structure, and word choice. It does not add or remove substance.

## Core Principle

The reader should never suspect a model wrote this. No tells: no em dashes, no spaced hyphens used as separators, no opener phrases, no LLM vocabulary, no bullet lists where prose would do. Say the thing directly. Lead with the answer. Cut everything that does not add meaning.

## Workflow

| Step | Action |
|------|--------|
| 1. Scan | Read the full text and identify every anti-pattern instance using the loaded catalog. |
| 2. Flag | Note each violation by category (punctuation, opener, word choice, structure, conciseness). |
| 3. Rewrite | Produce the revised version. Do not explain each change unless asked. |
| 4. Verify | Re-read the output before delivering. Check: (a) any catalog pattern still present, (b) near-synonyms of flagged words introduced (e.g. "solid" for "robust", "frictionless" for "seamlessly"), (c) whether it is terse-and-natural vs. terse-and-abrupt. Fix anything found. |

When asked to audit without rewriting, list only the violations, grouped by category, one line each.

## Critical Rules (Always Active)

- Never use em dashes (—). Restructure the sentence.
- Never use spaced hyphens as separators ( - ). Use a period or rewrite.
- Never open with "Certainly!", "Great question!", "Of course!", or similar.
- Lead with the answer. Reasoning comes after, only if needed.
- No trailing summaries on short responses.
- Terse is not the same as abrupt. Removing filler is correct; removing context the reader needs is not. If the output would feel curt coming from a colleague, add one clause back.

## Anti-Patterns

These are hard rules. Each one prevents a failure mode that has been observed on real rewrites.

1. **Never replace a flagged word with a near-synonym.** Swapping "robust" for "solid" or "leverage" for "harness" defeats the purpose. Describe the thing specifically instead.
2. **Never preserve the opener pattern while changing the words.** Replacing "Certainly!" with "Absolutely!" or "Sure thing!" is the same violation.
3. **Never split prose that flows naturally into bullet points just to add structure.** Two-sentence thoughts split into four single-line bullets lose context and rhythm.
4. **Never add a "to summarize" or "in conclusion" line to a short response.** The reader just read it.
5. **Never hedge a claim that should be stated plainly.** "This may potentially be worth considering in some cases" is a way of avoiding the assertion. Either commit or cut.
6. **Never invent content during the rewrite.** The rewrite changes phrasing, not substance. If a fact is missing, leave it missing.
7. **Never confuse terse with rude.** Removing filler is correct; stripping context a colleague would expect is not. Re-add one clause when the output would land cold.
