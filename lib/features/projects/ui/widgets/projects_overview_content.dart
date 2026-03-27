import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/features/projects/ui/widgets/projects_header.dart';
import 'package:lotti/features/projects/ui/widgets/projects_overview_list.dart';
import 'package:lotti/features/projects/ui/widgets/shared_widgets.dart';

class ProjectsOverviewContent extends StatefulWidget {
  const ProjectsOverviewContent({
    required this.title,
    required this.groups,
    required this.onProjectTap,
    this.query = '',
    this.searchEnabled = true,
    this.selectedProjectId,
    this.onSearchChanged,
    this.onSearchCleared,
    this.onSearchPressed,
    this.titleTrailing,
    this.searchTrailing,
    this.scrollController,
    this.headerPadding = const EdgeInsets.only(top: 8),
    this.titleBottomSpacing = 24,
    this.listBottomPadding = 24,
    super.key,
  });

  final String title;
  final List<ProjectCategoryGroup> groups;
  final ValueChanged<ProjectListItemData> onProjectTap;
  final String query;
  final bool searchEnabled;
  final String? selectedProjectId;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onSearchCleared;
  final ValueChanged<String>? onSearchPressed;
  final Widget? titleTrailing;
  final Widget? searchTrailing;
  final ScrollController? scrollController;
  final EdgeInsets headerPadding;
  final double titleBottomSpacing;
  final double listBottomPadding;

  @override
  State<ProjectsOverviewContent> createState() =>
      _ProjectsOverviewContentState();
}

class _ProjectsOverviewContentState extends State<ProjectsOverviewContent> {
  ScrollController? _internalScrollController;

  ScrollController get _effectiveScrollController =>
      widget.scrollController ??
      (_internalScrollController ??= ScrollController());

  @override
  void didUpdateWidget(covariant ProjectsOverviewContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController &&
        widget.scrollController != null) {
      _internalScrollController?.dispose();
      _internalScrollController = null;
    }
  }

  @override
  void dispose() {
    _internalScrollController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scrollController = _effectiveScrollController;

    return DesignSystemScrollbar(
      controller: scrollController,
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: ProjectsOverviewContentWidth(
              child: ProjectsHeader(
                title: widget.title,
                query: widget.query,
                searchEnabled: widget.searchEnabled,
                onSearchChanged: widget.onSearchChanged,
                onSearchCleared: widget.onSearchCleared,
                onSearchPressed: widget.onSearchPressed,
                titleTrailing: widget.titleTrailing,
                searchTrailing: widget.searchTrailing,
                padding: widget.headerPadding,
                titleBottomSpacing: widget.titleBottomSpacing,
              ),
            ),
          ),
          if (widget.groups.isEmpty)
            SliverPadding(
              padding: EdgeInsets.only(bottom: widget.listBottomPadding),
              sliver: const SliverFillRemaining(
                hasScrollBody: false,
                child: ProjectsOverviewContentWidth(
                  child: NoResultsPane(),
                ),
              ),
            )
          else
            ProjectsOverviewSliverList(
              groups: widget.groups,
              selectedProjectId: widget.selectedProjectId,
              onProjectTap: widget.onProjectTap,
              bottomPadding: widget.listBottomPadding,
            ),
        ],
      ),
    );
  }
}
