import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/model/onboarding_capture_category.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/services/onboarding_capture_to_task_service.dart';
import 'package:lotti/features/onboarding/state/recording_style.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_first_task_view.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The live first-task aha, end to end — hosted *inside* the onboarding panel
/// as the flow's final step (it never leaves the dialogue for a full-screen
/// takeover).
///
/// Hosts the presentational [OnboardingFirstTaskView] and wires it to the
/// **shared** [captureControllerProvider] (the same mic/realtime pipeline the
/// Daily OS capture screen uses — no bespoke audio wiring), to the persisted
/// [recordingStyleProvider] (so the visual the user picked one step earlier is
/// the one that records their first task), and to the
/// [onboardingCaptureToTaskServiceProvider] orchestrator that turns the
/// transcript into a real task.
///
/// Phase mapping ([CapturePhase] → [OnboardingFirstTaskPhase]):
///
/// ```text
/// idle         → prompt    (the visual invites a tap; suggestions offered)
/// listening    → listening (mic open, level streams into the visual)
/// transcribing → thinking  (words captured, transcript pending)
/// captured     → thinking  (structuring in flight)
/// error        → prompt    (with a retry: tapping the visual re-arms the mic)
/// ```
///
/// On reaching [CapturePhase.captured] with a non-empty transcript the step
/// records the capture modality once — [OnboardingEventName.firstAudioCaptured]
/// for the mic path, [OnboardingEventName.typedCaptureUsed] for the tapped or
/// typed paths — then calls the orchestrator exactly once per capture (guarded
/// so it never double-fires).
/// When a real task lands, the step shows the created beat *inside* the panel
/// — the task title + checklist as a tappable card — and only when the user
/// taps it does the step hand the task id to [onTaskCreated], so the host pops
/// the modal and navigates to the real task page. The spoken capture's audio
/// entry travels along ([CaptureState.audioId]) and is linked under the task.
class OnboardingFirstTaskStep extends ConsumerStatefulWidget {
  const OnboardingFirstTaskStep({
    required this.categories,
    required this.onTaskCreated,
    required this.onDone,
    this.providerName,
    super.key,
  }) : // `.isNotEmpty` is not potentially-constant, so it cannot appear in a
       // const constructor's assert — `.length > 0` is the only option here
       // (which is also why `prefer_is_empty` exempts this pattern).
       assert(categories.length > 0, 'at least one category is required');

  /// The areas the user created in the onboarding category step. The first is
  /// pre-selected; when there is more than one the step shows a destination
  /// picker so the user chooses which area the structured task lands in.
  final List<OnboardingCaptureCategory> categories;

  /// Optional low-cardinality provider funnel dimension (e.g. "Gemini").
  final String? providerName;

  /// Fired with the new task's id once structuring lands a real (in-progress)
  /// task. The host pops the modal and navigates to that task's detail page;
  /// injected so the step stays decoupled from the task UI and testable.
  final void Function(String taskId) onTaskCreated;

  /// Fired when the capture cannot produce a task at all (a total structuring
  /// failure) — finishes onboarding rather than stranding the user.
  final VoidCallback onDone;

  @override
  ConsumerState<OnboardingFirstTaskStep> createState() =>
      _OnboardingFirstTaskStepState();
}

