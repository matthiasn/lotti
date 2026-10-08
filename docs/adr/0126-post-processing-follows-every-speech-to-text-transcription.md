# ADR 0126: Post-Processing Follows Every Speech-to-Text Transcription, Framed by What the Recording Belongs To

- Status: Accepted
- Date: 2026-10-08

## Context

ADR 0124 made a speech-to-text engine's transcript go through one more call
after it lands: the audio summary corrects the misheard speech dictionary
terms and writes the recording's one-liner, TLDR and summary, and the
recording's text is written once, corrected. That step ran only for a
recording linked to a task, because the summary was framed by the task's
title and current report.

Most recordings are not about a task. A person check-in, a goal check-in, a
note on a project or an event, a standalone voice note — all were transcribed
by the same engines and kept their misspellings. Person check-ins had grown a
separate correction of their own: a second thinking-model call against the
names the check-in expects, with its own tool. And the goal check-in fallback
asked for the task-context transcription skill without a task, which the
skill trigger's task guard refused, so a goal check-in was never transcribed
automatically.

## Decision

- **Every speech-to-text transcription is post-processed**, whatever the
  recording belongs to and however the run started. Such an engine cannot
  read the dictionary or the context, so the correction is part of
  transcribing at all. A multimodal transcription keeps ADR 0124's rule: it
  read both in its own prompt, and chains a summary only when automated with
  an automated summary skill.
- **The frame is the recording's subject**, resolved separately from
  `linkedTaskId` (which stays a task id, since it also feeds task JSON,
  attribution and stale notifications): the task in `linkedTaskId`, else the
  entity linking to the recording — task, person (directly or through a
  check-in), goal, project, event. The frame is the subject's header and the
  current report of its newest agent; a goal's report only when written for
  its active spec version. With no subject, the dictionary alone frames the
  correction and the recording is summarized on its own. The bound of ADR
  0124 holds: never the subject's log or other recordings' transcripts.
- **A check-in's expected names join the correction** as entries that are
  corrected but never learned into the dictionary. The separate name pass and
  its tool are removed; the local correction by sound and spelling stays.
- **A run without a profile borrows one for post-processing**: the direct
  speech-to-text fallback uses the Settings default profile's audio
  post-processing route, else its thinking route. Without a default, nothing
  post-processes and the transcript is written as heard.
- **A recording's transcription and summary skills need no task.** The skill
  trigger lets them through without one, and the AI menu offers the summary on
  every recording, which also recovers a recording whose post-processing
  never finished.

## Consequences

- Every speech-to-text recording costs one more model call than before ADR
  0124 outside tasks: the composite call, on the profile's post-processing
  model. A recording that no dictionary term reaches and that is shorter than
  the summary floor is still skipped.
- Check-in text reaches the form after the post-processing, not right after
  the engine returns; the form already waits for the text.
- Goal check-ins are transcribed automatically again, and the compactor
  distils corrected text.
- The summary prompt no longer assumes a task: its language comes from the
  context's `languageCode`, else the recording's own language.
- Transcription that returns text to a caller instead of a recording (Daily
  OS capture, onboarding, chat voice input) is outside this decision; it goes
  through `AudioTranscriptionService`, not the runner.
- `specs/tla/TranscriptionRun.tla` is unchanged: its held-text configuration
  already includes the check-in waiter, and `WaiterResolves` holds through the
  fill.
