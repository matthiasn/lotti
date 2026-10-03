import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/ui/widgets/category_icon_chip.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/lists/hover_divider_index.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/habits/repository/habits_repository.dart';
import 'package:lotti/features/settings/ui/pages/definitions_list_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';

/// All habit definitions (active and inactive) for the settings list.
/// Co-located with its only consumer; the habits feature's own providers
/// scope to active habits and completion state instead.
final StreamProvider<List<HabitDefinition>> habitDefinitionsStreamProvider =
    StreamProvider.autoDispose<List<HabitDefinition>>(
      (ref) => ref.watch(habitsRepositoryProvider).watchHabitDefinitions(),
    );

/// The habit list as a desktop settings panel: no header of its own — the
/// detail pane's breadcrumb names it — and the create button beside the
/// search.
class HabitSettingsBody extends StatelessWidget {
  const HabitSettingsBody({this.initialSearchTerm, super.key});

  /// See [HabitSettingsPage.initialSearchTerm].
  final String? initialSearchTerm;

  @override
  Widget build(BuildContext context) => HabitSettingsPage(
    initialSearchTerm: initialSearchTerm,
    showHeader: false,
  );
}

/// Settings list of all habit definitions.
///
/// Watches [habitDefinitionsStreamProvider] and hands it to the shared
/// [DefinitionsListPage] shell; rows beam to the per-habit editor and the
/// create button to `/settings/habits/create`. [initialSearchTerm] seeds
/// the filter from deep links like `/settings/habits/search/<term>`.
class HabitSettingsPage extends ConsumerWidget {
  const HabitSettingsPage({
    this.initialSearchTerm,
    this.showHeader = true,
    super.key,
  });

  final String? initialSearchTerm;

  /// See [DefinitionsListPage.showHeader].
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    return DefinitionsListPage<HabitDefinition>(
      showHeader: showHeader,
      itemsAsync: ref.watch(habitDefinitionsStreamProvider),
      title: messages.settingsHabitsTitle,
      searchHint: messages.settingsHabitsSearchHint,
      displayName: (habit) => habit.name,
      initialSearchTerm: initialSearchTerm,
      emptyIcon: LottiIcons.repeat,
      emptyTitle: messages.settingsHabitsEmptyState,
      emptyHint: messages.settingsHabitsEmptyStateHint,
      noMatchMessage: messages.settingsHabitsNoMatchQuery,
      errorTitle: messages.settingsHabitsErrorLoading,
      createLabel: messages.settingsHabitsCreateTitle,
      onCreate: () => beamToNamed('/settings/habits/create'),
      itemBuilder: (context, habit, {required ListRowDivider divider}) =>
          _HabitListItem(habit: habit, divider: divider),
    );
  }
}

class _HabitListItem extends StatelessWidget {
  const _HabitListItem({
    required this.habit,
    required this.divider,
  });

  final HabitDefinition habit;
  final ListRowDivider divider;

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
                  LottiIcons.lock,
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
                  LottiIcons.hidden,
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
                  LottiIcons.star,
                  size: 18,
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
          Icon(
            LottiIcons.chevronRight,
            size: tokens.spacing.step6,
            color: tokens.colors.text.lowEmphasis,
          ),
        ],
      ),
      showDivider: divider.showDivider,
      dividerColor: divider.color,
      dividerIndent:
          tokens.spacing.step5 +
          DefinitionIconChip.defaultSize +
          tokens.spacing.step3,
      onHoverChanged: divider.onHoverChanged,
      onTap: () => beamToNamed('/settings/habits/by_id/${habit.id}'),
    );
  }
}
