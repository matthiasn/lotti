import 'package:lotti/features/agents/ui/ai_summary_card/summary_read_aloud_button.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/design_system/components/buttons/ds_ai_disc_button.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the companion full screen, head to toe on her stage — the place a
/// narrow summary card's header bust leads, since that bust shows only her
/// head and shoulders.
///
/// She speaks [sourceId]'s utterance as on the card, so a summary being read
/// aloud carries on in her mouth here, and the read-aloud control below her
/// reads [spokenText], the words the card showed when she was opened.
Future<void> openCompanionStage(
  BuildContext context, {
  required String sourceId,
  required String spokenText,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) =>
          CompanionStagePage(sourceId: sourceId, spokenText: spokenText),
    ),
  );
}

/// The companion full screen: her `full` framing on the dark stage, which
/// grounds her feet with its floor shadow, a close control at the top and
/// the summary's read-aloud control at her feet.
///
/// The stage is dark whatever the app theme, like the tutorial videos she
/// stands on it in, so the page wears the dark design-system theme for its
/// own controls.
class CompanionStagePage extends StatelessWidget {
  const CompanionStagePage({
    required this.sourceId,
    required this.spokenText,
    super.key,
  });

  final String sourceId;
  final String spokenText;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: DesignSystemTheme.dark(),
      child: Builder(
        builder: (context) {
          final tokens = context.designTokens;
          return Scaffold(
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
          );
        },
      ),
    );
  }
}
