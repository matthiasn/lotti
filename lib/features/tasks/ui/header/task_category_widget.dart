import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_modal_content.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

typedef CategoryIdCallback = Future<bool> Function(String?);

class TaskCategoryWidget extends StatelessWidget {
  const TaskCategoryWidget({
    required this.onSave,
    required this.category,
    super.key,
  });

  final CategoryDefinition? category;
  final CategoryIdCallback onSave;

  @override
  Widget build(BuildContext context) {
    final category = this.category;

    void onTap() {
      ModalUtils.showSinglePageModal<void>(
        context: context,
        title: context.messages.habitCategoryLabel,
        builder: (BuildContext _) {
          return CategorySelectionModalContent(
            onCategorySelected: (category) {
              onSave(category?.id);
              Navigator.pop(context);
            },
            initialCategoryId: category?.id,
          );
        },
      );
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              context.messages.taskCategoryLabel,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.outline,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                      right: CategoryIconConstants.smallSectionSpacing),
                  child: CategoryIconCompact(
                    category?.id,
                    size: CategoryIconConstants.iconSizeMedium,
                  ),
                ),
                Flexible(
                  child: Text(
                    category?.name ?? '-',
                    style: context.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
