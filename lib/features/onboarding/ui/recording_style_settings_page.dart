import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/recording_style_live_preview.dart';
import 'package:lotti/features/onboarding/ui/widgets/recording_style_picker.dart';
import 'package:lotti/features/speech/state/recording_style.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/pages/sliver_box_adapter_page.dart';
import 'package:material_ui/material_ui.dart';

/// Mobile / Beamer wrapper: adds the [SliverBoxAdapterPage] chrome and
/// delegates content to [RecordingStyleSettingsBody]. The same body is
/// embedded directly in the desktop settings detail pane via its `settingsRoutes` entry —
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

/// The Recording Style settings — the one place the recording style is
/// chosen: the live-previewed [RecordingStylePicker], backed directly by
/// [recordingStyleProvider], so a tap on a card persists the choice
/// immediately. [RecordingStyleLivePreview] drives the previews with a
/// simulated or live-mic level.
///
/// The page follows the ambient Settings theme (light or dark), so the
/// picker is handed the ambient
/// `context.designTokens`/`Theme.of(context).colorScheme`; forcing dark card
/// styling would render low-contrast text over a light page background.
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
