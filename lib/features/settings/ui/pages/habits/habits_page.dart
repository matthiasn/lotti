import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_chip.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/features/settings/ui/pages/definitions_list_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';

/// All habit definitions (active and inactive) for the settings list.
/// Co-located with its only consumer; the habits feature's own providers
/// scope to active habits and completion state instead.
final StreamProvider<List<HabitDefinition>> habitDefinitionsStreamProvider =
    StreamProvider.autoDispose<List<HabitDefinition>>(
      (ref) => ref.watch(habitsRepositoryProvider).watchHabitDefinitions(),
    );

/// Embeddable body alias for the Settings V2 detail pane (plan
/// step 8). See `CategoriesListBody` for the polish note about the
/// duplicate header.
class HabitsBody extends StatelessWidget {
  const HabitsBody({super.key});

  @override
  Widget build(BuildContext context) => const HabitsPage();
}

/// Settings list of all habit definitions.
///
/// Watches [habitDefinitionsStreamProvider] and hands it to the shared
/// [DefinitionsListPage] shell; rows beam to the per-habit editor and the
/// create button to `/settings/habits/create`. [initialSearchTerm] seeds
/// the filter from deep links like `/settings/habits/search/<term>`.
class HabitsPage extends ConsumerWidget {
  const HabitsPage({this.initialSearchTerm, super.key});

  final String? initialSearchTerm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    return DefinitionsListPage<HabitDefinition>(
      itemsAsync: ref.watch(habitDefinitionsStreamProvider),
      title: messages.settingsHabitsTitle,
      searchHint: messages.settingsHabitsSearchHint,
      displayName: (habit) => habit.name,
      initialSearchTerm: initialSearchTerm,
      emptyIcon: Icons.repeat_rounded,
      emptyTitle: messages.settingsHabitsEmptyState,
      emptyHint: messages.settingsHabitsEmptyStateHint,
      noMatchMessage: messages.settingsHabitsNoMatchQuery,
      errorTitle: messages.settingsHabitsErrorLoading,
      createLabel: messages.settingsHabitsCreateTitle,
      onCreate: () => beamToNamed('/settings/habits/create'),
      itemBuilder: (context, habit, {required bool showDivider}) =>
          _HabitListItem(habit: habit, showDivider: showDivider),
    );
  }
}

class _HabitListItem extends StatelessWidget {
  const _HabitListItem({
    required this.habit,
    required this.showDivider,
  });

  final HabitDefinition habit;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isPrivate = habit.private;
    final isFavorite = habit.priority ?? false;

    final description = habit.description.trim();

    return DesignSystemListItem(
      title: habit.name,
      subtitle: description.isNotEmpty ? description : null,
      // Item letter on the category color: the initial matches the row's
      // name while the chip color carries the category.
      leading: CategoryIconChip.fromId(
        habit.categoryId,
        letterFrom: habit.name,
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
                  Icons.star_rounded,
                  size: 18,
                  color: tokens.colors.text.mediumEmphasis,
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
          tokens.spacing.step5 +
          DefinitionIconChip.defaultSize +
          tokens.spacing.step3,
      onTap: () => beamToNamed('/settings/habits/by_id/${habit.id}'),
    );
  }
}
