# Daily OS expert panel review

Date: 2026-07-16

Scope: Capture → Reconcile → Draft → Agenda/Day → manual adjustment

Test scenario: a dark-mode, heavily scheduled day for the fictional Director
of Interplanetary Penguin Logistics

## Method

The same four-person simulated panel reviewed the baseline and the final build.
Each reviewer scored the complete workflow, not an isolated beauty shot. The
review set included phone and desktop states, a long dictated transcript, the
first frame of AI processing, a dense agenda, Plan versus Actual, arrange mode,
and both standalone and task-linked block editing.

Scores are deliberately critical. A 9 means the workflow is coherent,
trustworthy, efficient, and pleasant enough for daily use under pressure; it
does not mean that no future refinement is possible.

Baseline evidence:

- [Fixed-height phone transcript](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/pr-screenshots/daily-os-ux-review/baseline/pro_05_captured_dark.png)
- [Read-only phone timeline](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/pr-screenshots/daily-os-ux-review/baseline/day_pro_02_timeline_dark.png)
- [Read-only desktop timeline](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/pr-screenshots/daily-os-ux-review/baseline/day_desktop_02_timeline_dark.png)
- [Later drafting shader; the earlier matching pass had no equivalent state](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/pr-screenshots/daily-os-ux-review/baseline/daily_os_shader_runtime_phone.png)

Final evidence:

