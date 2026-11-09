import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/ui/ai_summary_card/summary_read_aloud_button.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/companion_mood.dart';
import 'package:lotti/features/companion/rig/stage_painter.dart';
import 'package:lotti/features/companion/state/companion_card_controller.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';
import 'package:lotti/features/companion/ui/companion_floating_card.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/design_system/components/buttons/ds_ai_disc_button.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tts/cloud/tts_cloud_route.dart';
import 'package:lotti/features/tts/state/tts_engine_provider.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// What a host puts on the companion's page in place of her stage: the
/// conversation she speaks in, its field with it, with her floating [card]
/// laid over its thread and [bottomInset] of room after its last message
/// so the thread's end scrolls clear of her.
typedef CompanionConversationBuilder =
    Widget Function({required Widget card, required double bottomInset});

/// Opens the companion full screen — the place a narrow summary card's
/// header bust leads, since that bust shows only her head and shoulders —
/// head to toe on her stage.
///
/// She speaks [sourceId]'s utterance as on the card, so a summary being read
/// aloud carries on in her mouth here, and the read-aloud control below her
/// reads [spokenText], the words the card showed when she was opened. A host
/// that poses her ([mood], [holding] — a goal's status pose) passes the pose
/// on, so the figure the bust was tapped on stands up in the same pose. A
/// host whose voice is not a summary's — the front agent's answers — passes
/// its own [controls] instead of the words, and may pass a [conversation]:
/// the page is then that conversation, with her in a glass card floating
/// over it ([CompanionFloatingCard]) rather than on a stage of her own, and
/// [pointsAtConversation] true while she should point at what it shows. She
/// wears what the card dressed her in: a host that dresses her for another
/// subject than [sourceId] names it as [dressedFor].
Future<void> openCompanionStage(
  BuildContext context, {
  required String sourceId,
  String spokenText = '',
  Widget? controls,
  CompanionConversationBuilder? conversation,
  ProviderListenable<bool>? pointsAtConversation,
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
        conversation: conversation,
        pointsAtConversation: pointsAtConversation,
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
/// With a [conversation] the page is that conversation instead, in the
/// app's own theme: the outfit control, the host's [controls] and the close
/// control in a row along the top, under the system bar and any notch, and
/// her in a [CompanionFloatingCard] over the thread — where the user moved
/// her, at the size they left her.
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
    this.conversation,
    this.pointsAtConversation,
    this.mood = CompanionMood.calm,
    this.holding,
    this.cloudRoute,
    String? dressedFor,
    super.key,
  }) : dressedFor = dressedFor ?? sourceId;

  /// The host's own controls — at her feet on the stage, in the top row
  /// over a [conversation] — in place of the summary's read-aloud control;
  /// they gate themselves.
  final Widget? controls;

  /// The host's conversation, which the page becomes, her floating over it.
  final CompanionConversationBuilder? conversation;

  /// While true, and the conversation is to her right — her card in the
  /// left half — she points at it ([GestureName.pointRight]) in place of
  /// [holding]: at the tasks it lists as she says them.
  final ProviderListenable<bool>? pointsAtConversation;

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

  void _nextOutfit(WidgetRef ref) => ref
      .read(companionOutfitProvider.notifier)
      .next(ref.read(companionLookRollProvider).outfitFor(dressedFor));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canReadAloud =
        spokenText.isNotEmpty &&
        (ref.watch(configFlagProvider(enableAiSummaryTtsFlag)).value ??
            false) &&
        (cloudRoute != null || ref.watch(ttsEngineProvider).isSupported);
    if (conversation case final conversation?) {
      return _overConversation(context, ref, conversation);
    }
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
                body: Column(
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
                                holding: holding,
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
                                    onPressed: () => _nextOutfit(ref),
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
          );
        },
      ),
    );
  }

  /// The page as [conversation], her floating over its thread.
  Widget _overConversation(
    BuildContext context,
    WidgetRef ref,
    CompanionConversationBuilder conversation,
  ) {
    final tokens = context.designTokens;
    final form = isDesktopLayout(context)
        ? CompanionCardForm.desktop
        : CompanionCardForm.phone;
    final placement = ref.watch(companionCardControllerProvider(form));
    final points = pointsAtConversation;
    final pointing = points != null && placement.x < 0.5 && ref.watch(points);
    final speaking = ref.watch(
      ttsPlaybackControllerProvider.select((s) => s.isActiveFor(sourceId)),
    );
    final card = CompanionFloatingCard(
      form: form,
      speaking: speaking,
      onRestyle: () => _nextOutfit(ref),
      // Decorative: the card carries its own label, and she says nothing a
      // reader would miss.
      figure: ExcludeSemantics(
        child: CompanionSpeaker(
          key: const ValueKey('companionStageFigure'),
          sourceId: sourceId,
          mood: mood,
          holding: pointing ? GestureName.pointRight : holding,
          dressedFor: dressedFor,
        ),
      ),
    );
    return Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: context.messages.aiCardCompanionStageTitle,
      child: Scaffold(
        backgroundColor: tokens.colors.background.level01,
        body: Column(
          children: [
            // Under the system bar and any notch: nothing here, her card
            // included, can sit behind the dynamic island.
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: tokens.spacing.cardPadding,
                  vertical: tokens.spacing.step3,
                ),
                child: Row(
                  children: [
                    DsAiDiscButton(
                      key: const ValueKey('companionStageOutfit'),
                      icon: LottiIcons.palette,
                      label: context.messages.aiCardCompanionStageNextOutfit,
                      onPressed: () => _nextOutfit(ref),
                    ),
                    const Spacer(),
                    ?controls,
                    SizedBox(width: tokens.spacing.step3),
                    DsAiDiscButton(
                      icon: LottiIcons.close,
                      label: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: conversation(
                  card: card,
                  // Room for her only while she sits in the lower half,
                  // where the thread's end runs into her.
                  bottomInset: placement.inLowerHalf
                      ? placement.height + tokens.spacing.step5
                      : 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
