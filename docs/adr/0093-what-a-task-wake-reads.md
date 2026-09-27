# ADR 0093: What a Task Agent's Wake Reads as Input

- Status: Accepted
- Date: 2026-09-27
- Amends: [ADR 0091](0091-wake-coordination-by-vector-clock-coverage.md)

## Context

Under ADR 0091 a device drops its task-agent wake when a peer's run read
every write its inputs rest on. The inputs therefore have to include
everything the context builders put in front of the model: a row the
context reads but the inputs miss can change the prompt without making the
device uncovered, and its wake is dropped with that input unprocessed.

ADR 0091's inputs were only the task's journal neighbourhood and the linked
tasks' agent reports. A review found the parent project's agent report
missing. An audit of the context builders then found more: the user's
decisions on the agent's proposals, the template and soul behind the system
prompt, attention requests on the task, and the label and category
definitions.

## Decision

A wake's inputs are the rows its context reads that **someone other than
this agent's wakes wrote**:

- the task's journal neighbourhood, removed rows included (ADR 0091);
- the agent link and current report of every linked task's task agent and
  of the parent project's project agent;
- the user's decisions on this agent's proposals for the task — not the
  agent's own retractions;
- the template assignment, the template's head and active version, the soul
  assignment and the soul's head and active version;
- attention requests other agents raised on the task.

**This agent's own writes are not inputs**: its report, observations,
messages, change sets, memory and its own attention requests. They are what
a run produces, not what it responds to. A peer's run writes its own, with
its host's counters above the watermark its claim carried, so counting them
would make every completed run look uncovering to the device it should
cancel. The agent's state and identity are left out too. They choose the
task, the model and the turn budget, not what the run reads. And the
throttle writes the state on every device that is waiting to run.

**Label and category definitions** carry no host counter. They are ordered
by `updatedAt`, created without a vector clock, and travel outside the sync
sequence log, so no watermark can vouch for them. The claim carries a digest
of the label definitions (private ones included) and the task's category,
and only a peer with an equal digest covers. Definitions rarely change, so
exact equality costs little here.

## Consequences

- A device whose project agent has a newer report than the peer's run saw,
  or where the user rejected a proposal the peer's run did not know about,
  runs instead of being dropped.
- The inputs still read wider than the context renders, which can only cost
  a run, never drop one.
- Three things the prompt shows stay device-local and are not inputs. A
  running timer is held in memory; the entry it times is a journal row, and
  that row is covered. The "changed since last wake" hints come from the
  local notification. The model and profile are the device's own
  configuration. A peer's run that covers a device can therefore have been
  shown a different timer hint, different change hints, or a different model.
  None of these carries information the peer's run lacked.
- The message gains `definitionsDigest`. #4526 is unreleased, so no
  deployed client sends the older shape.
