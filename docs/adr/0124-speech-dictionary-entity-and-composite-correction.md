# ADR 0124: The Speech Dictionary Is Its Own Entity, and a Speech-to-Text Transcript Is Corrected in Its Summary Call

- Status: Accepted
- Date: 2026-10-06

## Context

Speech-to-text engines (Whisper and its kin) misspell names, places and
jargon: they return what they heard, and the dictionary reaches them only as
a vocabulary hint not every engine honours. A multimodal model that listens
to the audio under a prompt reads the dictionary and spells it as given.

The dictionary was a list on each category (`speechDictionary`). A term used
everywhere had to be added to every category, and it could not say which
spelling it tends to come out as. ADR 0024 proposed a global correction
lexicon with deterministic replacement; it was never built.

A task-linked recording was already summarized after transcription, in a
second model call. Before it, the raw transcript was written into the
recording's text, so the reader saw it and then — after nothing changed it —
kept it, misspellings and all.

## Decision

- **One synced entry per term** (`EntityDefinition.speechDictionaryEntry`),
  limited to a set of categories (none for every category), carrying the
  spellings it is misheard as. The id is derived from the normalized term,
  so a term is one entry on every device.
- **The category lists are carried over, not merged.** Every device migrates
  each term it holds no entry for, at the epoch stamp, through a write that is
  refused rather than re-stamped when a copy is stored. Equal stamps are
  ordered by content. `specs/tla/SpeechDictionarySync.tla` gives each rule a
  counterexample; one document per term with a merging migration lost a
  user's narrowing of a term.
- **Correction rides on the summary call.** For a speech-to-text engine's
  transcript in a task's context, the audio summary publishes, besides its
  three tiers, quoted corrections against the dictionary entries that reach
  the recording. Code applies them; the model never rewrites the transcript.
  The recording's text is held until then and written once, corrected — or
  raw when the summary fails — unless the user edited it meanwhile.
- **Misheard spellings are evidence, not rules.** They are listed in the
  prompt and learned from applied corrections, and never replaced blindly:
  the heard word may be the one the speaker meant. ADR 0024's `hardReplace`
  is not adopted.
- **The summary is bounded by the recording.** It reads the task's title,
  language and current report — not the task's log, other recordings'
  transcripts or linked tasks.
- **A multimodal transcription is unchanged.** Its text is written at once,
  and its summary's corrections are ignored.

## Consequences

- One call per recording still produces the one-liner, the TLDR and now a
  corrected transcript; a correction costs only the quoted edits' tokens.
- A recording's text appears once, after the summary call, instead of
  flashing the raw transcript first.
- The legacy lists remain on categories and are read only by the migration.
- Concurrent edits of one term keep one of them (last writer wins), as for
  every definition; a learned spelling can overwrite a category change made
  on another device in the same sync window.
- A transcription the user asks for in a task's context on a speech-to-text
  engine now includes the summary call: on such an engine that call is what
  makes the transcript match the task.
