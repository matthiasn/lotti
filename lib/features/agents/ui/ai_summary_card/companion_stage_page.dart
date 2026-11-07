import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/summary_read_aloud_button.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/rig/stage_painter.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/design_system/components/buttons/ds_ai_disc_button.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
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
/// on, so the figure the bust was tapped on stands up in the same pose. A
/// host whose voice is not a summary's — the front agent's answers — passes
/// its own [controls] instead of the words: its voice, and a way to answer
/// her — and may pass a [sidePanel] that stands beside her on a desktop
/// window (the conversation she is speaking in), and [pointsAtSidePanel],
/// true while she should point at what that panel shows. She
/// wears what the card dressed her in: a host that dresses her for another
/// subject than [sourceId] names it as [dressedFor].
Future<void> openCompanionStage(
  BuildContext context, {
  required String sourceId,
  String spokenText = '',
  Widget? controls,
  Widget? sidePanel,
  ProviderListenable<bool>? pointsAtSidePanel,
  CompanionMood mood = CompanionMood.calm,
  GestureName? holding,
  TtsCloudRoute? cloudRoute,
  String? dressedFor,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => CompanionStagePage(
        sourceId: sourceId,
        spokenText: spokenText,
        controls: controls,
        sidePanel: sidePanel,
        pointsAtSidePanel: pointsAtSidePanel,
        mood: mood,
        holding: holding,
        cloudRoute: cloudRoute,
        dressedFor: dressedFor,
      ),
    ),
  );
}

/// The companion full screen: her `full` framing on the dark stage, which
/// grounds her feet with its floor shadow, a control at the top that
/// changes her outfit for the session ([companionOutfitProvider]) and one that
/// closes the page, and the summary's read-aloud control at her feet.
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
    this.controls,
    this.sidePanel,
    this.pointsAtSidePanel,
    this.mood = CompanionMood.calm,
    this.holding,
    this.cloudRoute,
    String? dressedFor,
    super.key,
  }) : dressedFor = dressedFor ?? sourceId;

  /// The host's own controls at her feet, in place of the summary's
  /// read-aloud control; they gate themselves.
  final Widget? controls;

  /// Beside her on a desktop window, the host's own panel — the front
  /// agent's conversation — so a wide stage is not mostly empty floor
  /// either side of her. Left out on a phone, where she takes the screen.
  final Widget? sidePanel;

  /// While true, and [sidePanel] stands beside her, she points at it
  /// ([GestureName.pointRight]) in place of [holding] — at the tasks the
  /// conversation lists as she says them.
  final ProviderListenable<bool>? pointsAtSidePanel;

  /// The host's own panel's share of a desktop window's width; she keeps
  /// the rest.
  static const int sidePanelFlex = 2;

  /// Her share beside [sidePanel].
  static const int figureFlex = 3;

  /// The host's cloud voice, or `null` for the on-device voice.
  final TtsCloudRoute? cloudRoute;

  final String sourceId;
  final String spokenText;

  /// How she carries herself here: the host's pose, calm by default.
  final CompanionMood mood;

  /// A gesture she keeps up here, as on the host card.
  final GestureName? holding;

  /// The subject her outfit is drawn for, as on the host card.
  final String dressedFor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canReadAloud =
        spokenText.isNotEmpty &&
        (ref.watch(configFlagProvider(enableAiSummaryTtsFlag)).value ??
            false) &&
        (cloudRoute != null || ref.watch(ttsEngineProvider).isSupported);
    final beside = sidePanel != null && isDesktopLayout(context);
    final points = pointsAtSidePanel;
    final pointing = beside && points != null && ref.watch(points);
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
                // The stage's own floor, so the band under her is more of
                // her stage, not a slab of page.
                backgroundColor: CompanionStage.bottom,
                // She stands above, the controls in a band of their own
                // below her, so nothing is ever drawn on her.
                body: _besideSidePanel(
                  beside,
                  Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            // Decorative: the close and read-aloud controls carry
                            // the page's meaning, and she says nothing a reader
                            // would miss.
                            Positioned.fill(
                              child: ExcludeSemantics(
                                child: CompanionSpeaker(
                                  key: const ValueKey('companionStageFigure'),
                                  sourceId: sourceId,
                                  stage: true,
                                  mood: mood,
                                  holding: pointing
                                      ? GestureName.pointRight
                                      : holding,
                                  dressedFor: dressedFor,
                                ),
                              ),
                            ),
                            SafeArea(
                              bottom: false,
                              child: Padding(
                                padding: EdgeInsets.all(
                                  tokens.spacing.cardPadding,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    DsAiDiscButton(
                                      key: const ValueKey(
                                        'companionStageOutfit',
                                      ),
                                      icon: LottiIcons.palette,
                                      label: context
                                          .messages
                                          .aiCardCompanionStageNextOutfit,
                                      onPressed: () => ref
                                          .read(
                                            companionOutfitProvider.notifier,
                                          )
                                          .next(
                                            ref
                                                .read(companionLookRollProvider)
                                                .outfitFor(dressedFor),
                                          ),
                                    ),
                                    DsAiDiscButton(
                                      icon: LottiIcons.close,
                                      label: MaterialLocalizations.of(
                                        context,
                                      ).closeButtonTooltip,
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (controls ??
                              (canReadAloud
                                  ? SummaryReadAloudButton(
                                      sourceId: sourceId,
                                      text: spokenText,
                                      cloudRoute: cloudRoute,
                                    )
                                  : null)
                          case final footer?)
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: EdgeInsets.all(tokens.spacing.cardPadding),
                            child: Center(child: footer),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// [stage] alone, or beside the host's [sidePanel] when [beside] — on a
  /// desktop window.
  Widget _besideSidePanel(bool beside, Widget stage) {
    final panel = sidePanel;
    if (panel == null || !beside) return stage;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: figureFlex, child: stage),
        Expanded(flex: sidePanelFlex, child: panel),
      ],
    );
  }
}
