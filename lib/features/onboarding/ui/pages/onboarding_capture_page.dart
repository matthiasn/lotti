import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/model/onboarding_event.dart';
import 'package:lotti/features/onboarding/repository/onboarding_metrics_repository.dart';
import 'package:lotti/features/onboarding/services/onboarding_capture_to_task_service.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_capture_view.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The live first-capture aha, end to end.
///
/// Hosts the presentational [OnboardingCaptureView] on a full-screen dark
/// surface and wires it to the shared [captureControllerProvider] (the same
/// mic/realtime pipeline the Daily OS capture screen uses — no bespoke audio
/// wiring) and to the [onboardingCaptureToTaskServiceProvider] orchestrator
/// that turns the transcript into a real task.
///
/// Phase mapping ([CapturePhase] → [OnboardingCapturePhase]):
///
/// ```text
/// idle         → prompt    (the orb invites a tap)
/// listening    → listening (mic open, waveform streams)
/// transcribing → thinking  (words captured, transcript pending)
/// captured     → thinking  (structuring in flight) then revealed (result)
/// error        → prompt    (with a retry: tapping the orb re-arms the mic)
/// ```
///
/// On reaching [CapturePhase.captured] with a non-empty transcript the page
/// records [OnboardingEventName.firstAudioCaptured] once, then calls the
/// orchestrator exactly once per capture (guarded so it never double-fires)
/// and reveals the structured title + checklist with the celebration burst.
class OnboardingCapturePage extends ConsumerStatefulWidget {
  const OnboardingCapturePage({
    required this.categoryId,
    required this.categoryLabel,
    required this.onDone,
    this.providerName,
    super.key,
  });

  /// The category the structured task lands in (the first area the user
  /// created in the onboarding category step).
  final String categoryId;

  /// Human-readable name of [categoryId], shown on the resolved card.
  final String categoryLabel;

  /// Optional low-cardinality provider funnel dimension (e.g. "Gemini").
  final String? providerName;

  /// Fired when the user accepts the revealed task ("Looks good").
  final VoidCallback onDone;

  @override
  ConsumerState<OnboardingCapturePage> createState() =>
      _OnboardingCapturePageState();
}

class _OnboardingCapturePageState extends ConsumerState<OnboardingCapturePage> {
  /// The transcript currently being (or already) structured. Guards against
  /// re-triggering the orchestrator while a capture's structuring is in flight
  /// or after it has resolved — structuring runs exactly once per capture.
  String? _structuringForTranscript;

  /// True from the moment structuring starts until the reveal lands, so the
  /// view stays on the thinking frame across the orchestrator round-trip even
  /// though the controller has already settled on [CapturePhase.captured].
  bool _structuring = false;

  /// The resolved structuring outcome, or null until the reveal.
  OnboardingCaptureResult? _result;

  OnboardingMetricsRepository? get _metrics =>
      getIt.isRegistered<OnboardingMetricsRepository>()
      ? getIt<OnboardingMetricsRepository>()
      : null;

  @override
  Widget build(BuildContext context) {
    // Meter ticks (amplitudes/dbfs, many per second while listening) flow
    // straight into the orb; the whole page rebuilds with them, but the active
    // band is the only meter consumer so the cost stays local.
    final captureState = ref.watch(captureControllerProvider);

    ref.listen<CaptureState>(captureControllerProvider, (previous, next) {
      _maybeStructure(next);
    });

    // The dark onboarding surface: a Theme carrying the dark DsTokens so the
    // view's `context.designTokens` resolves the dark palette, over a matching
    // dark Scaffold.
    final darkTheme = DesignSystemTheme.dark();
    return Theme(
      data: darkTheme,
      child: Builder(
        builder: (themedContext) {
          final tokens = themedContext.designTokens;
          return Scaffold(
            backgroundColor: tokens.colors.background.level01,
            body: SafeArea(
              child: OnboardingCaptureView(
                phase: _viewPhase(captureState.phase),
                accent: tokens.colors.interactive.enabled,
                // The resolved card is a light surface lifted onto the dark
                // hero, mirroring the crystallize hero's contrast.
                cardColor: dsTokensLight.colors.background.level01,
                onCardColor: dsTokensLight.colors.text.highEmphasis,
                ghostColor: tokens.colors.text.mediumEmphasis,
                promptHeadline: context.messages.onboardingCapturePrompt,
                revealedHeadline: context.messages.onboardingCaptureRevealed,
                promptHint: context.messages.onboardingCapturePromptHint,
                listeningCaption: context.messages.onboardingCaptureListening,
                thinkingHeadline: context.messages.onboardingCaptureThinking,
                thinkingReassurance:
                    context.messages.onboardingCaptureReassurance,
                ratherTypeLabel: context.messages.onboardingCaptureRatherType,
                acceptLabel: context.messages.onboardingCaptureAccept,
                orbSemanticLabel: context.messages.onboardingCaptureOrbLabel,
                editHint: context.messages.onboardingCaptureEditHint,
                categoryLabel: widget.categoryLabel,
                transcript: _displayTranscript(captureState),
                amplitudes: captureState.amplitudes,
                dbfs: captureState.dbfs,
                title: _result?.title ?? '',
                items: _result?.checklistItems ?? const [],
                celebrate: _result?.isRealAha ?? false,
                onOrbTap: _onOrbTap,
                onRatherType: _onRatherType,
                onAccept: widget.onDone,
              ),
            ),
          );
        },
      ),
    );
  }

