import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class TasksTabHeader extends StatelessWidget {
  const TasksTabHeader({
    required this.query,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onSearchPressed,
    required this.onFilterPressed,
    super.key,
  });

  final String query;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final ValueChanged<String> onSearchPressed;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isCompact = MediaQuery.sizeOf(context).width < 600;
    final topPadding = isCompact
        ? tokens.spacing.step5 + tokens.spacing.step2
        : tokens.spacing.step3;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        topPadding,
        tokens.spacing.step5,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  context.messages.navTabTitleTasks,
                  style: tokens.typography.styles.heading.heading3.copyWith(
                    color: TaskShowcasePalette.highText(context),
                  ),
                ),
              ),
              Icon(
                Icons.notifications_none_rounded,
                size: 34,
                color: TaskShowcasePalette.highText(context),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step5 + tokens.spacing.step3),
          Row(
            children: [
              Expanded(
                child: DesignSystemSearch(
                  hintText: context.messages.searchTasksHint,
                  size: DesignSystemSearchSize.small,
                  initialText: query,
                  onChanged: onSearchChanged,
                  onClear: onSearchCleared,
                  onSearchPressed: onSearchPressed,
                ),
              ),
              SizedBox(width: tokens.spacing.step4),
              IconButton(
                tooltip: context.messages.tasksFilterTitle,
                onPressed: onFilterPressed,
                icon: Icon(
                  Icons.filter_list_rounded,
                  size: 24,
                  color: TaskShowcasePalette.accent(context),
                ),
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step5),
        ],
      ),
    );
  }
}
