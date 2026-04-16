import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_compact.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings/ui/pages/definitions_list_page.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/services/notification_stream.dart';

class HabitsPage extends StatelessWidget {
  const HabitsPage({this.initialSearchTerm, super.key});

  final String? initialSearchTerm;

  @override
  Widget build(BuildContext context) {
    return DefinitionsListPage<HabitDefinition>(
      stream: notificationDrivenStream(
        notifications: getIt<UpdateNotifications>(),
        notificationKeys: {habitsNotification, privateToggleNotification},
        fetcher: getIt<JournalDb>().getAllHabitDefinitions,
      ),
      floatingActionButton: FloatingAddIcon(
        createFn: () => beamToNamed('/settings/habits/create'),
        semanticLabel: 'Add Habit',
      ),
      title: context.messages.settingsHabitsTitle,
      getName: (habitDefinition) => habitDefinition.name,
      initialSearchTerm: initialSearchTerm,
      definitionCard:
          (int index, HabitDefinition item, {required bool isLast}) {
            return _HabitListItem(habit: item, showDivider: !isLast);
          },
    );
  }
}

class _HabitListItem extends StatelessWidget {
  const _HabitListItem({
    required this.habit,
    required this.showDivider,
  });

  static const double _leadingIconSize = 28;

  final HabitDefinition habit;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isPrivate = habit.private;
    final isFavorite = habit.priority ?? false;

    return DesignSystemListItem(
      title: habit.name,
      leading: CategoryIconCompact(
        habit.categoryId,
        size: _leadingIconSize,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPrivate)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Semantics(
                label: context.messages.privateLabel,
                child: Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          if (!habit.active)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Semantics(
                label: context.messages.inactiveLabel,
                child: Icon(
                  Icons.visibility_off_outlined,
                  size: 18,
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          if (isFavorite)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Semantics(
                label: context.messages.favoriteLabel,
                child: Icon(
                  Icons.star,
                  color: tokens.colors.alert.warning.defaultColor,
                  size: 20,
                ),
              ),
            ),
          Icon(
            Icons.chevron_right_rounded,
            size: tokens.spacing.step6,
            color: tokens.colors.text.lowEmphasis,
          ),
        ],
      ),
      showDivider: showDivider,
      dividerIndent:
          tokens.spacing.step5 + _leadingIconSize + tokens.spacing.step3,
      onTap: () => beamToNamed('/settings/habits/by_id/${habit.id}'),
    );
  }
}
