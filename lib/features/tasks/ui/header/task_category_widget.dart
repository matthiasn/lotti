import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_selection_modal_content.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/cards/modern_status_chip.dart';
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

    final theme = Theme.of(context);
    final Color chipColor;
    final String chipLabel;
    IconData? chipIcon;

    if (category != null) {
      chipLabel = category.name;
      chipColor = colorFromCssHex(
        category.color,
        substitute: theme.colorScheme.primary,
      );
      chipIcon = category.icon?.iconData;
    } else {
      chipLabel = context.messages.taskCategoryUnassignedLabel;
      chipColor = theme.colorScheme.outline;
      chipIcon = Icons.category_outlined;
    }

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
        child: ModernStatusChip(
          label: chipLabel,
          color: chipColor,
          icon: chipIcon,
          borderWidth: AppTheme.statusIndicatorBorderWidth * 1.5,
        ),
      ),
    );
  }
}
