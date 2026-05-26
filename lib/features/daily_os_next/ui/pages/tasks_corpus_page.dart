import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/state/tasks_corpus_controller.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/category_chip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Browser over the task corpus. Pure read; no agent involvement
/// per the prototype design — Tasks is intentionally secondary to
/// the daily ritual.
class TasksCorpusPage extends ConsumerWidget {
  const TasksCorpusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final asyncItems = ref.watch(tasksCorpusItemsProvider);

    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      appBar: AppBar(
        backgroundColor: tokens.colors.background.level01,
        elevation: 0,
        title: Text(
          context.messages.dailyOsNextTasksTitle,
          style: tokens.typography.styles.subtitle.subtitle1.copyWith(
            color: tokens.colors.text.highEmphasis,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: context.messages.dailyOsNextDayBack,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: tokens.spacing.step4),
              Text(
                context.messages.dailyOsNextTasksSubtitle,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
              SizedBox(height: tokens.spacing.step4),
              const _SearchField(),
              SizedBox(height: tokens.spacing.step3),
              const _StateFilterPills(),
              SizedBox(height: tokens.spacing.step4),
              Expanded(
                child: asyncItems.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text(
                      context.messages.dailyOsNextReconcileError(e.toString()),
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ),
                  data: (items) => items.isEmpty
                      ? _TasksEmptyState()
                      : ListView.separated(
                          itemBuilder: (context, i) => _TaskRow(item: items[i]),
                          separatorBuilder: (_, _) =>
                              SizedBox(height: tokens.spacing.step2),
                          itemCount: items.length,
                        ),
                ),
              ),
              SizedBox(height: tokens.spacing.step3),
              _TasksFooterHint(),
              SizedBox(height: tokens.spacing.step4),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchField extends ConsumerWidget {
  const _SearchField();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    return TextField(
      onChanged: (value) =>
          ref.read(tasksCorpusControllerProvider.notifier).setQuery(value),
      decoration: InputDecoration(
        hintText: context.messages.dailyOsNextTasksSearchPlaceholder,
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 18,
          color: tokens.colors.text.lowEmphasis,
        ),
        filled: true,
        fillColor: tokens.colors.background.level02,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radii.m),
          borderSide: BorderSide.none,
        ),
      ),
      style: tokens.typography.styles.body.bodyMedium.copyWith(
        color: tokens.colors.text.highEmphasis,
      ),
    );
  }
}

class _StateFilterPills extends ConsumerWidget {
  const _StateFilterPills();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final selected = ref.watch(
      tasksCorpusControllerProvider.select((f) => f.stateFilter),
    );
    final notifier = ref.read(tasksCorpusControllerProvider.notifier);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final state in TaskCorpusState.values) ...[
            _FilterPill(
              label: _labelFor(context, state),
              isSelected: selected == state,
              onTap: () => notifier.setStateFilter(state),
            ),
            SizedBox(width: tokens.spacing.step2),
          ],
        ],
      ),
    );
  }

  String _labelFor(BuildContext context, TaskCorpusState s) {
    final m = context.messages;
    switch (s) {
      case TaskCorpusState.all:
        return m.dailyOsNextTasksFilterAll;
      case TaskCorpusState.inProgress:
        return m.dailyOsNextTasksFilterInProgress;
      case TaskCorpusState.overdue:
        return m.dailyOsNextTasksFilterOverdue;
      case TaskCorpusState.scheduled:
        return m.dailyOsNextTasksFilterScheduled;
      case TaskCorpusState.recurring:
        return m.dailyOsNextTasksFilterRecurring;
      case TaskCorpusState.backlog:
        return m.dailyOsNextTasksFilterBacklog;
      case TaskCorpusState.done:
        return m.dailyOsNextTasksFilterDone;
    }
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step3,
          vertical: tokens.spacing.step2,
        ),
        decoration: BoxDecoration(
          color: isSelected ? teal.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
          border: Border.all(
            color: isSelected
                ? teal.withValues(alpha: 0.32)
                : tokens.colors.decorative.level01,
          ),
        ),
        child: Text(
          label,
          style: tokens.typography.styles.body.bodySmall.copyWith(
            color: isSelected ? teal : tokens.colors.text.mediumEmphasis,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.item});

  final TaskCorpusItem item;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final (icon, color, label) = _stateMeta(context, item.state);
    final isDone = item.state == TaskCorpusState.done;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step3,
      ),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Text(
              item.title,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: isDone
                    ? tokens.colors.text.lowEmphasis
                    : tokens.colors.text.highEmphasis,
                decoration: isDone ? TextDecoration.lineThrough : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          CategoryChip(category: item.category),
          SizedBox(width: tokens.spacing.step3),
          Text(
            label,
            style: tokens.typography.styles.others.caption.copyWith(
              color: color,
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          Text(
            item.updatedLabel,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, String) _stateMeta(
    BuildContext context,
    TaskCorpusState s,
  ) {
    final tokens = context.designTokens;
    final m = context.messages;
    switch (s) {
      case TaskCorpusState.all:
        return (
          Icons.list_rounded,
          tokens.colors.text.mediumEmphasis,
          m.dailyOsNextTasksFilterAll,
        );
      case TaskCorpusState.inProgress:
        return (
          Icons.adjust_rounded,
          tokens.colors.alert.warning.defaultColor,
          m.dailyOsNextTasksFilterInProgress,
        );
      case TaskCorpusState.overdue:
        return (
          Icons.warning_amber_rounded,
          tokens.colors.alert.error.defaultColor,
          m.dailyOsNextTasksFilterOverdue,
        );
      case TaskCorpusState.scheduled:
        return (
          Icons.event_rounded,
          tokens.colors.alert.info.defaultColor,
          m.dailyOsNextTasksFilterScheduled,
        );
      case TaskCorpusState.recurring:
        return (
          Icons.refresh_rounded,
          tokens.colors.alert.info.defaultColor,
          m.dailyOsNextTasksFilterRecurring,
        );
      case TaskCorpusState.backlog:
        return (
          Icons.inbox_outlined,
          tokens.colors.text.mediumEmphasis,
          m.dailyOsNextTasksFilterBacklog,
        );
      case TaskCorpusState.done:
        return (
          Icons.check_rounded,
          tokens.colors.alert.success.defaultColor,
          m.dailyOsNextTasksFilterDone,
        );
    }
  }
}

class _TasksEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Center(
      child: Text(
        context.messages.dailyOsNextTasksEmpty,
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    );
  }
}

class _TasksFooterHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        context.messages.dailyOsNextTasksFooterHint,
        style: tokens.typography.styles.body.bodySmall.copyWith(
          color: tokens.colors.text.lowEmphasis,
        ),
      ),
    );
  }
}
