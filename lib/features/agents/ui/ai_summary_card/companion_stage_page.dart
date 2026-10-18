import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/summary_read_aloud_button.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/design_system/components/buttons/ds_ai_disc_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the companion full screen, head to toe on her stage — the place a
/// narrow summary card's header bust leads, since that bust shows only her
/// head and shoulders.
///
/// She speaks [sourceId]'s utterance as on the card, so a summary being read
/// aloud carries on in her mouth here, and the read-aloud control below her
/// reads [spokenText], the words the card showed when she was opened. A host
/// that poses her ([mood], [holding] — a goal's status pose) passes the pose
/// on, so the figure the bust was tapped on stands up in the same pose.
Future<void> openCompanionStage(
  BuildContext context, {
  required String sourceId,
  required String spokenText,
  CompanionMood mood = CompanionMood.calm,
  GestureName? holding,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => CompanionStagePage(
        sourceId: sourceId,
        spokenText: spokenText,
        mood: mood,
        holding: holding,
      ),
    ),
  );
}

/// The companion full screen: her `full` framing on the dark stage, which
/// grounds her feet with its floor shadow, a close control at the top and
/// the summary's read-aloud control at her feet.
///
/// The stage is dark whatever the app theme, like the tutorial videos she
/// stands on it in, so the page wears the dark design-system theme for its
/// own controls and light system-bar icons over the stage.
///
/// The read-aloud control follows the same gate as the card's: a synced
/// change that turns read-aloud off, or a voice the device lacks, takes it
/// away here too rather than leaving a control that would start speech the
/// user has switched off.
class CompanionStagePage extends ConsumerWidget {
  const CompanionStagePage({
    required this.sourceId,
    required this.spokenText,
    this.mood = CompanionMood.calm,
    this.holding,
    super.key,
  });

  final String sourceId;
  final String spokenText;

  /// How she carries herself here: the host's pose, calm by default.
  final CompanionMood mood;

  /// A gesture she keeps up here, as on the host card.
  final GestureName? holding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canReadAloud =
        spokenText.isNotEmpty &&
        (ref.watch(configFlagProvider(enableAiSummaryTtsFlag)).value ??
            false) &&
        ref.watch(ttsEngineProvider).isSupported;
    return Theme(
      data: DesignSystemTheme.dark(),
      child: Builder(
        builder: (context) {
          final tokens = context.designTokens;
          // Light icons over the dark stage, whatever the app's chrome; and a
          // route name, so a screen reader says where it has arrived.
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: context.messages.aiCardCompanionStageTitle,
              child: Scaffold(
                backgroundColor: tokens.colors.background.level01,
                body: Stack(
                  children: [
                    // Decorative: the close and read-aloud controls carry the
                    // page's meaning, and she says nothing a reader would miss.
                    Positioned.fill(
                      child: ExcludeSemantics(
                        child: CompanionSpeaker(
                          key: const ValueKey('companionStageFigure'),
                          sourceId: sourceId,
                          stage: true,
                          mood: mood,
                          holding: holding,
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: EdgeInsets.all(tokens.spacing.cardPadding),
                        child: Column(
                          children: [
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: DsAiDiscButton(
                                icon: LottiIcons.close,
                                label: MaterialLocalizations.of(
                                  context,
                                ).closeButtonTooltip,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            const Spacer(),
                            if (canReadAloud)
                              SummaryReadAloudButton(
                                sourceId: sourceId,
                                text: spokenText,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
