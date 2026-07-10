import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/state/recording_style.dart';
import 'package:lotti/features/onboarding/ui/widgets/recording_style_live_preview.dart';
import 'package:lotti/features/onboarding/ui/widgets/recording_style_picker.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Mobile / Beamer wrapper: adds the [SliverBoxAdapterPage] chrome and
/// delegates content to [RecordingStyleSettingsBody]. The same body is
/// embedded directly in the Settings V2 detail pane via the panel registry —
/// that host supplies its own header, so it uses
/// [RecordingStyleSettingsBody] without this wrapper.
class RecordingStyleSettingsPage extends StatelessWidget {
  const RecordingStyleSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverBoxAdapterPage(
      title: context.messages.settingsRecordingStyleTitle,
      showBackButton: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: const RecordingStyleSettingsBody(),
    );
  }
}

/// The Recording Style settings: the same live-previewed [RecordingStylePicker]
/// shown during onboarding, backed directly by [recordingStyleProvider] — a
/// tap on a card persists the choice immediately, there is no "Continue"
/// step. [RecordingStyleLivePreview] supplies the same simulated / live-mic
/// preview driving as onboarding.
///
/// Unlike onboarding — which always sits over its own dark
/// `OnboardingBackdrop` and can safely force [RecordingStylePicker]'s cards
/// to `dsTokensDark` — this page has no such backdrop and follows the
/// ambient Settings theme (light or dark), so the picker is handed the
/// ambient `context.designTokens`/`Theme.of(context).colorScheme` instead.
/// Forcing the dark card styling here would render low-contrast text over
/// a light page background.
class RecordingStyleSettingsBody extends ConsumerWidget {
  const RecordingStyleSettingsBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final selected =
        ref.watch(recordingStyleProvider).asData?.value ??
        RecordingStyle.modern;
    final notifier = ref.read(recordingStyleProvider.notifier);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step6,
        vertical: tokens.spacing.step4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            messages.settingsRecordingStyleExplanation,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step5),
          RecordingStyleLivePreview(
            builder: (context, state) => RecordingStylePicker(
              accent: tokens.colors.interactive.enabled,
              colorScheme: Theme.of(context).colorScheme,
              surfaceTokens: tokens,
              analogueLabel: messages.onboardingRecordingStyleAnalogue,
              modernLabel: messages.onboardingRecordingStyleModern,
              tryWithVoiceLabel: messages.onboardingRecordingStyleTryVoice,
              selected: selected,
              onSelect: notifier.setStyle,
              tryingWithVoice: state.tryingWithVoice,
              onToggleTryWithVoice: state.onToggleTryWithVoice,
              vu: state.level.vu,
              dBFS: state.level.dbfs,
              amplitudes: state.level.amplitudes,
            ),
          ),
        ],
      ),
    );
  }
}
