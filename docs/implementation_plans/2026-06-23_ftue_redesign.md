# FTUE redesign — recording-style picker, real-task payoff, seamless backdrop

_2026-06-23_

## Context

The first FTUE screens (welcome → connect → success → categories) test well, but the
**payoff went off the rails**: after the voice capture, the flow showed a *synthetic*
"crystallize hero" card and then popped back to the app, landing on the Daily OS
`/calendar` "day interface" — jarring and off-message. The interaction we want to
showcase is **creating a real task** the user then lands on. We also add a small,
on-brand **personalization step** (pick your recording look) and fix the constellation
backdrop, which loops beautifully but **snaps at the loop seam**.

## Decisions

- **Recording-style picker** — a new onboarding step offering **two themed pairs** (each
  shows two visualizers together during recording):
  1. **Analogue** — analog VU meter + waveform bars (retro styling).
  2. **Modern** — energy orb (`AiVoiceInputShader`) + a brand-tinted waveform.
- **Preview = hybrid**: both pairs animate with **simulated motion** by default, plus a
  **"Try with your voice"** toggle driving them from the **live mic** (fallback to
  simulated if denied).
- **Persist** the choice (`AppPrefs`), reused by the real capture + a minimal Settings
  toggle.
- **Payoff**: brief "thinking" beat → create the task **in progress** in the chosen
  category → navigate to the **real `TaskDetailsPage`**. Retire the crystallize hero.
- **Deferred**: the general "record to fill a missing estimate/due date" CTA.
- **Goal**: every onboarding page panel-reviewed/iterated to **≥8/10 average (experts)**,
  end-to-end to a real first task.

## Work items

- **A. Preference** — `lib/features/onboarding/state/recording_style.dart`:
  `enum RecordingStyle { analogue, modern }` + `recordingStyleProvider`
  (`AsyncNotifier`) backed by `AppPrefs` (key `recording_visual_style`, default `modern`).
- **B. Picker** — `OnboardingRecordingStyleView` + host: both pairs as selectable preview
  cards; shared level source (simulated ticker / live `captureControllerProvider`); reuse
  `AnalogVuMeter`, `LiveWaveform`, `AiVoiceInputShader`; reduced-motion static. Insert as a
  `_FlowStep` after success in `onboarding_welcome_modal.dart`.
- **C. Capture** — `onboarding_capture_view.dart` renders the chosen pair; keep the
  category picker; simplify to `prompt / listening / thinking` (drop `revealed`).
- **D. Payoff** — `onboarding_capture_to_task_service.dart` creates `TaskStatus.inProgress`;
  `onboarding_capture_page.dart` navigates (replace) to `TaskDetailsPage(taskId)` on
  success/floor (mobile `pushReplacement`; desktop `pushDesktopTaskDetail` + pop). Remove
  `crystallize_hero.dart` (+ test) once unused.
- **E. Backdrop** — `neural_constellation.dart`: make the travelling-pulse phase periodic
  over the loop (compute from `controller.value`, integer cycles/loop), fade synapse-edge
  alpha to 0 at the link threshold; add a loop-seam test.
- **F.** l10n strings (+ `make l10n`/sort), minimal Settings toggle, README, CHANGELOG +
  flatpak update.

## Verification

- analyze clean; format; targeted tests green (preference, picker + both pairs,
  capture→task nav + in-progress status, neural loop seam).
- Manual: flow ends on a real in-progress task page; chosen pair drives capture;
  try-with-voice + denial fallback; reduced-motion static; tap-outside dismiss; seamless
  backdrop.
- Panel review (expert + user) on every page to ≥8/10 average (experts).
