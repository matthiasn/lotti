import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/widgetbook/widgetbook_helpers.dart';
import 'package:lotti/features/projects/ui/widgets/project_list_detail_showcase.dart';
import 'package:lotti/features/projects/ui/widgets/project_mobile_list_detail_showcase.dart';
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
        name: 'Desktop',
        builder: (context) => const _ProjectListDetailOverviewPage(),
      ),
      WidgetbookUseCase(
        name: 'Mobile',
        builder: (context) => const _ProjectListDetailMobilePage(),
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

class _ProjectListDetailMobilePage extends StatelessWidget {
  const _ProjectListDetailMobilePage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: ListView(
        children: const [
          WidgetbookViewport(
            width: 860,
            child: ProviderScope(
              child: Center(
                child: ProjectMobileListDetailShowcase(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
