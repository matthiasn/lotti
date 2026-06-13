import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/settings/settings_switch_row.dart';

/// Data class for category switch settings
class CategorySwitchSettings {
  const CategorySwitchSettings({
    required this.isPrivate,
    required this.isActive,
    required this.isFavorite,
    required this.isAvailableForDayPlan,
  });

  final bool isPrivate;
  final bool isActive;
  final bool isFavorite;
  final bool isAvailableForDayPlan;
}

/// Callback type for switch value changes
typedef SwitchFieldChanged =
    void Function(SwitchFieldType field, {required bool value});

/// Enum to identify which switch was changed
enum SwitchFieldType { private, active, favorite, availableForDayPlan }

/// A widget that displays four switch rows for category settings.
///
/// This widget shows [SettingsSwitchRow]s in the shared Options order used
/// by every definition editor — Favorite, Private, Active, then the
/// category-only Day planning row. It's designed to be independent of
/// Riverpod for better testability.
class CategorySwitchTiles extends StatelessWidget {
  const CategorySwitchTiles({
    required this.settings,
    required this.onChanged,
    super.key,
  });

  final CategorySwitchSettings settings;
  final SwitchFieldChanged onChanged;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final rows = <(SwitchFieldType, String, String?, IconData, bool)>[
      (
        SwitchFieldType.favorite,
        messages.favoriteLabel,
        null,
        Icons.star_outline_rounded,
        settings.isFavorite,
      ),
      (
        SwitchFieldType.private,
        messages.privateLabel,
        messages.privateSwitchDescription,
        Icons.lock_outline,
        settings.isPrivate,
      ),
      (
        SwitchFieldType.active,
        messages.activeLabel,
        messages.categoryActiveSwitchDescription,
        Icons.visibility_outlined,
        settings.isActive,
      ),
      (
        SwitchFieldType.availableForDayPlan,
        messages.categoryDayPlanLabel,
        messages.categoryDayPlanDescription,
        Icons.today_outlined,
        settings.isAvailableForDayPlan,
      ),
    ];

    return Column(
      children: [
        for (final (field, title, subtitle, icon, value) in rows)
          SettingsSwitchRow(
            title: title,
            subtitle: subtitle,
            icon: icon,
            value: value,
            onChanged: (newValue) => onChanged(field, value: newValue),
          ),
      ],
    );
  }
}
