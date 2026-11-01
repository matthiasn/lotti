import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/state/front_category_scope.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the chips.
@visibleForTesting
abstract final class FrontCategoryChipsKeys {
  static Key chip(String categoryId) => Key('front-category-$categoryId');
}

/// The open conversation's category chips, under her header: choosing some
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step5,
        vertical: tokens.spacing.step2,
      ),
      child: Row(
        children: [
          for (final category in options)
            Padding(
              padding: EdgeInsets.only(right: tokens.spacing.step2),
              child: DesignSystemChip(
                key: FrontCategoryChipsKeys.chip(category.id),
                label: category.name,
                selected: chosen.contains(category.id),
                onPressed: () => scope.toggle(conversationId, category.id),
              ),
            ),
        ],
      ),
    );
  }
}
