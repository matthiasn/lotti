# ADR 0162: She Says the Task Is Made

- Status: Accepted
- Date: 2026-11-08
- Concepts: [front agent](../../knowledge/features/front_agent.md#a-task-from-her-words)
- Amends: [ADR 0160](0160-a-dictated-task-is-filled-from-the-words.md), consequence "Nothing she says confirms the creation itself"

## Context

A dictated task waits for the user's tap (ADR 0160). Her spoken reply to the
dictation says the task is *ready to confirm*. After the tap, nothing was
said. The card's *Made into a task* was the only receipt. For someone who
talked to her, possibly with the phone at arm's length, that receipt is
silent. The demo flow reads as unfinished: a spoken note, one tap, then
silence.

## Decision

1. **The tap that makes the task is confirmed aloud.** Once *Make it a task*
   has written the task, she says one short line in her own voice:
   `frontTaskCreatedSpoken`, "Hey, dear, I created that task." It is
   localized like every other string, so the wording lives in the ARB
   catalogs.
2. **It is one of her answers, not a new voice path.** It goes through
   `FrontVoice.speak` under the conversation on screen. Her mute
   (`speaksReplies`, Settings › Preferences › Companion › Her voice, and the
   header's switch) silences it. So does read-aloud being off. Her voice is
   whatever her profile resolves to: cloud, else on-device. It takes the
   voice over from whatever is playing, and her lips follow it.
3. **Only a task actually made is confirmed.** A tap that fails, or a second
   tap on a busy door, says nothing; the card shows the failure.
   `FrontChatController.makeTask` answers whether the task was made.
4. **The line is the same whether the dictation was spoken or typed.** The
   tap is neither a spoken nor a typed turn, so the spoken-turn rule does
   not decide it. The mute is the user's control for silence.

## Consequences

- Her reply before the tap still never says the task was created. Only
  this line after the tap does.
- *Say it again* replays her latest answer to a turn, not this line.
- Still no audio is linked to the task (ADR 0160): her recorder deletes the
  clip, and the verbatim words under the task remain the provenance.
