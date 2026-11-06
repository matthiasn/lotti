# ADR 0158: Goal Agents Write in a Language the Goal Names

- Status: Accepted
- Date: 2026-11-06
- Concepts: [goal agents](../../knowledge/features/goals.md#the-briefing-language)

## Context

A goal agent's system prompt told the model to use "the user's language in
prose" and never said which language that was. Every other word of a wake —
the prompt, the FACTS keys, the tool descriptions — is English, so a user who
journals in German got English briefings, reports and banners, and had no
setting that could change it. The app has no global "journal language"
either: the one place a user names the language their entries are kept in is
a category's *Default language*, and nothing at runtime read it.

## Decision

1. **The language is the agent's setting, on its identity.**
   `AgentConfig.languageCode` holds a `SupportedLanguage` code and syncs with
   the identity like the agent's other settings. It is not part of the goal
   spec: a spec revision mints a version, supersedes the goal's banners and
   retracts pending proposals, none of which a change of language warrants.
   The edit page saves it beside the revision (`updateBriefingLanguage`), so a
   language-only edit mints nothing.
2. **Null follows the journal.** A goal nobody picked a language for is
   briefed in the default language of the category it is filed in — the
   category its check-ins are recorded into — read at wake time, so changing
   the category's language (or moving the goal) moves the briefings with it.
3. **A picked language stands; the journal's is only suggested.** When the
   journal's language moves away from a language picked by hand, the edit page
   offers *Use German* under the field and applies it only when taken.
4. **Every wake names its language in FACTS.** `language` is always present:
   the resolved language as `de (German)`, or — with neither a pick nor a
   journal language — the instruction to write in the language of the user's
   own words and in English when there are none, which is what goals did
   before. The system prompt says *FACTS language in prose* in place of the
   unnamed "user's language", inside its 4,000-character ceiling.
5. **An unknown code reads as unset.** A code this build does not support —
   one a newer client wrote — falls through to the journal, never reaches the
   model as a bare string, and is never overwritten by an untouched form.

## Consequences

- Briefings follow the language a user already set for the category they
  journal in, without a new setting to find.
- A language change takes effect from the agent's next report; the standing
  report is not rewritten (and no wake is paid for) just because the setting
  moved.
- An older client that rewrites the identity's config drops the field, as it
  drops every config field newer than itself; the goal then follows its
  journal until the language is picked again.
- The category's *Default language*, whose settings caption speaks only of
  tasks, now also decides the briefings of the goals filed in it.
