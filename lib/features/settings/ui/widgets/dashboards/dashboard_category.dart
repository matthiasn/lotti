import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_chip.dart';
import 'package:lotti/features/categories/ui/widgets/category_picker_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/notification_stream.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';

/// Category picker for the dashboard editor, rendered as a
/// [SettingsPickerField] so it matches the design-system fields around
/// it. Selection happens in [CategoryPickerSheet].
class SelectDashboardCategoryWidget extends StatelessWidget {
  const SelectDashboardCategoryWidget({
    required this.setCategory,
    required this.categoryId,
    super.key,
  });

  final void Function(String?) setCategory;
  final String? categoryId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CategoryDefinition>>(
      stream: notificationDrivenStream(
        notifications: getIt<UpdateNotifications>(),
        notificationKeys: {categoriesNotification, privateToggleNotification},
        fetcher: getIt<JournalDb>().getAllCategories,
      ),
      builder: (context, snapshot) {
        final categories = snapshot.data ?? <CategoryDefinition>[]
          ..sortBy((category) => category.name);
        final categoriesById = <String, CategoryDefinition>{
          for (final category in categories) category.id: category,
        };
        final category = categoriesById[categoryId];

        Future<void> onTap() async {
          final result = await showCategoryPicker(
            context: context,
            title: context.messages.dashboardCategoryLabel,
            currentCategoryId: categoryId,
            // Inactive-inclusive list (getAllCategories) so an existing
            // inactive assignment stays selectable.
            options: categories,
          );
          if (result == null) return;
          setCategory(result.categoryOrNull?.id);
        }

        return SettingsPickerField(
          key: const Key('select_dashboard_category'),
          label: context.messages.optionalCategoryLabel,
          valueText: category?.name,
          hintText: context.messages.habitCategoryHint,
          // Same rounded-square chip language as the list rows.
          leading: category != null
              ? CategoryIconChip(category: category, size: 28)
              : null,
          onClear: category != null ? () => setCategory(null) : null,
          onTap: onTap,
        );
      },
    );
  }
}
