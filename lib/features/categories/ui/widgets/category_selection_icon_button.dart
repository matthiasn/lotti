import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// An icon button that shows a journal [entry]'s current category and opens
/// the single-select picker to reassign it.
///
/// The button glyph is the entry's [CategoryIconCompact]; tapping opens
/// [showCategoryPicker]. A pick (or an explicit clear, mapped to `null`)
/// persists immediately through `entryControllerProvider.updateCategoryId`;
/// dismissing the picker leaves the assignment unchanged.
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
    final provider = entryControllerProvider(entry.id);
    final notifier = ref.read(provider.notifier);

    return IconButton(
      onPressed: () async {
        final result = await showCategoryPicker(
          context: context,
          title: context.messages.habitCategoryLabel,
          currentCategoryId: entry.categoryId,
        );
        // null = dismissed (no change); CategoryPicked -> the id;
        // CategoryCleared -> null (categoryOrNull maps both to null).
        if (result == null) return;
        await notifier.updateCategoryId(result.categoryOrNull?.id);
      },
      icon: CategoryIconCompact(
        entry.categoryId,
        size: CategoryIconConstants.iconSizeMedium,
      ),
    );
  }
}
