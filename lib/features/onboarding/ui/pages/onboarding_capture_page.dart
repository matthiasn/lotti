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
/// One area the user created in the onboarding category step, offered as a
/// destination for the first captured task. Carried from the category step into
/// the capture page so the user chooses *which* area the task lands in.
@immutable
class OnboardingCaptureCategory {
  const OnboardingCaptureCategory({required this.id, required this.label});

  final String id;
  final String label;
}

class OnboardingCapturePage extends ConsumerStatefulWidget {
  const OnboardingCapturePage({
    required this.categories,
    required this.onDone,
    this.providerName,
    super.key,
  }) : assert(categories.length > 0, 'at least one category is required');

  /// The areas the user created in the onboarding category step. The first is
  /// pre-selected; when there is more than one the page shows a destination
  /// picker so the user chooses which area the structured task lands in.
  final List<OnboardingCaptureCategory> categories;

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

  /// The area the structured task lands in. Pre-selected to the first created
  /// area; when more than one exists the user can re-pick via the destination
  /// picker until structuring starts.
  late String _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.categories.first.id;
  }

  OnboardingCaptureCategory get _selectedCategory =>
      widget.categories.firstWhere(
        (c) => c.id == _selectedCategoryId,
        orElse: () => widget.categories.first,
      );

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
              child: Stack(
                children: [
                  OnboardingCaptureView(
                    phase: _viewPhase(captureState.phase),
                    accent: tokens.colors.interactive.enabled,
                    // The resolved card is a light surface lifted onto the dark
                    // hero, mirroring the crystallize hero's contrast.
                    cardColor: dsTokensLight.colors.background.level01,
                    onCardColor: dsTokensLight.colors.text.highEmphasis,
                    ghostColor: tokens.colors.text.mediumEmphasis,
                    promptHeadline: context.messages.onboardingCapturePrompt,
                    revealedHeadline:
                        context.messages.onboardingCaptureRevealed,
                    promptHint: context.messages.onboardingCapturePromptHint,
                    listeningCaption:
                        context.messages.onboardingCaptureListening,
                    thinkingHeadline:
                        context.messages.onboardingCaptureThinking,
                    thinkingReassurance:
                        context.messages.onboardingCaptureReassurance,
                    ratherTypeLabel:
                        context.messages.onboardingCaptureRatherType,
                    acceptLabel: context.messages.onboardingCaptureAccept,
                    orbSemanticLabel:
                        context.messages.onboardingCaptureOrbLabel,
                    editHint: context.messages.onboardingCaptureEditHint,
                    categoryLabel: _selectedCategory.label,
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
                  // The capture page is full-screen (no barrier to tap), so an
                  // always-available close is the escape hatch — it finishes
                  // onboarding; the user can capture later.
                  Positioned(
                    top: tokens.spacing.step2,
                    left: tokens.spacing.step2,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: tokens.colors.text.mediumEmphasis,
                      tooltip: MaterialLocalizations.of(
                        themedContext,
                      ).closeButtonTooltip,
                      onPressed: widget.onDone,
                    ),
                  ),
                  // When the user created more than one area, let them choose
                  // which one this first task lands in. Shown only while the
                  // capture is still being composed (prompt / listening) — once
                  // structuring starts the destination is locked and surfaced
                  // on the resolved card instead.
                  if (_showCategoryPicker(captureState.phase))
                    Positioned(
                      top: tokens.spacing.step10,
                      left: tokens.spacing.step6,
                      right: tokens.spacing.step6,
                      child: _CategoryPicker(
                        prompt:
                            context.messages.onboardingCaptureCategoryPrompt,
                        categories: widget.categories,
                        selectedId: _selectedCategoryId,
                        accent: tokens.colors.interactive.enabled,
                        onSelect: (id) =>
                            setState(() => _selectedCategoryId = id),
                      ),
                    ),
                ],
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

  /// The destination picker only appears when there is a real choice to make
  /// (more than one created area) and only before structuring starts — while
  /// the orb is idle/listening. After capture the destination is fixed.
  bool _showCategoryPicker(CapturePhase phase) {
    if (widget.categories.length < 2) return false;
    final viewPhase = _viewPhase(phase);
    return viewPhase == OnboardingCapturePhase.prompt ||
        viewPhase == OnboardingCapturePhase.listening;
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
      categoryId: _selectedCategoryId,
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

/// The first-capture destination picker: a short prompt over a centred wrap of
/// pills naming the areas the user created, so they choose which one the
/// structured task lands in. Selection is colour-led (a solid brand fill for the
/// chosen area, an outline for the rest) so it stays legible on the dark hero.
class _CategoryPicker extends StatelessWidget {
  const _CategoryPicker({
    required this.prompt,
    required this.categories,
    required this.selectedId,
    required this.accent,
    required this.onSelect,
  });

  final String prompt;
  final List<OnboardingCaptureCategory> categories;
  final String selectedId;
  final Color accent;
  final void Function(String id) onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          prompt,
          textAlign: TextAlign.center,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(height: tokens.spacing.step3),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: tokens.spacing.step2,
          runSpacing: tokens.spacing.step2,
          children: [
            for (final category in categories)
              _PickerChip(
                tokens: tokens,
                accent: accent,
                label: category.label,
                selected: category.id == selectedId,
                onTap: () => onSelect(category.id),
              ),
          ],
        ),
      ],
    );
  }
}

/// One destination pill. Selected fills solid brand with a dark label; the rest
/// are a quiet outline with a light label.
class _PickerChip extends StatelessWidget {
  const _PickerChip({
    required this.tokens,
    required this.accent,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final DsTokens tokens;
  final Color accent;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? tokens.colors.background.level01
        : tokens.colors.text.highEmphasis;
    final radius = BorderRadius.circular(tokens.radii.l);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: radius,
            border: Border.all(
              color: selected
                  ? accent
                  : tokens.colors.text.mediumEmphasis.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step4,
              vertical: tokens.spacing.step2,
            ),
            child: Text(
              label,
              style: tokens.typography.styles.body.bodySmall.copyWith(
                color: fg,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
