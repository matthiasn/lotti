# ADR 0123: Each Label Writer Decides on the Stored Task

- Status: Accepted
- Date: 2026-10-04

## Context

A task's labels have two writers: the user's label picker, and the task
agent's label assignment. Each holds a suppressed set as well
(`aiSuppressedLabelIds`): a label the user takes off is suppressed, so the
agent does not put it back, and one the user adds is unsuppressed. Every
write is built on the stored task (ADR 0083, ADR 0119). What each writer
took from its earlier read was still wrong:

- **The picker wrote the whole set.** `setLabels` wrote the labels the user
  chose and diffed them against the stored set. If the agent, or another
  device, put a label on while the picker was open, the picker's write took
  it off and suppressed it, as if the user had rejected a label they had
  never seen.
- **The agent checked suppression on its read.** The assignment processor
  read the suppressed set, validated the proposal against it, and only then
  wrote through `addLabels`. That was also the manual-add path, which
  checked nothing and unsuppressed what it added. If the user took the label
  off between the read and the write, the agent put it back and lifted its
  suppression.

We modelled both writers in `specs/tla/TaskLabels.tla`. With the picker
writing the whole set (`PickerDelta = FALSE`), TLC breaks `NoSilentRemoval`
in five states. With suppression checked only on the agent's read
(`SuppressionAtWrite = FALSE`), it breaks `RemoveWins`.

## Decision

- **The picker sends the user's edit.** `LabelsRepository.updateLabels`
  takes the labels added and removed: the difference between the picker's
  selection and the labels it opened with. It applies them to the stored
  labels, suppressing what it takes off and unsuppressing what it puts on.
  An edit that changes nothing writes nothing.
- **The agent's add decides on the stored task.** `assignLabels` adds only
  labels the stored task neither carries nor suppresses, decided inside the
  write. It never unsuppresses, because only the user lifts a suppression.
  It returns what it added.
- **The processor reports what was written.** A label the write did not add
  is skipped as `changed_since_read`. A write that failed assigns nothing
  and is reported as `write_failed`.
- `setLabels` and `addLabels` are removed.

## Consequences

- A label the agent put on while the picker was open survives the user's
  edit, and is not suppressed.
- A label the user took off stays off, whatever the agent read before.
- The agent's result tells the model when its proposal lost to a change made
  meanwhile.
