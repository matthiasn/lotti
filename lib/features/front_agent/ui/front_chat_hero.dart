import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';
import 'package:lotti/features/companion/ui/companion_speaker.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/state/front_voice_providers.dart';
import 'package:lotti/features/front_agent/ui/front_chat_voice.dart';
import 'package:lotti/features/front_agent/ui/front_voice_controls.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the hero.
@visibleForTesting
abstract final class FrontChatHeroKeys {
  static const Key hero = Key('front-chat-hero');
  static const Key figure = Key('front-chat-figure');
  static const Key openStage = Key('front-chat-figure-open-stage');
}

/// The open conversation, as the surface names it: the inbox while that
/// view is on, the conversation's title, or her name for one not begun.
({String title, bool archived}) frontOpenConversation(
  WidgetRef ref,
  AppLocalizations messages,
) {
  final inboxOnly = ref.watch(frontInboxFilterProvider);
  final activeId = ref.watch(frontActiveConversationProvider).value;
  final conversation = ref
      .watch(frontConversationsProvider)
      .value
      ?.byId(activeId);
  final title = conversation?.title ?? '';
  return (
    title: inboxOnly
        ? messages.frontChatInboxTitle
        : title.isNotEmpty
        ? title
        : messages.frontChatTitle,
    archived: !inboxOnly && (conversation?.archived ?? false),
  );
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
      child: FrontCompanionFigure(size: ControlSizes.avatarHero),
    ),
  );
}

/// Her bust in the session's outfit at [size]; the spark every agent wears
/// when the companion character is switched off.
class FrontCompanionFigure extends ConsumerWidget {
  const FrontCompanionFigure({required this.size, super.key});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final companionOn =
        ref.watch(configFlagProvider(enableCompanionFlag)).value ?? false;
    final conversationId = ref.watch(frontActiveConversationProvider).value;
    return ExcludeSemantics(
      child: Container(
        key: size == ControlSizes.avatarHero ? FrontChatHeroKeys.figure : null,
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tokens.colors.aiCard.accentSoft,
          shape: BoxShape.circle,
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

/// Her bust speaking: her lips follow her voice in [conversationId], she
/// holds a pose for the turn (listening, thinking), and a tap stands her up
/// full screen, still speaking — stopping her is her voice's control
/// ([FrontVoiceButton]). Before any conversation resolves, she simply
/// stands.
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
    // the end of an utterance — lives through it. Decorative to a screen
    // reader: the stage control beside her carries the same action.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: FrontChatHeroKeys.openStage,
        behavior: HitTestBehavior.opaque,
        onTap: () => openFrontStage(context, id).ignore(),
        child: CompanionSpeaker(
          sourceId: frontVoiceSourceId(id),
          dressedFor: frontCompanionDressedFor,
          framing: CompanionFraming.bust,
          holding: holding,
        ),
      ),
    );
  }
}
