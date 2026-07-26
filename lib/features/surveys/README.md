# Surveys

Surveys are short structured questionnaires the user can fill in — currently a
small fixed set — whose result is saved as a journal entry alongside everything
else.

## What it does for the user

- **Runs a questionnaire.** A guided flow through the questions rather than a
  wall of fields.
- **Scores it.** Answers are turned into a meaningful bucket rather than left as
  raw numbers.
- **Keeps it with everything else.** The result is a journal entry, so it appears
  on the timeline, can be charted on a dashboard, and syncs like any other entry.

The questionnaires are built in; this is not a survey builder.

## What it owns

The survey definitions, the modal runner around them, the scoring, and
persistence as a survey entry.

## Where the code lives

```text
lib/features/surveys/
```

## How it works

Why scoring happens at submission time, and what that buys, is documented in the
knowledge bundle:

**→ [knowledge/features/surveys/](../../../knowledge/features/surveys/)**
