import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// A project entry paired with its owning category ID for grouping.
@immutable
class ProjectWithCategory {
  const ProjectWithCategory({
    required this.project,
    required this.categoryId,
  });

  final ProjectEntry project;
  final String categoryId;
}

/// Shows a selection modal for projects, grouped by category.
///
/// Uses Wolt modal sheet — appears as a bottom sheet on mobile and a centered
/// dialog on desktop, determined automatically by [ModalUtils.modalTypeBuilder].
/// The Done button is rendered as a sticky action bar that remains visible
/// while the project list scrolls.
Future<Set<String>?> showProjectSelectionModal({
  required BuildContext context,
  required List<ProjectWithCategory> projects,
  required List<CategoryDefinition> categories,
  required Set<String> initialSelectedIds,
}) async {
  final selectedIdsNotifier = ValueNotifier({...initialSelectedIds});
  final resolvedLabel = context.messages.doneButton;

  try {
    return await ModalUtils.showSinglePageModal<Set<String>>(
      context: context,
      title: context.messages.projectFilterLabel,
      padding: const EdgeInsets.only(left: 20, top: 8, right: 20, bottom: 20),
      stickyActionBarBuilder: (_) {
        return Builder(
          builder: (ctx) {
            final tokens = ctx.designTokens;
            final palette = DesignSystemFilterPalette.fromTokens(tokens);
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step5,
                vertical: tokens.spacing.step4,
              ),
              child: SizedBox(
                width: double.infinity,
                child: DesignSystemFilterActionButton(
                  key: const ValueKey(
                    'design-system-project-selection-apply',
                  ),
                  label: resolvedLabel,
                  palette: palette,
                  highlighted: true,
                  textStyle: tokens.typography.styles.subtitle.subtitle1,
                  onTap: () => Navigator.of(ctx).pop(
                    selectedIdsNotifier.value,
                  ),
                ),
              ),
            );
          },
        );
      },
      builder: (modalContext) {
        return ValueListenableBuilder<Set<String>>(
          valueListenable: selectedIdsNotifier,
          builder: (ctx, selectedIds, _) {
            final tokens = ctx.designTokens;
            final spacing = tokens.spacing;
            final palette = DesignSystemFilterPalette.fromTokens(tokens);
            final grouped = _groupByCategory(projects, categories);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final group in grouped) ...[
                  Text(
                    group.categoryName,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: palette.secondaryText,
                    ),
                  ),
                  SizedBox(height: spacing.step3),
                  for (var i = 0; i < group.projects.length; i++) ...[
                    _ProjectSelectionRow(
                      project: group.projects[i],
                      selected: selectedIds.contains(
                        group.projects[i].meta.id,
                      ),
                      palette: palette,
                      onTap: () {
                        final next = {...selectedIds};
                        final id = group.projects[i].meta.id;
                        if (!next.add(id)) {
                          next.remove(id);
                        }
                        selectedIdsNotifier.value = next;
                      },
                    ),
                    if (i != group.projects.length - 1)
                      Divider(
                        height: spacing.step6,
                        color: palette.dividerColor,
                      ),
                  ],
                  SizedBox(height: spacing.step6),
                ],
                SizedBox(height: spacing.step10),
              ],
            );
          },
        );
      },
    );
  } finally {
    selectedIdsNotifier.dispose();
  }
}

class _ProjectSelectionRow extends StatelessWidget {
  const _ProjectSelectionRow({
    required this.project,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final ProjectEntry project;
  final bool selected;
  final DesignSystemFilterPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey(
          'design-system-project-selection-option-${project.meta.id}',
        ),
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.step1,
            vertical: spacing.step4,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  project.data.title,
                  style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                    color: palette.primaryText,
                  ),
                ),
              ),
              DesignSystemCheckbox(
                value: selected,
                onChanged: (_) => onTap(),
                semanticsLabel: project.data.title,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@immutable
class _ProjectCategoryGroup {
  const _ProjectCategoryGroup({
    required this.categoryName,
    required this.projects,
  });

  final String categoryName;
  final List<ProjectEntry> projects;
}

List<_ProjectCategoryGroup> _groupByCategory(
  List<ProjectWithCategory> projects,
  List<CategoryDefinition> categories,
) {
  final categoryOrder = {
    for (var i = 0; i < categories.length; i++) categories[i].id: i,
  };
  final categoryNameById = {
    for (final cat in categories) cat.id: cat.name,
  };

  final groups = <String, List<ProjectEntry>>{};
  for (final pwc in projects) {
    groups.putIfAbsent(pwc.categoryId, () => []).add(pwc.project);
  }

  final sortedKeys = groups.keys.toList()
    ..sort((a, b) {
      final aOrder = categoryOrder[a] ?? 999;
      final bOrder = categoryOrder[b] ?? 999;
      return aOrder.compareTo(bOrder);
    });

  return [
    for (final key in sortedKeys)
      _ProjectCategoryGroup(
        categoryName: categoryNameById[key] ?? key,
        projects: groups[key]!,
      ),
  ];
}