  /// The transcript surfaced under the thinking shimmer. Falls back to the
  /// live realtime partial while transcription is still resolving so the user
  /// sees their words echoed before the final transcript lands.
  String _displayTranscript(CaptureState state) {
    if (state.transcript.isNotEmpty) return state.transcript;
    return state.partialTranscript;
  }

  /// Resolves the visible frame. Once structuring is in flight (or has landed)
  /// the controller's [CapturePhase.captured] maps to thinking → revealed; the
  /// raw phase only drives the pre-structuring frames.
  OnboardingCapturePhase _viewPhase(CapturePhase phase) {
    if (_result != null) return OnboardingCapturePhase.revealed;
    if (_structuring) return OnboardingCapturePhase.thinking;
    return switch (phase) {
      CapturePhase.idle => OnboardingCapturePhase.prompt,
      CapturePhase.listening => OnboardingCapturePhase.listening,
      CapturePhase.transcribing => OnboardingCapturePhase.thinking,
      // Captured but not yet structuring (transient) — hold on thinking until
      // the listener kicks off structuring on the next frame.
      CapturePhase.captured => OnboardingCapturePhase.thinking,
      // An error re-arms the prompt; tapping the orb retries the mic.
      CapturePhase.error => OnboardingCapturePhase.prompt,
    };
  }

  void _onOrbTap() {
    // The controller's own toggle drives the mic lifecycle; from an error it
    // re-begins listening, which is exactly the retry affordance we want.
    ref.read(captureControllerProvider.notifier).toggle();
  }

  /// Kicks off structuring once the controller has a captured, non-empty
  /// transcript. Idempotent per transcript so it never double-fires.
  void _maybeStructure(CaptureState state) {
    if (state.phase != CapturePhase.captured) return;
    final transcript = state.transcript.trim();
    if (transcript.isEmpty) return;
    if (_structuringForTranscript == transcript) return;

    _structuringForTranscript = transcript;
    setState(() {
      _structuring = true;
      _result = null;
    });
    unawaited(_structure(transcript));
  }

  Future<void> _structure(String transcript) async {
    await _metrics?.recordEvent(
      OnboardingEventName.firstAudioCaptured,
      provider: widget.providerName,
    );
    final service = ref.read(onboardingCaptureToTaskServiceProvider);
    final result = await service.createTaskFromTranscript(
      transcript: transcript,
      categoryId: widget.categoryId,
      providerName: widget.providerName,
    );
    if (!mounted) return;
    setState(() {
      _structuring = false;
      _result = result;
    });
  }

  /// The "Rather type?" escape hatch: open the typed-capture path on the
  /// controller, collect text in a small dialog, then push it through the same
  /// structuring pipeline as voice.
  Future<void> _onRatherType() async {
    final notifier = ref.read(captureControllerProvider.notifier)
      ..startTyping();
    final typed = await _promptForText();
    if (!mounted) return;
    final transcript = typed?.trim() ?? '';
    if (transcript.isEmpty) {
      // Nothing typed — back to the prompt rather than a stranded captured
      // state with an empty transcript.
      notifier.reset();
      return;
    }
    notifier.updateTranscript(transcript);
    // updateTranscript leaves the controller in `captured`; the ref.listen
    // above only fires on state *changes*, so structure directly here.
    _maybeStructure(ref.read(captureControllerProvider));
  }

  Future<String?> _promptForText() {
    final controller = TextEditingController();
    final messages = context.messages;
    final material = MaterialLocalizations.of(context);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(messages.onboardingCaptureTypePrompt),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: null,
          textInputAction: TextInputAction.done,
          onSubmitted: (value) => Navigator.of(ctx).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(material.cancelButtonLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(material.okButtonLabel),
          ),
        ],
      ),
    );
  }
}
