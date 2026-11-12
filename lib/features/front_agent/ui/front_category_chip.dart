import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/state/front_chat_category.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_mention_categories.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the category chip and its sheet.
@visibleForTesting
abstract final class FrontCategoryChipKeys {
  static const Key chip = Key('front-chat-category-chip');
  static const Key everything = Key('front-chat-category-everything');
  static Key option(String categoryId) =>
      Key('front-chat-category-$categoryId');
}

/// A category's colour as a small rounded square — or, for no category
/// ("Everything"), its outline. Never alone: wherever it stands, the
/// category's name is said beside it or in the semantics around it.
class FrontCategorySwatch extends StatelessWidget {
  const FrontCategorySwatch({this.category, super.key}) : _slot = false;

  /// The swatch centred in a glyph-sized box: a row's leading slot, so its
  /// label starts where the label of a row led by an icon does.
  const FrontCategorySwatch.inSlot({this.category, super.key}) : _slot = true;

  final CategoryDefinition? category;
  final bool _slot;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final color = category == null ? null : colorFromCssHex(category!.color);
    final swatch = SizedBox.square(
      dimension: tokens.spacing.step3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(tokens.radii.xs),
          border: color == null
              ? Border.all(color: tokens.colors.text.lowEmphasis)
              : null,
        ),
      ),
    );
    return _slot
        ? SizedBox.square(
            dimension: IconSizes.s,
            child: Center(child: swatch),
          )
        : swatch;
  }
}

/// The composer's category, at the start of its controls row: the open
/// conversation's scope ([frontChatCategoryProvider]) — its colour, its name,
/// a chevron — or "Everything". A tap opens [FrontCategorySheet] to change
/// it; every turn sent from then on carries what is picked.
class FrontCategoryChip extends ConsumerWidget {
  const FrontCategoryChip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final category = ref.watch(frontChatCategoryProvider);
    final canOpen = ref.watch(frontActiveConversationProvider).value != null;
    final name = category?.name ?? messages.frontChatCategoryEverything;
    void open() => FrontCategorySheet.show(context);
    return DesignSystemChip(
      key: FrontCategoryChipKeys.chip,
      label: name,
      semanticsLabel: messages.frontChatCategoryChip(name),
      size: DesignSystemChipSize.compactPillTouch,
      // The chip clips its avatar to a circle: the swatch keeps its own
      // shape and size inside it.
      avatar: Center(child: FrontCategorySwatch(category: category)),
      trailing: Icon(
        LottiIcons.chevronDown,
        size: IconSizes.xs,
        color: tokens.colors.text.mediumEmphasis,
      ),
      onPressed: canOpen ? open : null,
    );
  }
}

/// Picks the open conversation's category: what it does, one row per
/// category she may see plus "Everything", the current one checked, and a
/// word on `@`, which narrows one question rather than the conversation.
class FrontCategorySheet extends ConsumerWidget {
  const FrontCategorySheet({super.key});

  /// Opens the sheet over the chat: a bottom sheet on a phone, a dialog on
  /// a wide window.
  static Future<void> show(BuildContext context) =>
      ModalUtils.showSinglePageModal<void>(
        context: context,
        title: context.messages.frontChatCategorySheetTitle,
        // The rows run edge to edge, as in her other pickers; the words
        // over and under them keep the gutter themselves.
        padding: EdgeInsets.zero,
        builder: (_) => const FrontCategorySheet(),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final options = ref.watch(frontMentionCategoriesProvider);
    final current = ref.watch(frontChatCategoryProvider);
    final conversationId = ref.watch(frontActiveConversationProvider).value;
    final quiet = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
    );

    void choose(String? categoryId) {
      if (conversationId != null) {
        ref
            .read(frontChatCategoryPickProvider.notifier)
            .pick(conversationId, categoryId);
      }
      Navigator.of(context).pop();
    }

    Widget gutter(Widget child, {double top = 0}) => Padding(
      padding: EdgeInsets.only(
        left: tokens.spacing.step5,
        top: top,
        right: tokens.spacing.step5,
      ),
      child: child,
    );

    Widget row({
      required Key key,
      required String title,
      required CategoryDefinition? category,
    }) {
      final selected = current?.id == category?.id;
      return DesignSystemSelectionRow(
        key: key,
        title: title,
        type: DesignSystemSelectionRowType.singleSelect,
        size: DesignSystemListItemSize.small,
        selected: selected,
        selectedLabel: messages.designSystemSelectedLabel,
        // Said by the word and the tick: no band, so "selected" looks the
        // same here as in the drawer.
        showSelectedBackground: false,
        leading: FrontCategorySwatch.inSlot(category: category),
        onTap: () => choose(category?.id),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: tokens.spacing.step4,
      children: [
        gutter(
          Text(messages.frontChatCategorySheetBody, style: quiet),
          top: tokens.spacing.step4,
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The default, and the way back to it, where the eye lands.
            row(
              key: FrontCategoryChipKeys.everything,
              title: messages.frontChatCategoryEverything,
              category: null,
            ),
            for (final category in options)
              row(
                key: FrontCategoryChipKeys.option(category.id),
                title: category.name,
                category: category,
              ),
          ],
        ),
        // A note, a step under the choices.
        gutter(
          Text(
            messages.frontChatCategorySheetMention,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ),
        SizedBox(height: tokens.spacing.step2),
      ],
    );
  }
}
