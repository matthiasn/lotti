import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/projects/state/project_providers.dart';
import 'package:lotti/features/projects/ui/widgets/project_status_chip.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Modal content for selecting a project within a category.
class ProjectSelectionModalContent extends ConsumerWidget {
  const ProjectSelectionModalContent({
    required this.categoryId,
    required this.onProjectSelected,
    this.currentProjectId,
    super.key,
  });

  final String categoryId;
  final void Function(ProjectEntry? project) onProjectSelected;
  final String? currentProjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectsAsync = ref.watch(projectsForCategoryProvider(categoryId));
    final messages = context.messages;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = math.min(screenHeight * 0.9, 640).toDouble();

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: projectsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              context.messages.projectErrorLoadProjects,
              style: TextStyle(color: context.colorScheme.error),
            ),
          ),
        ),
        data: (List<ProjectEntry> projects) {
          final items = <_ProjectItem>[
            _ProjectItem.none(),
            ...projects.map(_ProjectItem.project),
          ];

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  _ProjectRowTile(
                    item: items[i],
                    isSelected: items[i].isNone
                        ? currentProjectId == null
                        : items[i].project!.meta.id == currentProjectId,
                    messages: messages,
                    onTap: () {
                      onProjectSelected(items[i].project);
                      Navigator.pop(context);
                    },
                  ),
                  if (i < items.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 52,
                      color: context.colorScheme.outlineVariant.withValues(
                        alpha: 0.3,
                      ),
                    ),
                ],
                if (projects.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Text(
                      messages.projectNoProjects,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProjectItem {
  _ProjectItem.none() : project = null;
  _ProjectItem.project(this.project);

  final ProjectEntry? project;

  bool get isNone => project == null;
}

class _ProjectRowTile extends StatelessWidget {
  const _ProjectRowTile({
    required this.item,
    required this.isSelected,
    required this.messages,
    required this.onTap,
  });

  final _ProjectItem item;
  final bool isSelected;
  final AppLocalizations messages;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = context.colorScheme.primary;
    final onSurface = context.colorScheme.onSurface;
    final onSurfaceVariant = context.colorScheme.onSurfaceVariant;
    final selectedBg = primary.withValues(alpha: 0.10);

    final iconData = item.isNone
        ? Icons.do_not_disturb_alt_outlined
        : Icons.folder_outlined;
    final title = item.isNone
        ? messages.projectPickerUnassigned
        : item.project!.data.title;
    final iconColor = isSelected ? primary : onSurfaceVariant;
    final titleColor = isSelected ? primary : onSurface;

    return Material(
      color: isSelected ? selectedBg : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Icon(iconData, size: 20, color: iconColor),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: titleColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!item.isNone)
                ProjectStatusChip(status: item.project!.data.status),
              if (isSelected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_rounded, size: 20, color: primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
