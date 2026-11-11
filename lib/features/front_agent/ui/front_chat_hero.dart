import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/companion_card_controller.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';
import 'package:lotti/features/companion/ui/companion_floating_card.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_stage_pointing.dart';
import 'package:lotti/features/front_agent/state/front_voice_providers.dart';
import 'package:lotti/features/front_agent/ui/front_chat_voice.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the hero.
@visibleForTesting
abstract final class FrontChatHeroKeys {
  static const Key hero = Key('front-chat-hero');
  static const Key figure = Key('front-chat-figure');
}

/// She greets a conversation not begun: her bust, large, where the thread
/// will be. Once it has begun the header carries her, so the thread is the
/// conversation's alone.
class FrontChatHero extends StatelessWidget {
  const FrontChatHero({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    key: FrontChatHeroKeys.hero,
    padding: EdgeInsets.only(bottom: context.designTokens.spacing.step5),
    child: const Center(
      child: FrontCompanionFigure(
        key: FrontChatHeroKeys.figure,
        size: ControlSizes.avatarHero,
      ),
    ),
  );
}

/// Her bust in the session's outfit at [size], in a circle or — [rounded] —
/// a rounded tile; the spark every agent wears when the companion character
/// is switched off.
class FrontCompanionFigure extends ConsumerWidget {
  const FrontCompanionFigure({
    required this.size,
    this.rounded = false,
    super.key,
  });

  final double size;

  /// A rounded tile rather than a circle: her face in the header.
  final bool rounded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final companionOn =
        ref.watch(configFlagProvider(enableCompanionFlag)).value ?? false;
    final conversationId = ref.watch(frontActiveConversationProvider).value;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.colors.aiCard.accentSoft,
          shape: rounded ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: rounded ? BorderRadius.circular(tokens.radii.m) : null,
          border: Border.all(color: tokens.colors.aiCard.border),
        ),
        child: companionOn
            ? _SpeakingFigure(conversationId: conversationId)
            : Icon(
                LottiIcons.aiSpark,
                size: size / 2,
                color: tokens.colors.aiCard.accent,
              ),
      ),
    );
  }
}

/// Her bust speaking: her lips follow her voice in [conversationId], and
/// she holds a pose for the turn (listening, thinking). Before any
/// conversation resolves, she simply stands.
class _SpeakingFigure extends ConsumerWidget {
  const _SpeakingFigure({required this.conversationId});

  final String? conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holding = FrontVoice.holdingOf(ref);
    final id = conversationId;
    if (id == null) {
      return CompanionView(
        look: ref
            .watch(companionLookRollProvider)
            .draw(frontCompanionDressedFor),
        framing: CompanionFraming.bust,
        holding: holding,
      );
    }
    // One tree whatever she is doing, so her animator — and the sign-off at
    // the end of an utterance — lives through it.
    return CompanionSpeaker(
      sourceId: frontVoiceSourceId(id),
      dressedFor: frontCompanionDressedFor,
      framing: CompanionFraming.bust,
      holding: holding,
    );
  }
}

/// Her, head to toe, in the glass card floating over [conversationId]'s
/// thread ([CompanionFloatingCard]) — where the user moved her, at the size
/// they left her in [form]. She speaks the conversation's answers, holds the
/// turn's pose as her bust in the header does, and points at what her latest
/// reply lists ([frontStagePointsProvider]) while the thread is to her right.
/// Its menu's customize row calls [onCustomize].
class FrontCompanionCard extends ConsumerWidget {
  const FrontCompanionCard({
    required this.conversationId,
    required this.form,
    required this.onCustomize,
    super.key,
  });

  final String conversationId;
  final CompanionCardForm form;

  /// Opens the page that customizes her.
  final VoidCallback onCustomize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceId = frontVoiceSourceId(conversationId);
    final leftHalf = ref.watch(
      companionCardControllerProvider(form).select((p) => p.x < 0.5),
    );
    final pointing =
        leftHalf && ref.watch(frontStagePointsProvider(conversationId));
    final speaking = ref.watch(
      ttsPlaybackControllerProvider.select((s) => s.isActiveFor(sourceId)),
    );
    final holding = FrontVoice.holdingOf(ref);
    return CompanionFloatingCard(
      form: form,
      speaking: speaking,
      // Her face in the header shows the card; the card puts itself away.
      onHide: ref.read(frontCompanionCardShownProvider.notifier).toggle,
      onCustomize: onCustomize,
      // Decorative: the card carries its own label, and she says nothing a
      // reader would miss.
      figure: ExcludeSemantics(
        child: CompanionSpeaker(
          sourceId: sourceId,
          holding: pointing ? GestureName.pointRight : holding,
          dressedFor: frontCompanionDressedFor,
        ),
      ),
    );
  }
}
