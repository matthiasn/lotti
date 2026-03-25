import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/task_list_items/design_system_task_list_item.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookComponent buildDesignSystemTaskListItemWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Task list item',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _TaskListItemOverviewPage(),
      ),
    ],
  );
}

class _TaskListItemOverviewPage extends StatelessWidget {
  const _TaskListItemOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: [
          _TaskListItemSection(
            title: context.messages.designSystemTaskListItemSectionTitle,
            child: const _TaskListItemVariants(),
          ),
        ],
      ),
    );
  }
}

class _TaskListItemSection extends StatelessWidget {
  const _TaskListItemSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _TaskListItemVariants extends StatelessWidget {
  const _TaskListItemVariants();

  @override
  Widget build(BuildContext context) {
    final descriptionStyle = Theme.of(context).textTheme.bodySmall;
    final messages = context.messages;
    final sampleTitle = messages.designSystemTaskListSampleTitle;
    final sampleTime = messages.designSystemTaskListSampleTime;
    const sampleCategory = DesignSystemTaskCategory(
      label: 'Study',
      badgeTone: DesignSystemBadgeTone.success,
    );

    return SizedBox(
      width: 480,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Default
          Text(
            messages.designSystemTaskListDefaultLabel,
            style: descriptionStyle,
          ),
          const SizedBox(height: 8),
          DesignSystemTaskListItem(
            title: sampleTitle,
            category: sampleCategory,
            priority: DesignSystemTaskPriority.p2,
            status: DesignSystemTaskStatus.blocked,
            statusLabel: messages.designSystemTaskListBlockedLabel,
            timeRange: sampleTime,
            showDivider: true,
            onTap: () {},
          ),

          const SizedBox(height: 16),

          // Hover
          Text(
            messages.designSystemTaskListHoverLabel,
            style: descriptionStyle,
          ),
          const SizedBox(height: 8),
          DesignSystemTaskListItem(
            title: sampleTitle,
            category: sampleCategory,
            priority: DesignSystemTaskPriority.p2,
            status: DesignSystemTaskStatus.blocked,
            statusLabel: messages.designSystemTaskListBlockedLabel,
            timeRange: sampleTime,
            forcedState: DesignSystemTaskListItemVisualState.hover,
            showDivider: true,
            onTap: () {},
          ),

          const SizedBox(height: 16),

          // Pressed
          Text(
            messages.designSystemTaskListPressedLabel,
            style: descriptionStyle,
          ),
          const SizedBox(height: 8),
          DesignSystemTaskListItem(
            title: sampleTitle,
            category: sampleCategory,
            priority: DesignSystemTaskPriority.p2,
            status: DesignSystemTaskStatus.blocked,
            statusLabel: messages.designSystemTaskListBlockedLabel,
            timeRange: sampleTime,
            forcedState: DesignSystemTaskListItemVisualState.pressed,
            showDivider: true,
            onTap: () {},
          ),

          const SizedBox(height: 16),

          // Open status
          Text(
            messages.designSystemTaskListOpenLabel,
            style: descriptionStyle,
          ),
          const SizedBox(height: 8),
          DesignSystemTaskListItem(
            title: 'Payment confirmation',
            category: const DesignSystemTaskCategory(
              label: 'Work',
            ),
            priority: DesignSystemTaskPriority.p1,
            status: DesignSystemTaskStatus.open,
            statusLabel: messages.designSystemTaskListOpenLabel,
            timeRange: '10:00-11:30am',
            showDivider: true,
            onTap: () {},
          ),

          const SizedBox(height: 16),

          // On Hold status
          Text(
            messages.designSystemTaskListOnHoldLabel,
            style: descriptionStyle,
          ),
          const SizedBox(height: 8),
          DesignSystemTaskListItem(
            title: 'Team Lunch',
            category: const DesignSystemTaskCategory(
              label: 'Leisure',
              badgeTone: DesignSystemBadgeTone.danger,
            ),
            priority: DesignSystemTaskPriority.p3,
            status: DesignSystemTaskStatus.onHold,
            statusLabel: messages.designSystemTaskListOnHoldLabel,
            timeRange: '12:30-1:15pm',
            showDivider: true,
            onTap: () {},
          ),

          const SizedBox(height: 16),

          // With divider (list)
          Text(
            messages.designSystemTaskListWithDividerLabel,
            style: descriptionStyle,
          ),
          const SizedBox(height: 8),
          DesignSystemTaskListItem(
            title: sampleTitle,
            category: sampleCategory,
            priority: DesignSystemTaskPriority.p2,
            status: DesignSystemTaskStatus.blocked,
            statusLabel: messages.designSystemTaskListBlockedLabel,
            timeRange: sampleTime,
            showDivider: true,
            onTap: () {},
          ),
          DesignSystemTaskListItem(
            title: 'Payment confirmation',
            category: const DesignSystemTaskCategory(
              label: 'Work',
            ),
            priority: DesignSystemTaskPriority.p1,
            status: DesignSystemTaskStatus.open,
            statusLabel: messages.designSystemTaskListOpenLabel,
            timeRange: '10:00-11:30am',
            showDivider: true,
            onTap: () {},
          ),
          DesignSystemTaskListItem(
            title: 'Team Lunch',
            category: const DesignSystemTaskCategory(
              label: 'Leisure',
              badgeTone: DesignSystemBadgeTone.danger,
            ),
            priority: DesignSystemTaskPriority.p3,
            status: DesignSystemTaskStatus.onHold,
            statusLabel: messages.designSystemTaskListOnHoldLabel,
            timeRange: '12:30-1:15pm',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
