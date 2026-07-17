import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/state/recording_style.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_recording_style_view.dart';
import 'package:lotti/features/onboarding/ui/widgets/recording_style_live_preview.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The recording-style step: previews both themed pairs (analogue VU meter +
/// modern orb) via [RecordingStyleLivePreview] (which owns the simulated /
/// live-mic level and the "Try with your voice" toggle), buffers the pick
/// locally, and persists it via [RecordingStyleController.setStyle] on
/// continue.
class OnboardingRecordingStyleStep extends ConsumerStatefulWidget {
  const OnboardingRecordingStyleStep({required this.onContinue, super.key});

  /// Advances to the category step once the style is chosen + persisted.
  final VoidCallback onContinue;

  @override
  ConsumerState<OnboardingRecordingStyleStep> createState() =>
      _OnboardingRecordingStyleStepState();
}

class _OnboardingRecordingStyleStepState
    extends ConsumerState<OnboardingRecordingStyleStep> {
  RecordingStyle _selected = RecordingStyle.modern;
  bool _selectionEdited = false;

  @override
  void initState() {
    super.initState();
    final current = ref.read(recordingStyleProvider).asData?.value;
    if (current != null) _selected = current;
  }

  @override
  Widget build(BuildContext context) {
    // On a cold mount `recordingStyleProvider` is still `AsyncLoading` when
    // `initState` runs, so `_selected` falls back to the hardcoded default
    // above. Once the pref finishes loading, seed `_selected` from it here —
    // but only on that first loading→data transition, so it never clobbers
    // a style the user has already tapped on this screen.
    ref.listen<AsyncValue<RecordingStyle>>(recordingStyleProvider, (
      previous,
      next,
    ) {
      final resolved = next.asData?.value;
      final wasUnresolved =
          previous == null || previous is AsyncLoading<RecordingStyle>;
      if (resolved != null && wasUnresolved && !_selectionEdited) {
        setState(() => _selected = resolved);
      }
    });
    final messages = context.messages;
    return RecordingStyleLivePreview(
      builder: (context, state) {
        return OnboardingRecordingStyleView(
          accent: context.designTokens.colors.interactive.enabled,
          colorScheme: Theme.of(context).colorScheme,
          title: messages.onboardingRecordingStyleTitle,
          explanation: messages.onboardingRecordingStyleExplanation,
          analogueLabel: messages.onboardingRecordingStyleAnalogue,
          modernLabel: messages.onboardingRecordingStyleModern,
          tryWithVoiceLabel: messages.onboardingRecordingStyleTryVoice,
          continueLabel: messages.onboardingRecordingStyleContinue,
          selected: _selected,
          onSelect: (style) {
            setState(() {
              _selectionEdited = true;
              _selected = style;
            });
          },
          tryingWithVoice: state.tryingWithVoice,
          onToggleTryWithVoice: state.onToggleTryWithVoice,
          onContinue: () async {
            await ref.read(recordingStyleProvider.notifier).setStyle(_selected);
            widget.onContinue();
          },
          vu: state.level.vu,
          dBFS: state.level.dbfs,
          amplitudes: state.level.amplitudes,
        );
      },
    );
  }
}
