import 'package:flutter/material.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_pane.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/color.dart';

const _desktopContentMaxWidth = 760.0;
const _desktopBreakpoint = 960.0;

class ProjectsOverviewSliverList extends StatelessWidget {
  const ProjectsOverviewSliverList({
    required this.groups,
    required this.onProjectTap,
    super.key,
  });

  final List<ProjectCategoryGroup> groups;
  final ValueChanged<ProjectListItemData> onProjectTap;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      sliver: SliverMainAxisGroup(
        slivers: [
          for (var index = 0; index < groups.length; index++) ...[
            _ProjectCategoryHeaderSliver(group: groups[index]),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            _ProjectCategoryRowsSliver(
              group: groups[index],
              onProjectTap: onProjectTap,
            ),
            if (index < groups.length - 1)
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
        ],
      ),
    );
  }
}

class _ProjectCategoryHeaderSliver extends StatelessWidget {
  const _ProjectCategoryHeaderSliver({
    required this.group,
  });

  final ProjectCategoryGroup group;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final category = group.category;
    final color = colorFromCssHex(category?.color ?? defaultCategoryColorHex);

    return SliverToBoxAdapter(
      child: _CenteredProjectsContent(
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              CategoryTag(
                label:
                    category?.name ??
                    context.messages.taskCategoryUnassignedLabel,
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
          ),
        ),
      ),
    );
  }
}

class _ProjectCategoryRowsSliver extends StatelessWidget {
  const _ProjectCategoryRowsSliver({
    required this.group,
    required this.onProjectTap,
  });

  final ProjectCategoryGroup group;
  final ValueChanged<ProjectListItemData> onProjectTap;

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = group.projects[index];
        return _CenteredProjectsContent(
          child: _ProjectRowCard(
            item: item,
            isFirst: index == 0,
            isLast: index == group.projects.length - 1,
            onTap: () => onProjectTap(item),
          ),
        );
      }, childCount: group.projects.length),
    );
  }
}

class _CenteredProjectsContent extends StatelessWidget {
  const _CenteredProjectsContent({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxWidth = screenWidth >= _desktopBreakpoint
        ? _desktopContentMaxWidth
        : double.infinity;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class _ProjectRowCard extends StatelessWidget {
  const _ProjectRowCard({
    required this.item,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  final ProjectListItemData item;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.vertical(
      top: isFirst
          ? const Radius.circular(AppTheme.cardBorderRadius)
          : Radius.zero,
      bottom: isLast
          ? const Radius.circular(AppTheme.cardBorderRadius)
          : Radius.zero,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ShowcasePalette.surface(context),
        borderRadius: radius,
        border: Border(
          top: isFirst
              ? BorderSide(color: ShowcasePalette.border(context))
              : BorderSide.none,
          left: BorderSide(color: ShowcasePalette.border(context)),
          right: BorderSide(color: ShowcasePalette.border(context)),
          bottom: BorderSide(color: ShowcasePalette.border(context)),
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: ProjectRow(
          item: item,
          selected: false,
          showDivider: false,
          onTap: onTap,
        ),
      ),
    );
  }
}