class _OnboardingFirstTaskStepState
    extends ConsumerState<OnboardingFirstTaskStep> {
  /// The transcript currently being (or already) structured. Guards against
  /// re-triggering the orchestrator while a capture's structuring is in flight
  /// or after it has resolved — structuring runs exactly once per capture.
  String? _structuringForTranscript;

  /// True from the moment structuring starts until the created beat (or a
  /// retry) takes over, so the view holds the thinking frame across the
  /// orchestrator round-trip even though the controller has already settled
  /// on [CapturePhase.captured].
  bool _structuring = false;

  /// The landed task, once structuring resolves — drives the in-panel created
  /// beat. Tapping the card hands [_createdTaskId] to the host.
  OnboardingCaptureResult? _created;
  String? _createdTaskId;

  /// Latches on the first created-card tap so a fast double-tap can't hand the
  /// task off twice — the host pops the modal on handoff, and a second pop
  /// would tear down the route beneath it.
  bool _handedOff = false;

  /// The area the structured task lands in. Pre-selected to the first created
  /// area; when more than one exists the user can re-pick via the destination
  /// picker until structuring starts.
  late String _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.categories.first.id;
  }

  OnboardingMetricsRepository? get _metrics =>
      getIt.isRegistered<OnboardingMetricsRepository>()
      ? getIt<OnboardingMetricsRepository>()
      : null;

  @override
  Widget build(BuildContext context) {
    // Meter ticks (amplitudes/dbfs, many per second while listening) flow
    // straight into the recording visual; the whole step rebuilds with them,
    // but the active band is the only meter consumer so the cost stays local.
    final captureState = ref.watch(captureControllerProvider);

    ref.listen<CaptureState>(captureControllerProvider, (previous, next) {
      // A mic capture that came back with nothing (silence, unintelligible
      // audio) must re-arm the prompt: `captured` maps to the thinking frame,
      // which has no retry affordance, so leaving the empty capture in place
      // would strand the user on "Turning your words into a task…" forever.
      // Scoped to the mic path (previous == transcribing) so the typed path's
      // transient captured('') is untouched.
      if (next.phase == CapturePhase.captured &&
          next.transcript.trim().isEmpty &&
          previous?.phase == CapturePhase.transcribing) {
        ref.read(captureControllerProvider.notifier).reset();
        return;
      }
      _maybeStructure(next);
    });

    // The style picked one step earlier; while the preference is still loading
    // (or on a load error) the signature orb stands in.
    final style =
        ref.watch(recordingStyleProvider).asData?.value ??
        RecordingStyle.modern;

    final messages = context.messages;
    return OnboardingFirstTaskView(
      phase: _viewPhase(captureState.phase),
      style: style,
      accent: context.designTokens.colors.interactive.enabled,
      colorScheme: Theme.of(context).colorScheme,
      title: messages.onboardingFirstTaskTitle,
      guidance: messages.onboardingFirstTaskGuidance,
      suggestionsLabel: messages.onboardingFirstTaskSuggestionsLabel,
      suggestions: [
        messages.onboardingFirstTaskSuggestionPlanWeek,
        messages.onboardingFirstTaskSuggestionDentist,
        messages.onboardingFirstTaskSuggestionMeeting,
      ],
      listeningCaption: messages.onboardingCaptureListening,
      thinkingHeadline: messages.onboardingCaptureThinking,
      thinkingReassurance: messages.onboardingCaptureReassurance,
      ratherTypeLabel: messages.onboardingCaptureRatherType,
      recordSemanticLabel: messages.onboardingCaptureOrbLabel,
      categoryPrompt: messages.onboardingCaptureCategoryPrompt,
      createdHeadline: messages.onboardingFirstTaskCreatedTitle,
      createdHint: messages.onboardingFirstTaskCreatedHint,
      createdTaskTitle: _created?.title ?? '',
      categories: widget.categories,
      selectedCategoryId: _selectedCategoryId,
      onSelectCategory: (id) => setState(() => _selectedCategoryId = id),
      onRecordTap: _onRecordTap,
      onSuggestionTap: _onSuggestion,
      onRatherType: _onRatherType,
      onOpenTask: _onOpenTask,
      transcript: _displayTranscript(captureState),
      amplitudes: captureState.amplitudes,
      dbfs: captureState.dbfs,
    );
  }

  /// The created card was tapped — hand the landed task to the host, which
  /// pops the modal and opens the real task page.
  void _onOpenTask() {
    if (_handedOff) return;
    final taskId = _createdTaskId;
    if (taskId == null) return;
    _handedOff = true;
    widget.onTaskCreated(taskId);
  }

  /// The transcript surfaced under the thinking shimmer. Falls back to the
  /// live realtime partial while transcription is still resolving so the user
  /// sees their words echoed before the final transcript lands.
  String _displayTranscript(CaptureState state) {
    if (state.transcript.isNotEmpty) return state.transcript;
    return state.partialTranscript;
  }

  /// Resolves the visible frame. Once a task has landed the created beat owns
  /// the panel; while structuring is in flight the controller's
  /// [CapturePhase.captured] maps to thinking; the raw phase only drives the
  /// pre-structuring frames.
  OnboardingFirstTaskPhase _viewPhase(CapturePhase phase) {
    if (_created != null) return OnboardingFirstTaskPhase.created;
    if (_structuring) return OnboardingFirstTaskPhase.thinking;
    return switch (phase) {
      CapturePhase.idle => OnboardingFirstTaskPhase.prompt,
      CapturePhase.listening => OnboardingFirstTaskPhase.listening,
      CapturePhase.transcribing => OnboardingFirstTaskPhase.thinking,
      // Captured but not yet structuring (transient) — hold on thinking until
      // the listener kicks off structuring on the next frame.
      CapturePhase.captured => OnboardingFirstTaskPhase.thinking,
      // An error re-arms the prompt; tapping the visual retries the mic.
      CapturePhase.error => OnboardingFirstTaskPhase.prompt,
    };
  }

  void _onRecordTap() {
    // The controller's own toggle drives the mic lifecycle; from an error it
    // re-begins listening, which is exactly the retry affordance we want.
    ref.read(captureControllerProvider.notifier).toggle();
  }

  /// A tapped starter suggestion rides the typed-capture path: the controller
  /// jumps straight to `captured` with the suggestion as the transcript, and
  /// the same structuring pipeline turns it into a real task.
  void _onSuggestion(String suggestion) {
    ref.read(captureControllerProvider.notifier)
      ..startTyping()
      ..updateTranscript(suggestion);
    // startTyping/updateTranscript settle synchronously; the ref.listen above
    // only fires on state *changes* delivered between frames, so structure
    // directly here.
    _maybeStructure(ref.read(captureControllerProvider));
  }

  /// Kicks off structuring once the controller has a captured, non-empty
  /// transcript. Idempotent per transcript so it never double-fires.
  void _maybeStructure(CaptureState state) {
    if (state.phase != CapturePhase.captured) return;
    final transcript = state.transcript.trim();
    if (transcript.isEmpty) return;
    if (_structuringForTranscript == transcript) return;

    _structuringForTranscript = transcript;
    setState(() => _structuring = true);
    unawaited(_structure(transcript, audioId: state.audioId));
  }

  Future<void> _structure(String transcript, {String? audioId}) async {
    // Telemetry is best-effort: a metrics DB failure must never kill this
    // (unawaited) future before the orchestrator runs — that would strand the
    // user on the thinking frame with `_structuring` stuck true.
    //
    // Record the capture modality by the presence of audio: only the mic path
    // carries an [audioId]; the tapped-suggestion and "Rather type?" paths
    // arrive with none. Counting those as a voice capture would inflate the
    // funnel's voice-adoption metric, so they log the typed-capture event.
    try {
      await _metrics?.recordEvent(
        audioId != null
            ? OnboardingEventName.firstAudioCaptured
            : OnboardingEventName.typedCaptureUsed,
        provider: widget.providerName,
      );
    } catch (_) {
      // Proceed without the funnel event.
    }
    // The modal can be barrier-dismissed while the telemetry write was
    // awaited — using `ref` after disposal throws.
    if (!mounted) return;
    final service = ref.read(onboardingCaptureToTaskServiceProvider);
    final OnboardingCaptureResult result;
    try {
      result = await service.createTaskFromTranscript(
        transcript: transcript,
        categoryId: _selectedCategoryId,
        providerName: widget.providerName,
        audioId: audioId,
      );
    } catch (_) {
      // The orchestrator soft-lands its own failures, so a throw here is
      // unexpected (e.g. persistence). Don't strand the user on the thinking
      // frame — re-arm the prompt so they can retry.
      if (!mounted) return;
      setState(() => _structuring = false);
      _structuringForTranscript = null;
      ref.read(captureControllerProvider.notifier).reset();
      return;
    }
    if (!mounted) return;
    final task = result.task;
    if (task != null) {
      // The task landed — reveal the created beat inside the panel: the title
      // + checklist as a tappable card. The user taps it to leave the dialogue
      // and land on the real task page, instead of the modal vanishing the
      // moment structuring resolves.
      setState(() {
        _created = result;
        _createdTaskId = task.meta.id;
      });
    } else {
      // Couldn't persist even a title-only floor task — leave onboarding rather
      // than strand the user on the thinking frame.
      widget.onDone();
    }
  }

  /// The "Rather type?" escape hatch: collect text in a small dialog, then
  /// push it through the same structuring pipeline as voice.
  ///
  /// The controller is only touched *after* the dialog resolves with text:
  /// `startTyping` puts it in `captured('')`, which maps to the thinking
  /// frame — opening the dialog over that would show "Turning your words into
  /// a task…" behind it while nothing is being structured.
  Future<void> _onRatherType() async {
    final typed = await _promptForText();
    if (!mounted) return;
    final transcript = typed?.trim() ?? '';
    // Nothing typed — the controller was never touched, so the panel is
    // still sitting on the prompt frame.
    if (transcript.isEmpty) return;
    ref.read(captureControllerProvider.notifier)
      ..startTyping()
      ..updateTranscript(transcript);
    // updateTranscript leaves the controller in `captured`; the ref.listen
    // above only fires on state *changes*, so structure directly here.
    _maybeStructure(ref.read(captureControllerProvider));
  }

  Future<String?> _promptForText() {
    final messages = context.messages;
    final material = MaterialLocalizations.of(context);
    return showDialog<String>(
      context: context,
      builder: (_) => _TypeThoughtDialog(
        title: messages.onboardingCaptureTypePrompt,
        cancelLabel: material.cancelButtonLabel,
        okLabel: material.okButtonLabel,
      ),
    );
  }
}

/// The "Rather type?" dialog. A [StatefulWidget] so it owns its
/// [TextEditingController] and disposes it once the dialog leaves the tree
/// (after the exit animation) — disposing it synchronously after `showDialog`
/// returns would tear it down mid-transition while the field still reads it.
class _TypeThoughtDialog extends StatefulWidget {
  const _TypeThoughtDialog({
    required this.title,
    required this.cancelLabel,
    required this.okLabel,
  });

  final String title;
  final String cancelLabel;
  final String okLabel;

  @override
  State<_TypeThoughtDialog> createState() => _TypeThoughtDialogState();
}

class _TypeThoughtDialogState extends State<_TypeThoughtDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: null,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(widget.cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.okLabel),
        ),
      ],
    );
  }
}
