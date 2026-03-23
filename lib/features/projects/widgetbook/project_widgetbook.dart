import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/widgetbook/widgetbook_helpers.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_detail_showcase.dart';
import 'package:widgetbook/widgetbook.dart';

WidgetbookFolder buildProjectsWidgetbookFolder() {
  return WidgetbookFolder(
    name: 'Projects',
    children: [
      buildProjectListDetailWidgetbookComponent(),
    ],
  );
}

WidgetbookComponent buildProjectListDetailWidgetbookComponent() {
  return WidgetbookComponent(
    name: 'Project list & detail',
    useCases: [
      WidgetbookUseCase(
        name: 'Overview',
        builder: (context) => const _ProjectListDetailOverviewPage(),
      ),
    ],
  );
}

class _ProjectListDetailOverviewPage extends StatelessWidget {
  const _ProjectListDetailOverviewPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: const [
          WidgetbookViewport(
            width: 1440,
            child: ProviderScope(
              child: ProjectListDetailShowcase(),
            ),
          ),
        ],
      ),
    );
  }
}
