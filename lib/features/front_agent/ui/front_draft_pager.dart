import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/ui/front_category_chip.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// What sits at the start of the companion's chat box: the conversation's
/// [category] chip, and the box's pages once Edit has given it more than
/// one — or nothing, which leaves the box its helper text.
Widget? frontComposerLeading({
  required bool category,
  required FrontChatComposerState composer,
  required ValueChanged<int> onShowPage,
}) {
  final paged = composer.asideDrafts.isNotEmpty;
  if (!paged) return category ? const FrontCategoryChip() : null;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (category) const FrontCategoryChip(),
      if (paged)
        FrontDraftPager(
          page: composer.draftPage,
          count: composer.asideDrafts.length + 1,
          onShow: onShowPage,
        ),
    ],
  );
}

/// Stable keys for the chat box's pager.
@visibleForTesting
abstract final class FrontDraftPagerKeys {
  static const previous = Key('front-draft-pager-previous');
  static const next = Key('front-draft-pager-next');
  static const page = Key('front-draft-pager-page');
}

/// Flips the companion's chat box between its pages — what was being typed,
/// and the words of a stopped turn taken back into it — as ‹ 2/2 ›.
/// [page] counts from 0; [onShow] is handed the page to put in the box.
class FrontDraftPager extends StatelessWidget {
  const FrontDraftPager({
    required this.page,
    required this.count,
    required this.onShow,
    super.key,
  });

  final int page;
  final int count;
  final ValueChanged<int> onShow;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DesignSystemIconAction(
          key: FrontDraftPagerKeys.previous,
          icon: LottiIcons.chevronLeft,
          tooltip: messages.frontChatDraftPrevious,
          onPressed: page > 0 ? () => onShow(page - 1) : null,
        ),
        Semantics(
          label: messages.frontChatDraftPageLabel(page + 1, count),
          excludeSemantics: true,
          child: Text(
            messages.frontChatDraftPage(page + 1, count),
            key: FrontDraftPagerKeys.page,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        DesignSystemIconAction(
          key: FrontDraftPagerKeys.next,
          icon: LottiIcons.chevronRight,
          tooltip: messages.frontChatDraftNext,
          onPressed: page < count - 1 ? () => onShow(page + 1) : null,
        ),
      ],
    );
  }
}
