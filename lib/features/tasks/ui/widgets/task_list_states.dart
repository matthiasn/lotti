import 'dart:async';

import 'package:lotti/features/demo/ui/demo_entry_launcher.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// What the task list says when it shows no task, and the way out of it.
///
/// A search that found nothing names the search and offers to clear it; a
/// filter that matched nothing offers to reset the filters; with nothing
/// narrowing, the default open-work view is empty — "No open tasks", since
/// closed tasks may still exist — and keeps the demo offer, which gates
/// itself to a truly empty journal.
class TaskListEmptyState extends StatelessWidget {
  const TaskListEmptyState({
    required this.query,
    required this.filtersActive,
    required this.onClearSearch,
    required this.onClearFilters,
    this.pullRequestSearch = false,
    super.key,
  });

  /// The typed search, as the page holds it.
  final String query;

  /// Whether any filter narrows the list.
  final bool filtersActive;
  final Future<void> Function() onClearSearch;
  final Future<void> Function() onClearFilters;

  /// The search is a pull request link, whose miss says no task is linked.
  final bool pullRequestSearch;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final search = query.trim();
    final (title, action) = search.isNotEmpty
        ? (
            pullRequestSearch
                ? messages.tasksSearchNoLinkedTasks
                : messages.tasksEmptySearchMiss(search),
            _Action(
              label: messages.tasksEmptyClearSearch,
              onPressed: onClearSearch,
            ),
          )
        : filtersActive
        ? (
            messages.tasksEmptyFilterMiss,
            _Action(
              label: messages.tasksEmptyClearFilters,
              onPressed: onClearFilters,
            ),
          )
        : (messages.tasksEmptyNoOpenTasks, const DemoTryButton());

    return DesignSystemEmptyState(
      icon: LottiIcons.list,
      title: title,
      action: action,
    );
  }
}

/// The task list's loading mark: the design-system spinner, centred with
/// room above it. [inline] is the smaller gap under rows already shown,
/// while the next page loads.
class TaskListSpinner extends StatelessWidget {
  const TaskListSpinner({this.inline = false, super.key});

  final bool inline;

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;
    return Padding(
      padding: inline
          ? EdgeInsets.symmetric(vertical: spacing.step6)
          : EdgeInsets.only(top: spacing.step7),
      child: const Center(child: DesignSystemSpinner(size: IconSizes.xl)),
    );
  }
}

/// The task list could not load: says so and offers to try again, instead
/// of the pagination package's default error text.
class TaskListErrorState extends StatelessWidget {
  const TaskListErrorState({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => DesignSystemEmptyState(
    icon: LottiIcons.warning,
    title: context.messages.tasksListLoadFailed,
    action: _Action(
      label: context.messages.tasksListRetry,
      onPressed: onRetry,
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onPressed});

  final String label;
  final FutureOr<void> Function() onPressed;

  @override
  Widget build(BuildContext context) => DesignSystemButton(
    label: label,
    onPressed: () async => onPressed(),
    variant: DesignSystemButtonVariant.secondary,
  );
}
