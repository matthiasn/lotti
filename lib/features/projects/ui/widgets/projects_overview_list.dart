import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_shared.dart';

/// Sliver that renders the grouped project overview as a vertical stack of
/// [ProjectGroupSection]s, one per category group, with spacing between them.
///
/// Each group is width-constrained by [DetailContentWidth], and
/// [selectedProjectId] highlights the active row in the desktop split view.
class ProjectsOverviewSliverList extends StatelessWidget {
  const ProjectsOverviewSliverList({
    required this.groups,
    required this.onProjectTap,
    this.selectedProjectId,
    this.bottomPadding = 24,
    super.key,
  });

  final List<ProjectCategoryGroup> groups;
  final ValueChanged<ProjectListItemData> onProjectTap;
  final String? selectedProjectId;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      sliver: SliverMainAxisGroup(
        slivers: [
          for (var index = 0; index < groups.length; index++) ...[
            SliverToBoxAdapter(
              child: DetailContentWidth(
                child: ProjectGroupSection(
                  group: groups[index],
                  selectedProjectId: selectedProjectId,
                  onProjectSelected: onProjectTap,
                ),
              ),
            ),
            if (index < groups.length - 1)
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ],
      ),
    );
  }
}
