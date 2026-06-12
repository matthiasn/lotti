import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/settings/ui/widgets/settings_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/notification_stream.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';

/// Category picker for the dashboard editor, rendered as a
/// [SettingsPickerField] so it matches the design-system fields around
/// it. Selection happens in a single-page modal listing the categories.
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

        void onTap() {
          ModalUtils.showSinglePageModal<void>(
            context: context,
            title: context.messages.dashboardCategoryLabel,
            builder: (BuildContext _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...categories.map(
                    (category) => SettingsCard(
                      onTap: () {
                        setCategory(category.id);
                        Navigator.pop(context);
                      },
                      title: category.name,
                      leading: CategoryIconCompact(
                        category.id,
                        size: CategoryIconConstants.iconSizeMedium,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        }

        return SettingsPickerField(
          key: const Key('select_dashboard_category'),
          label: context.messages.dashboardCategoryLabel,
          valueText: category?.name,
          hintText: context.messages.habitCategoryHint,
          leading: category != null
              ? CategoryIconCompact(
                  category.id,
                  size: CategoryIconConstants.iconSizeMedium,
                )
              : null,
          onClear: category != null ? () => setCategory(null) : null,
          onTap: onTap,
        );
      },
    );
  }
}
