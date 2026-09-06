# Language Learning Skill Pack

Four Claude skills for a full weekly language practice routine: one-time setup, plus a Tue/Thu conversation, a Friday quiz, and a Sunday listening + translation session, all configurable for any language and any CEFR level (A1-C2).

## What's inside

| Skill | When it runs | What it does |
|---|---|---|
| **learning-setup** | Once, on demand (via Claude Code) | Asks for your target language, base language, and CEFR level, then writes `learning-config.json`. Re-run any time to change language or level. |
| **daily-language-practice** | Tue + Thu, 9 AM | Live 30-min conversation in your configured target language. Catches every mistake with a category label, always adds a level-appropriate paraphrase, saves a rich Apple Note with vocabulary, verbs, idioms, mistakes, reused items, and stats. |
| **language-weekend-review** | Fri, 9 AM | Game-show quiz format with 4-5 themed rounds and 10-15 questions max. Mandatory "Mistake Rewind" round that re-tests past mistakes. Saves a scored quiz note. |
| **language-sunday-writing-listening** | Sun, 9 AM | Listening round using real audio/video from your configured (or freshly-searched) sources, plus a translation round on the same theme. Sentence-by-sentence corrections with level-appropriate reformulations. |

All three practice skills save summary notes into a single Apple Notes folder configured during setup (`notesFolderName` in `learning-config.json`), which lets you build a growing library of your own learning history and power `dashboard-template.html`, the progress dashboard included in this repo (see below).

## Setup (run this first)

1. Open this repo in **Claude Code** (the `learning-setup` skill needs local filesystem access to write `learning-config.json`; it isn't meant to run as a scheduled Apple Notes-only task like the other three).
2. Run the `learning-setup` skill, or copy `learning-setup/SKILL.md` into a Claude Code conversation.
3. Answer the questions: target language, base language, CEFR level, flags, Apple Notes folder name, note title prefixes, mistake taxonomy, and (for the Sunday skill) content sources.
4. Claude writes `learning-config.json` to the repo root. The pack ships with this file pre-filled for German/B2, so if you're happy with that, you can skip setup entirely and start using the skills right away.

The three scheduled skills read `learning-config.json` at the start of every run. If it's missing, they'll tell you to run `learning-setup` first.

## Design principles

- **One question at a time.** Gentle rhythm that's easy to follow. No message ever asks more than two questions.
- **Bilingual formatting.** Every target-language line is bold with your configured target-language flag, followed by a blank line and the base-language translation with your configured base-language flag. Easy to scan, easy to have your Mac read the target language aloud.
- **No em dashes.** Uses commas, periods, pipes, or middle dots as separators.
- **Proper diacritics and special characters always** (e.g. German umlauts ä, ö, ü, ß). No ASCII substitutes.
- **Level paraphrase after every mistake.** Shows the upgrade path from "correct but plain" to "fluent at your level" on every turn.
- **Mistake categories.** Each mistake gets one label from your configured taxonomy (default: 10 categories covering grammar, vocabulary, and spelling) so you can spot patterns over time.

## Installation

### Option A: Install the `.skill` files (easiest)

1. Download the `.skill` file you want from the [releases page](../../releases) or from this repo.
2. Drag the file into Claude (Claude Code, Cowork, or claude.ai).
3. Click **Save skill** in the file preview.
4. The skill is now available for scheduled tasks and manual invocation.

### Option B: Copy the SKILL.md manually

1. Open the folder for the skill you want (e.g. `daily-language-practice/`).
2. Copy the entire content of `SKILL.md`.
3. In Cowork or Claude Code, create a new scheduled task and paste the content as the prompt.

## Setting up the scheduled tasks

`learning-setup` is run on demand, not scheduled. The other three skills run as scheduled tasks with these cron expressions (times in your local timezone):

| Skill | Cron | Human-readable |
|---|---|---|
| daily-language-practice | `0 9 * * 2,4` | Tuesday & Thursday at 9:00 AM |
| language-weekend-review | `0 9 * * 5` | Friday at 9:00 AM |
| language-sunday-writing-listening | `0 9 * * 0` | Sunday at 9:00 AM |

In **Cowork**:
1. Open the Scheduled section in the sidebar.
2. New scheduled task → paste the SKILL.md prompt.
3. Set the cron expression from the table above.
4. Save.

In **Claude Code**:
1. Use the `mcp__scheduled-tasks__create_scheduled_task` MCP tool.
2. Pass the SKILL.md content as `prompt`, and the cron string as `cronExpression`.

## Required connectors

The three scheduled skills need **Read and Write Apple Notes** access (macOS only) to save session summaries. Grant permission when Claude first asks.

The **Sunday writing & listening** skill also uses **WebSearch and WebFetch** to find a fresh podcast or video episode each week (or to rotate through the sources set during `learning-setup`). Both are typically available by default.

`learning-setup` additionally needs local filesystem write access, since it writes `learning-config.json` directly, rather than using the Apple Notes connector.

## Customization

- **Learner name.** The prompts refer to "the learner" (generic). Search and replace with your name for a personal touch.
- **Time of day.** Change the `0 9` in the cron to any hour that fits your schedule (`0 7` for 7 AM, `30 20` for 8:30 PM, etc.).
- **Frequency.** The daily practice runs Tue/Thu (`* * 2,4`). Swap to Mon-Fri with `* * 1-5`, or every day with `* * *`.
- **Language, level, folder name, sources, and taxonomy.** All handled by `learning-setup` and `learning-config.json` now, no manual find/replace needed. Re-run `learning-setup` any time you want to change any of them.

## Recommended companion: progress dashboard

`dashboard-template.html` is a self-contained HTML dashboard that reads the Apple Notes saved by these skills and visualizes progress over time: session streak, mistake categories (pie chart), sticky category patterns, cumulative vocabulary growth, level-appropriate structures used, and a tabbed Vocabulary Explorer (Nouns & Adjectives / Verbs / Idioms / Ready to Reuse / Reused).

It ships with sample data (German/B2) so you can see the shape it expects. To make it yours:

1. Open the file in a browser, or drop it into Cowork as an artifact.
2. If your `learning-config.json` isn't German/B2, update the `CONFIG` object near the top of the `<script>` block to match it (target language, level, flags, note title prefixes).
3. Ask Claude: "read my notes from Apple Notes and rebuild this dashboard with my real sessions."
4. Claude will replace the `SNAPSHOT_SESSIONS` and `SNAPSHOT_REVIEW_DATES` constants near the top of the `<script>` block with your actual data, keeping `CONFIG` in sync with `learning-config.json`.

Re-run step 3 any time you want it refreshed. If you're running it as a Cowork artifact with the Apple Notes connector available, it can also try a live refresh via the "Refresh" banner button instead of a full manual rebuild.

## License

MIT. Use freely, remix, share. Attribution appreciated but not required.

## Feedback

If you use these skills and something feels off (too strict, too gentle, too much scaffolding, unclear formatting), open an issue with a concrete example. The skills have been iterated many times based on real-world use, and every new use case makes them better.

Good luck with your language learning journey!
