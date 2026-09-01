import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon_data.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/lockdown/domain/lockdown_state.dart';
import 'package:lotti/features/lockdown/state/lockdown_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

/// Stable key prefix for the per-category rows of the logo menu; the full
/// key is `Key('${lockdownMenuCategoryKeyPrefix}<categoryId>')`.
@visibleForTesting
const String lockdownMenuCategoryKeyPrefix = 'lockdown-menu-category-';

/// Stable key on the "exit lockdown" row of the logo menu.
@visibleForTesting
const Key lockdownMenuClearKey = Key('lockdown-menu-clear');

/// The hidden lockdown menu behind the desktop sidebar's brand logo.
///
/// Two shapes, decided by [LockdownState.isActive]:
///
/// - **Inactive:** a heading and one row per active category; tapping a row
///   locks the app down to that category. The picker is single-select on
///   purpose — the state already carries a set, so a multi-select picker is
///   a UI change, not a model change.
/// - **Active:** the locked category, rendered selected, and an exit row.
///   The other categories are *not* listed — this menu is the demo's exit,
///   and it must not spell out what the demo is hiding.
///
/// [items] and [header] are pure over the provider state so the shell can
/// hand them to `DesktopNavigationSidebar` without owning any of the logic.
abstract final class LockdownLogoMenu {
  /// Heading of the menu for the current lockdown state.
  static String header(BuildContext context, LockdownState lockdown) =>
      lockdown.isActive
      ? context.messages.lockdownMenuActiveHeader
      : context.messages.lockdownMenuHeader;

  /// Rows of the menu for the current lockdown state.
  static List<DesignSystemContextMenuItem> items(
    BuildContext context,
    WidgetRef ref, {
    required LockdownState lockdown,
    required List<CategoryDefinition> categories,
  }) {
    final controller = ref.read(lockdownControllerProvider.notifier);
    final tokens = context.designTokens;
    if (categories.isEmpty && !lockdown.isActive) {
      return [
        DesignSystemContextMenuItem(
          label: context.messages.lockdownMenuNoCategories,
        ),
      ];
    }
    return [
      // The caller already hands over a scoped list; filtering again here
      // keeps the "never name a hidden category" rule local to the menu.
      for (final category in categories)
        if (lockdown.allows(category.id))
          DesignSystemContextMenuItem(
            key: Key('$lockdownMenuCategoryKeyPrefix${category.id}'),
            label: category.name,
            icon: categoryIconData[category.icon] ?? LottiIcons.folder,
            iconColor: colorFromCssHex(
              category.color,
              substitute: tokens.colors.text.mediumEmphasis,
            ),
            isSelected: lockdown.isActive && lockdown.allows(category.id),
            // Re-picking the locked category is a no-op rather than a toggle:
            // the exit row below is the one deliberate way out.
            onTap: lockdown.allows(category.id) && lockdown.isActive
                ? null
                : () => controller.lockToCategory(category.id),
          ),
      if (lockdown.isActive)
        DesignSystemContextMenuItem(
          key: lockdownMenuClearKey,
          label: context.messages.lockdownMenuClear,
          icon: LottiIcons.unlocked,
          onTap: controller.clear,
        ),
    ];
  }
}
