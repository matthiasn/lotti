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
  var _expanded = true;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final cardPadding = tokens.spacing.step2;
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
        Semantics(
          header: true,
          button: true,
          expanded: _expanded,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: TapTargets.minimum),
              child: Padding(
                padding: EdgeInsets.only(top: tokens.spacing.step3),
                child: Row(
                  children: [
                    Expanded(child: ProjectGroupHeader(group: widget.group)),
                    SizedBox(width: tokens.spacing.step2),
                    Icon(
                      _expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: ShowcasePalette.mediumText(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          SizedBox(height: tokens.spacing.step2),
          DecoratedBox(
            key: ValueKey(
              'project-group-card-${widget.group.categoryId ?? 'unassigned'}',
            ),
            decoration: BoxDecoration(
              color: _projectGroupBackgroundColor(context),
              borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
              border: Border.all(color: ShowcasePalette.border(context)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tokens.radii.sectionCards),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: cardPadding),
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
                      backgroundTopInset: cardPadding,
                      backgroundBottomInset: cardPadding,
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
                      SizedBox(height: cardPadding),
                      if (interactions[index].showDividerBelow)
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens.spacing.step4,
                          ),
                          child: Divider(
                            key: ValueKey('project-group-divider-$index'),
                            height: BorderWidths.hairline,
                            thickness: BorderWidths.hairline,
                            color: ShowcasePalette.border(context),
                          ),
                        )
                      else
                        SizedBox(
                          key: ValueKey(
                            'project-group-divider-slot-$index',
                          ),
                          height: BorderWidths.hairline,
                        ),
                      SizedBox(height: cardPadding),
                    ],
                  ],
                  SizedBox(height: cardPadding),
                ],
              ),
            ),
          ),
        ],
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