- [First-frame AI processing](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/daily_os/0.9.1047/daily_os_shader_runtime_phone_dark.png)
- [Long transcript review](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/daily_os/0.9.1047/pro_05_captured_dark.png)
- [Reconcile decisions](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/daily_os/0.9.1047/pro_07_reconcile_dark.png)
- [Busy agenda](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/daily_os/0.9.1047/day_pro_01_agenda_dark.png)
- [Desktop Plan versus Actual](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/daily_os/0.9.1047/day_desktop_02_timeline_dark.png)
- [Arrange mode](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/daily_os/0.9.1047/day_pro_03_timeline_arrange_dark.png)
- [Block overview editor](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/daily_os/0.9.1047/day_pro_04_block_edit_overview_dark.png)
- [Task-linked block editor](https://raw.githubusercontent.com/matthiasn/lotti-docs/main/images/daily_os/0.9.1047/day_pro_06_block_edit_linked_dark.png)

## Scorecard

| Reviewer | Baseline | Final | Verdict |
| --- | ---: | ---: | --- |
| Productivity expert | 6.4 | 9.2 | Daily planning is now fast to capture, inspect, reshape, and accept. |
| Executive assistant expert | 5.8 | 9.1 | Commitments and ownership are explicit enough to manage a dense day safely. |
| Day planner | 6.2 | 9.3 | The schedule is now a calendar users can directly operate, not merely inspect. |
| Psychologist | 6.5 | 9.1 | The flow reduces uncertainty and decision fatigue without hiding consequences. |
| **Panel average** | **6.2** | **9.2** | **The same panel consistently clears the 9/10 target.** |

## Productivity expert

### Baseline — 6.4/10

The voice-first premise was strong, but the experience lost leverage after
capture. A long dictation appeared truncated, the initial AI wait looked
frozen, and the generated calendar could not be moved or resized. Users could
create a plan quickly but could not repair one equally quickly. Delayed task
metadata also undermined confidence that the schedule represented current
work.

Priority path to 9/10:

1. Make every scheduled block directly adjustable with move, resize, edit, and
   undo.
2. Preserve and expose the full dictated input before AI interpretation.
3. Show immediate, continuous system feedback from the first processing frame.
4. Keep linked task titles and categories live everywhere they are projected.
5. Make capacity, category allocation, and Plan versus Actual scannable before
   asking for commitment.

### Final — 9.2/10

- **Interactivity:** Arrange mode, fifteen-minute snapping, edge resize, full
  block editing, and Undo make correction faster than re-dictation.
- **Information architecture:** Capture, decisions, draft, agenda, and calendar
  each answer a distinct question and form a legible progression.
- **Visual design:** Capacity leads the agenda while the calmer metadata
  treatment preserves attention for titles and time.
- **Cognitive load:** Reconcile isolates consequential matches and updates
  before schedule generation.
- **Workflow efficiency:** The common path is voice-first; exceptions remain
  quick to fix with direct manipulation or one modal.
- **Emotional response:** The system feels responsive and recoverable rather
  than brittle.

Residual opportunity: keyboard nudging for selected blocks would make desktop
fine-tuning even faster, but its absence does not compromise the daily flow.

## Executive assistant expert

### Baseline — 5.8/10

The interface exposed a proposed schedule but did not yet behave like a
reliable operational record. A renamed or recategorized task could remain stale
on the calendar; the first AI pass offered no acknowledgment; and a bad time
slot required another voice turn. Those are trust failures in a day with fixed
commitments and dependencies.

Priority path to 9/10:

1. Establish clear source-of-truth rules between tasks, planned blocks, and
   recorded time.
2. Apply edits atomically and provide recovery for accidental adjustments.
3. Keep task name, category name, and category color synchronized immediately.
4. Expose start and end controls through the familiar time-recording editor.
5. Preserve placement reasons so the schedule remains explainable.

### Final — 9.1/10

- **Interactivity:** Every editable block exposes a pencil, while Arrange mode
  handles rapid calendar work.
- **Information architecture:** The editor overview groups title, category,
  timing, and placement reason; Start & end drills into a focused second page.
- **Visual design:** Task-owned fields are visibly read-only and paired with
  Open task, preventing edits in the wrong system.
- **Cognitive load:** Task, plan, and actual-time ownership is consistent and
  documented.
- **Workflow efficiency:** One atomic save prevents partial updates; live task
  metadata removes manual refresh rituals.
- **Emotional response:** Immediate feedback and Undo make the schedule safe to
  operate during a busy day.

Residual opportunity: multi-select block movement could help during a major
calendar disruption, but is not necessary for a strong individual planning
workflow.

## Day planner

### Baseline — 6.2/10

The app generated useful blocks but treated the calendar too much like output.
Without dragging, resizing, or a complete edit surface, it could not support
the ordinary negotiation between intention, available time, and emerging
reality. The short transcript box and stale category projection further
weakened the planning loop.

Priority path to 9/10:

1. Turn the existing custom calendar into a first-class editable surface.
2. Keep Plan and Actual visually distinct on one shared time axis.
3. Provide capacity and category balance before users approve the draft.
4. Preserve idle-time folding while allowing intentional expansion for edits.
5. Make voice refinement and manual changes complementary, not competing paths.

### Final — 9.3/10

- **Interactivity:** Body drag, top/bottom resize, explicit edit, pinch density,
  folded-region expansion, and Undo cover the core planning gestures.
- **Information architecture:** Agenda provides sequence and capacity; Day
  provides temporal shape and Plan-versus-Actual comparison.
- **Visual design:** Planned blocks remain sketch-like while actual recordings
  are filled, supporting rapid comparison without a legend hunt.
- **Cognitive load:** Arrange is an explicit mode, so handles appear only when
  useful and normal timeline browsing stays calm.
- **Workflow efficiency:** Voice can reshape the whole plan; direct manipulation
  can repair one block in seconds.
- **Emotional response:** The calendar now feels owned by the user rather than
  imposed by the model.

Residual opportunity: cross-day dragging could help when rescheduling beyond
midnight, though the current within-day boundary is safer and clearer for the
daily ritual.

## Psychologist

### Baseline — 6.5/10

The product had a promising externalization ritual, but ambiguity created avoidable
stress. A silent 10–20 second wait looked like failure, truncated text reduced
trust in what the model heard, and non-editable blocks encouraged all-or-nothing
thinking about an AI-generated plan. The dense day needed stronger progressive
disclosure and clearer user agency.

Priority path to 9/10:

1. Acknowledge input immediately and continuously during uncertain waits.
2. Let users verify the complete source text before interpretation.
3. Separate recognition, decisions, drafting, and acceptance into bounded
   cognitive steps.
4. Make change reversible and preserve the distinction between intention and
   reality.
5. Use calm hierarchy, fewer competing accents, and helpful explanations to
   reduce decision fatigue.

### Final — 9.1/10

- **Interactivity:** Direct editing and Undo reinforce agency and reduce fear of
  experimentation.
- **Information architecture:** Progressive disclosure gives each phase one
  dominant decision.
- **Visual design:** Dark-mode surfaces are calm, category color is meaningful,
  and processing animation is present without being duplicated.
- **Cognitive load:** The full transcript, confidence-aware reconciliation,
  capacity summary, and placement reasons reduce memory and inference burden.
- **Workflow efficiency:** Users can choose voice for broad intent and touch or
  pointer for precise corrections.
- **Emotional response:** The result feels collaborative: the assistant
  proposes, the person remains in control.

Residual opportunity: real backend progress events could make the drafting
narration more semantically precise than its current deterministic stages.

## Synthesized implementation outcome

The panel's highest-impact recommendations are implemented in this order:

1. **Restore trust:** first-frame AI activity, full transcript visibility, and
   immediate linked-task metadata.
2. **Restore agency:** explicit block editor, direct move/resize, atomic save,
   rollback, and Undo.
3. **Clarify ownership:** task-owned title/category, plan-owned placement, and
   independent actual-time records.
4. **Improve judgment:** Reconcile decisions, capacity/category summaries,
   placement reasons, and Plan versus Actual.
5. **Polish the operating rhythm:** stale-while-revalidate projections,
   design-system modal patterns, responsive phone/desktop layouts, and isolated
   edge-fade rendering.

## Repeatable review cycle

Every material Daily OS interaction change should repeat this loop:

1. Populate the screenshot harness with one dense, internally consistent day.
2. Capture dark-mode phone and desktop states, including loading, error, empty,
   and direct-edit modes relevant to the change.
3. Have all four panel roles score the complete workflow independently against
   the same six dimensions.
4. Treat any score below 9, any stale projection, any silent wait, or any
   irreversible edit as a release blocker.
5. Implement the smallest coherent set of changes, rerun automated tests, and
   recapture the affected states with the real renderer where shaders or
   compositing matter.
6. Re-panel until every reviewer scores at least 9/10 on the same build.

The screenshots are also manual fixtures, which keeps the review evidence tied
to the workflow users are actually taught rather than to disposable mockups.
