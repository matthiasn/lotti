import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/state/front_category_scope.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the chips.
@visibleForTesting
abstract final class FrontCategoryChipsKeys {
  static Key chip(String categoryId) => Key('front-category-$categoryId');
  static const Key all = Key('front-category-all');
}

/// The open conversation's category chips, above the composer where the
/// question is asked, led by what they do ("Answers from"): choosing some
/// narrows what she answers from to them; none chosen leaves her whole
/// allow-list. Only shown when there is a choice to make — two categories
/// or more she may see.
class FrontCategoryChips extends ConsumerWidget {
  const FrontCategoryChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(frontCategoryOptionsProvider);
    final conversationId = ref.watch(frontActiveConversationProvider).value;
    if (options.length < 2 || conversationId == null) {
      return const SizedBox.shrink();
    }
    final tokens = context.designTokens;
    final chosen = ref.watch(
      frontConversationCategoriesProvider.select(
        (byConversation) => byConversation[conversationId] ?? const {},
      ),
    );
    final scope = ref.read(frontConversationCategoriesProvider.notifier);
    // In the composer, under its own padding: the scope of the question.
    // The label stays put; the chips scroll beside it when they run long.
    return Row(
      children: [
        // What the chips do, said once: they choose what she answers from.
        Text(
          context.messages.frontChatScopeLabel,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        Flexible(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // One chosen form for every chip — the default as much as
                // a chosen category: a neutral fill and a check, never the
                // accent, which stays the talk control's.
                DesignSystemChip(
                  key: FrontCategoryChipsKeys.all,
                  label: context.messages.frontChatScopeAll,
                  outlined: true,
                  selected: chosen.isEmpty,
                  quietSelection: true,
                  leadingIcon: chosen.isEmpty ? LottiIcons.confirm : null,
                  onPressed: () => scope.clear(conversationId),
                ),
                for (final category in options) ...[
                  SizedBox(width: tokens.spacing.step3),
                  DesignSystemChip(
                    key: FrontCategoryChipsKeys.chip(category.id),
                    label: category.name,
                    outlined: true,
                    selected: chosen.contains(category.id),
                    quietSelection: true,
                    leadingIcon: chosen.contains(category.id)
                        ? LottiIcons.confirm
                        : null,
                    onPressed: () => scope.toggle(conversationId, category.id),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
