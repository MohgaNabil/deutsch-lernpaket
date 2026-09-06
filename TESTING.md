# Testing this repo

This repo has no app, build, or CI — it's `SKILL.md` prompt files (natural-language instructions Claude runs on a schedule), one JSON config, and a static HTML dashboard. A normal unit-test suite doesn't apply. Instead, testing happens in two layers:

1. **Automated checks** (`scripts/verify-repo.sh`) — repeatable, scriptable regression checks for the "plumbing": file structure, JSON validity, and cross-file consistency between `learning-config.json`, the SKILL.md templates, and `dashboard-template.html`. Run these after any edit.
2. **Manual QA scenarios** (below) — since a `SKILL.md` file is a prompt, not code, whether it actually *behaves* correctly can only be verified by running it as a live Claude conversation and checking the output. These are organized around the core logic every skill depends on: onboarding produces the right config, the three scheduled skills correctly consume that config, their output is correct, and sessions export correctly to Apple Notes.

## Automated checks

```
./scripts/verify-repo.sh
```

Covers:

1. **Structure** — all 4 skill folders exist with a `SKILL.md`; each `.skill` zip's contents match its folder's `SKILL.md` exactly (catches a stale zip after an edit).
2. **Frontmatter** — each `SKILL.md`'s `name:` matches its folder name.
3. **Config validity** — `learning-config.json` parses as JSON and has every schema key.
4. **Variable-declaration consistency** — every `{snake_case}` placeholder used in a scheduled `SKILL.md`'s body is declared in that file's Step 0 "extract and use" list. (This is the exact class of bug we found by hand once already: `language-weekend-review/SKILL.md` used `{grammar_structures}` without declaring it.)
5. **Grammar-structure key consistency** — `learning-config.json`'s `grammarStructures` never duplicates the fixed "Complex sentences (subordinate clauses)" row, and every key in `dashboard-template.html`'s `b2` chart object traces back to either that fixed row or an entry in `grammarStructures`. (This is the other bug we found by hand: a stray `"Nebensätze"` entry that the dashboard chart didn't know about.)
6. **Mistake-category set consistency** — `dashboard-template.html`'s `CATEGORY_COLORS` keys exactly match `learning-config.json`'s `mistakeCategories`.
7. **Table-header contract** — the literal English table headers in `daily-language-practice/SKILL.md`'s note templates (Word/Plural, Adjective, Infinitive, Idiom, Category/Wrong, Metric) each have a matching detection string in the dashboard's `parseNote()`. If a future edit changes a header on one side without the other, this fails.
8. **No leftover hardcoded literals** — grep sweep for `Deutsch B2`, `Deutsch lernen B2`, `🇦🇹`, `B2-Umformulierung`, `Sonstiges`, `Unbekannt` across the 4 skill folders, excluding `learning-setup/SKILL.md`'s intentional documented examples.
9. **Dashboard JS syntax** — the `<script>` block parses cleanly (via JavaScriptCore/`osascript`, or `node --check` if available).
10. **README/CHANGELOG cross-reference** — old skill names don't leak into README.md; CHANGELOG.md is reported for visibility (historical entries are expected to keep the old names).

The script prints ✓/✗ per check and exits non-zero on any failure, so it's usable as a pre-commit hook or CI gate. It was sanity-tested by deliberately reintroducing both previously-fixed bugs — it caught both plus a stale `.skill` zip as a bonus — before being reverted.

## Manual QA scenarios

Run as live Claude conversations. A note on **"frequency"**: the cron schedule (Tue/Thu 9am, Fri 9am, Sun 9am by default) is set when you create the scheduled task, per README's "Setting up the scheduled tasks" table — `learning-setup` doesn't ask about it and it isn't part of `learning-config.json`. The scenarios below test frequency as it exists today; if that split (onboarding configures everything except cadence) is confusing in practice, that's worth raising as a follow-up, not something to paper over here.

### 1. Onboarding produces the right config (`learning-setup`)

Run onboarding with a specific, written-down set of intended answers, then diff the resulting `learning-config.json` against them:

- [ ] **Target language & level**: answer "French, B1" → confirm `targetLanguage: "French"`, `targetLanguageCode: "fr"`, `cefrLevel: "B1"` exactly (not left at the German/B2 default, not mis-normalized).
- [ ] **Emoji correctness**: the proposed `targetFlagEmoji` is actually right for the language (French → 🇫🇷, not defaulted to 🇦🇹), and ambiguous cases (German → 🇩🇪 vs 🇦🇹, Chinese → Mandarin vs Cantonese) are *asked* rather than silently guessed.
- [ ] **Notes folder**: `notesFolderName` reflects the language/level (or the exact preserved `"Deutsch lernen B2 🇦🇹"` string when a German learner chooses to keep it) — not a stale value from a previous run.
- [ ] **Frequency**: the conversation is honest that cadence isn't part of `learning-config.json` and points to the README cron table; when you then set up the scheduled tasks, the cron expressions you choose match the frequency you actually want.
- [ ] **Re-run behavior**: "keep as-is" leaves the file byte-for-byte unchanged; "update level only" changes only `cefrLevel` (and `updatedAt`), nothing else.

### 2. The 3 skills correctly pick up target language, emoji, folder, level, and frequency

With a non-default config in place (e.g. the French/B1 config from above), for each of the 3 scheduled skills:

- [ ] **Target language**: every in-chat line and every note section is actually in French — no leftover English UI-chrome bleeding into content, no leftover German.
- [ ] **Emoji**: 🇫🇷 prefixes every French line, the configured base flag prefixes every English line, consistently through the whole session and the saved note.
- [ ] **Notes folder**: the note lands in the *exact* folder name from `notesFolderName` (verify with `list_notes` on that folder right after), not the German default folder.
- [ ] **Level**: corrections, paraphrases, and vocabulary are pitched at B1, not B2 — the "level paraphrase" section should read simpler/less elaborate than a B2 sample.
- [ ] **Frequency**: the skill only triggers on its scheduled cron; cross-check the scheduled task's cron expression against the intended cadence once per skill.

### 3. Output of each skill is correct

- [ ] **daily-language-practice**: one question per turn (never 3+), a level-appropriate paraphrase after every answer (never skipped), every mistake tagged with exactly one category from the configured taxonomy, target-language diacritics used correctly, note has all 8 sections (A-H + Next Steps) populated.
- [ ] **language-weekend-review**: 10-15 questions across 4-5 labeled rounds, one question per message, the mandatory Mistake Rewind round pulls *real* past mistakes (not placeholder text) when prior notes exist, running score updates correctly.
- [ ] **language-sunday-writing-listening**: listening and translation share one theme, comprehension questions are answerable from the actual fetched transcript, sentence-by-sentence corrections each get a category and a level paraphrase, full reference translation at the end.
- [ ] Cross-skill: no em dashes anywhere; tone stays warm/simple/neurodiverse-friendly per each file's "CRITICAL USER PREFERENCES" block.

### 4. Sessions export correctly to the notes folder

- [ ] **Creation, not mutation**: each session creates a *new* note via `add_note`; `list_notes` before/after shows no existing note's content changed.
- [ ] **Correct folder**: the new note is found in `notesFolderName`, not a default/other folder.
- [ ] **Correct title**: matches the configured `notePrefixes` entry plus date (and theme, for daily/Sunday) — e.g. `"French B1 Conversation, 2026-09-05, [theme]"`.
- [ ] **Same-day collision handling**: running the same skill twice in one day produces a second note with a `" (2)"` or time suffix, not an overwrite or an error.
- [ ] **Read-only history access**: `list_notes`/`get_note_content` calls used for vocabulary reuse or past mistakes never mutate the notes they read.

### Dashboard checks

- [ ] Open with the shipped default `CONFIG`: title/heading/sample charts/tables match the pre-refactor baseline, no console errors.
- [ ] Edit `CONFIG` to a different language/level and reload: title/heading update, nothing crashes.
- [ ] Live-load path (Apple Notes connector available): quiz notes are matched correctly; a note produced by the new English-labeled templates — including one saved to a non-default folder/language from scenario 2 — parses correctly into vocab/mistakes/stats once `CONFIG` is updated to match.

### Cross-cutting

- [ ] Full lifecycle: run `learning-setup` for a new language → run all three practice skills once each → confirm every session exported to the right folder with the right title → open the dashboard → confirm a coherent end-to-end story with nothing orphaned.
- [ ] Re-confirm both previously-fixed bugs stay fixed (covered automatically by `scripts/verify-repo.sh`, but worth a manual glance at real generated note content too).
