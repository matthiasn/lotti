import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_color_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_modal_content.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/modals.dart';

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

    final color = category != null
        ? colorFromCssHex(category.color)
        : context.colorScheme.outline.withAlpha(51);

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.taskCategoryLabel,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ColorIcon(
                color,
                size: 12,
              ),
              const SizedBox(width: 10),
              Text(
                category?.name ?? '-',
                style: context.textTheme.titleMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
