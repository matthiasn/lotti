import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/lists/grouped_card_row_interactions.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_row.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

export 'package:lotti/features/projects/ui/widgets/project_list_row.dart';

const _kProjectGroupCardRadius = 16.0;
const _kProjectGroupCardPadding = 8.0;
const _kProjectRowOverlap = 1.0;

/// Shared category header row showing the category tag and project count.
class ProjectGroupHeader extends StatelessWidget {
  const ProjectGroupHeader({
    required this.group,
    super.key,
  });

  final ProjectCategoryGroup group;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final category = group.category;
    final color = colorFromCssHex(category?.color ?? defaultCategoryColorHex);

    return Row(
      children: [
        CategoryTag(
          label: category?.name ?? context.messages.taskCategoryUnassignedLabel,
          icon: category?.icon?.iconData ?? Icons.folder_outlined,
          color: color,
        ),
        const Spacer(),
        Text(
          context.messages.projectCountSummary(group.projectCount),
          style: tokens.typography.styles.others.caption.copyWith(
            color: ShowcasePalette.mediumText(context),
          ),
        ),
      ],
    );
  }
}

/// A category-labelled section containing grouped project rows.
class ProjectGroupSection extends StatefulWidget {
  const ProjectGroupSection({
    required this.group,
    required this.selectedProjectId,
    required this.onProjectSelected,
    super.key,
  });

  final ProjectCategoryGroup group;
  final String? selectedProjectId;
  final ValueChanged<ProjectListItemData> onProjectSelected;

  @override
  State<ProjectGroupSection> createState() => _ProjectGroupSectionState();
}

class _ProjectGroupSectionState extends State<ProjectGroupSection> {
  String? _hoveredProjectId;

  @override
  Widget build(BuildContext context) {
    final priorities = widget.group.projects
        .map(
          (project) => _interactionPriority(
            projectId: project.project.meta.id,
            selectedProjectId: widget.selectedProjectId,
            hoveredProjectId: _hoveredProjectId,
          ),
        )
        .toList(growable: false);
    final interactions = buildGroupedCardRowInteractions(
      priorities: priorities,
      connectedBelow: List<bool>.filled(
        math.max(widget.group.projects.length - 1, 0),
        true,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ProjectGroupHeader(group: widget.group),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          key: ValueKey(
            'project-group-card-${widget.group.categoryId ?? 'unassigned'}',
          ),
          decoration: BoxDecoration(
            color: _projectGroupBackgroundColor(context),
            borderRadius: BorderRadius.circular(_kProjectGroupCardRadius),
            border: Border.all(color: ShowcasePalette.border(context)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_kProjectGroupCardRadius),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: _kProjectGroupCardPadding),
                for (
                  var index = 0;
                  index < widget.group.projects.length;
                  index++
                ) ...[
                  ProjectRow(
                    item: widget.group.projects[index],
                    selected:
                        widget.group.projects[index].project.meta.id ==
                        widget.selectedProjectId,
                    topOverlap: interactions[index].topOverlap,
                    bottomOverlap: interactions[index].bottomOverlap,
                    backgroundTopInset: _kProjectGroupCardPadding,
                    backgroundBottomInset: _kProjectGroupCardPadding,
                    onHoverChanged: (hovered) {
                      final projectId =
                          widget.group.projects[index].project.meta.id;
                      setState(() {
                        if (hovered) {
                          _hoveredProjectId = projectId;
                        } else if (_hoveredProjectId == projectId) {
                          _hoveredProjectId = null;
                        }
                      });
                    },
                    onTap: () => widget.onProjectSelected(
                      widget.group.projects[index],
                    ),
                  ),
                  if (index < widget.group.projects.length - 1) ...[
                    const SizedBox(height: _kProjectGroupCardPadding),
                    if (interactions[index].showDividerBelow)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kProjectRowHorizontalPadding,
                        ),
                        child: Divider(
                          key: ValueKey('project-group-divider-$index'),
                          height: 1,
                          thickness: 1,
                          color: ShowcasePalette.border(context),
                        ),
                      )
                    else
                      SizedBox(
                        key: ValueKey(
                          'project-group-divider-slot-$index',
                        ),
                        height: _kProjectRowOverlap,
                      ),
                    const SizedBox(height: _kProjectGroupCardPadding),
                  ],
                ],
                const SizedBox(height: _kProjectGroupCardPadding),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void didUpdateWidget(covariant ProjectGroupSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_hoveredProjectId != null &&
        widget.group.projects.every(
          (project) => project.project.meta.id != _hoveredProjectId,
        )) {
      _hoveredProjectId = null;
    }
  }
}

int _interactionPriority({
  required String projectId,
  required String? selectedProjectId,
  required String? hoveredProjectId,
}) {
  if (projectId == selectedProjectId) {
    return 2;
  }
  if (projectId == hoveredProjectId) {
    return 1;
  }
  return 0;
}

Color _projectGroupBackgroundColor(BuildContext context) {
  return ShowcasePalette.groupedCardSurface(context);
}
