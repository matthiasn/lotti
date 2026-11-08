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
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
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
/// window (the conversation she is speaking in) and opens in a sheet titled
/// [sidePanelLabel] from a control in her top bar on a phone, and
/// [pointsAtSidePanel], true while she should point at what that panel
/// shows beside her. She
/// wears what the card dressed her in: a host that dresses her for another
/// subject than [sourceId] names it as [dressedFor].
Future<void> openCompanionStage(
  BuildContext context, {
  required String sourceId,
  String spokenText = '',
  Widget? controls,
  Widget? sidePanel,
  String? sidePanelLabel,
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
        sidePanelLabel: sidePanelLabel,
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
    this.sidePanelLabel,
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
  /// either side of her. On a phone she takes the screen, and a control in
  /// her top bar opens the panel in a sheet titled [sidePanelLabel].
  final Widget? sidePanel;

  /// What [sidePanel] is, said by the phone's control and its sheet's title.
  /// Without it a phone offers no way to the panel.
  final String? sidePanelLabel;

  /// The phone sheet's share of the screen's height: room for the panel,
  /// with her still in view above it.
  static const double sidePanelSheetHeightFactor = 0.75;

  /// While true, and [sidePanel] stands beside her, she points at it
  /// ([GestureName.pointRight]) in place of [holding] — at the tasks the
  /// conversation lists as she says them.
  final ProviderListenable<bool>? pointsAtSidePanel;

  /// The divider between her and [sidePanel] on a desktop window.
  @visibleForTesting
  static const Key sidePanelDividerKey = Key('companionStageSideDivider');

  /// The phone's control that opens [sidePanel] in a sheet.
  @visibleForTesting
  static const Key sidePanelButtonKey = Key('companionStageSidePanel');

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
    final panel = sidePanel;
    final panelLabel = sidePanelLabel;
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
                                    Row(
                                      children: [
                                        if (!beside &&
                                            panel != null &&
                                            panelLabel != null) ...[
                                          DsAiDiscButton(
                                            key: CompanionStagePage
                                                .sidePanelButtonKey,
                                            icon: LottiIcons.chat,
                                            label: panelLabel,
                                            onPressed: () =>
                                                _openSidePanelSheet(
                                                  context,
                                                  panel,
                                                  panelLabel,
                                                ),
                                          ),
                                          SizedBox(
                                            width: tokens.spacing.step3,
                                          ),
                                        ],
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

  /// The host's [panel] in a sheet titled [label], on a phone, where it
  /// has no room beside her.
  static void _openSidePanelSheet(
    BuildContext context,
    Widget panel,
    String label,
  ) => ModalUtils.showSinglePageModal<void>(
    context: context,
    title: label,
    padding: EdgeInsets.zero,
    builder: (sheetContext) => SizedBox(
      height:
          MediaQuery.sizeOf(sheetContext).height * sidePanelSheetHeightFactor,
      child: panel,
    ),
  ).ignore();

  /// [stage] alone, or beside the host's [sidePanel] when [beside] — on a
  /// desktop window — split by a [ResizableDivider] at the user's saved
  /// share (`PaneWidths.companionStageShare`), as the app's own columns are.
  Widget _besideSidePanel(bool beside, Widget stage) {
    final panel = sidePanel;
    if (panel == null || !beside) return stage;
    return Consumer(
      builder: (context, ref, _) {
        final share = ref.watch(
          paneWidthControllerProvider.select((w) => w.companionStageShare),
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final span = constraints.maxWidth - ResizableDivider.layoutWidth;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: span * share, child: stage),
                ResizableDivider(
                  key: sidePanelDividerKey,
                  onDrag: (delta) => ref
                      .read(paneWidthControllerProvider.notifier)
                      .updateCompanionStageShare(delta / span),
                  currentValue: span * share,
                  minValue: span * minCompanionStageShare,
                  maxValue: span * maxCompanionStageShare,
                ),
                Expanded(child: panel),
              ],
            );
          },
        );
      },
    );
  }
}
