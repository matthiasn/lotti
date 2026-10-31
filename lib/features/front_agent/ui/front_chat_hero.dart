import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/state/companion_look_controller.dart';
import 'package:lotti/features/companion/ui/companion_view.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the hero.
@visibleForTesting
abstract final class FrontChatHeroKeys {
  static const Key hero = Key('front-chat-hero');
  static const Key figure = Key('front-chat-figure');
  static const Key title = Key('front-chat-hero-title');
  static const Key archived = Key('front-chat-archived');
}

/// Whether the hero has scrolled out of view, so the header carries her
/// and the title instead. Off whenever the sheet opens.
final NotifierProvider<FrontHeroScrolled, bool> frontHeroScrolledProvider =
    NotifierProvider.autoDispose<FrontHeroScrolled, bool>(
      FrontHeroScrolled.new,
      name: 'frontHeroScrolledProvider',
    );

class FrontHeroScrolled extends Notifier<bool> {
  @override
  bool build() => false;

  /// Follows the thread's scroll: gone once it is past her bust.
  void follow(double offset) {
    final scrolled = offset > ControlSizes.avatarHero;
    if (scrolled != state) state = scrolled;
  }

  /// Another conversation opens at its top, her bust in view.
  void reset() => state = false;
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

/// She leads the conversation: her bust, and under it what the two of you
/// are talking about. It scrolls with the thread, so a long conversation
/// gets the screen back; once it is gone the header carries her and the
/// title in a line.
class FrontChatHero extends ConsumerWidget {
  const FrontChatHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final open = frontOpenConversation(ref, context.messages);
    return Padding(
      key: FrontChatHeroKeys.hero,
      padding: EdgeInsets.only(bottom: tokens.spacing.step5),
      child: Column(
        children: [
          const FrontCompanionFigure(size: ControlSizes.avatarHero),
          SizedBox(height: tokens.spacing.step3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // An archived conversation says so where it is read, as its
              // row does in the list.
              if (open.archived) ...[
                Icon(
                  LottiIcons.archive,
                  key: FrontChatHeroKeys.archived,
                  size: IconSizes.s,
                  color: tokens.colors.text.mediumEmphasis,
                ),
                SizedBox(width: tokens.spacing.step2),
              ],
              // Two lines before it is cut, so a question-long title still
              // says what this conversation is.
              Flexible(
                child: Tooltip(
                  message: open.title,
                  child: Text(
                    open.title,
                    key: FrontChatHeroKeys.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
            ? CompanionView(
                look: ref.watch(companionLookProvider),
                framing: CompanionFraming.bust,
              )
            : Icon(
                LottiIcons.aiSpark,
                size: size / 2,
                color: tokens.colors.aiCard.accent,
              ),
      ),
    );
  }
}
