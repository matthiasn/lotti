# Speech dictionary

The speech dictionary is the user's own vocabulary — names, places, product
and project jargon — that speech recognition keeps getting wrong. It is one
list for the whole app, and each term knows where it belongs.

## What it does for the user

- **Adds a word once.** A term is entered once and used for every recording it
  applies to, on every device.
- **Keeps niche words where they belong.** A term can be limited to some areas;
  with none chosen it applies everywhere. A word from one project never
  "corrects" a recording about another.
- **Remembers how a word gets misheard.** Each term can list the spellings it
  tends to come out as. The user can type them, and corrections the app makes
  are added automatically. They help the correction recognise the term; they
  are never replaced without looking at the context, because the heard word
  may be the one that was meant.
- **Fixes the transcript before anyone reads it.** For a recording in a task,
  transcribed by a speech-to-text engine such as Whisper, the summary step
  also corrects misheard terms, and the recording's text appears once,
  already corrected. The user can still edit it afterwards.
- **Is editable from the text itself.** Selecting a word in the editor and
  choosing *Add to Dictionary* adds it for that entry's area.
- **Keeps what the areas held before.** Terms that were kept on areas are
  carried over automatically, limited to those areas.

## What it owns

The dictionary entry's identity and scope rules, the repository that edits and
learns entries, the migration from the areas' old lists, and the settings pages
that list and edit entries.

It does not own transcription or the summary call — those live in
[ai](../ai/README.md), which reads the entries that reach a recording — nor
the editor's selection menu, which lives in [speech](../speech/README.md).

## Where the code lives

```text
lib/features/speech_dictionary/
├── domain/       term identity, scope, misheard forms
├── repository/   edits, the editor's add, learning
├── services/     migration from the areas' lists
├── state/        entry streams and the editor controller
└── ui/pages/     the settings list and details pages
```

## How it works

How entries sync, how the migration avoids undoing edits, and how a
transcript is corrected in the summary call are documented in the knowledge
bundle:

**→ [knowledge/features/speech/dictionary.md](../../../knowledge/features/speech/dictionary.md)**
