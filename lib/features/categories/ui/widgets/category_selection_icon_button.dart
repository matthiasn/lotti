import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_modal_content.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class CategorySelectionIconButton extends ConsumerWidget {
  const CategorySelectionIconButton({
    required this.entry,
    super.key,
  });

  final JournalEntity entry;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final provider = entryControllerProvider(id: entry.id);
    final notifier = ref.read(provider.notifier);

    return IconButton(
      onPressed: () {
        ModalUtils.showSinglePageModal<void>(
          context: context,
          title: context.messages.habitCategoryLabel,
          builder: (BuildContext _) {
            return CategorySelectionModalContent(
              onCategorySelected: (category) {
                notifier.updateCategoryId(category?.id);
                Navigator.pop(context);
              },
              initialCategoryId: entry.categoryId,
            );
          },
        );
      },
      icon: CategoryIconCompact(
        entry.categoryId,
      ),
    );
  }
}
