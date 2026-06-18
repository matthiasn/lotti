/// Throwaway capture of the in-app knowledge-graph PAGE (ADR 0029 Phase 1) —
/// the real `TaskKnowledgeGraphPage` with its Scaffold + AppBar, rendered
/// through the real provider path (overridden with a representative task graph
/// + authentic category hex colors). Shows the integration in full app
/// scaffold. Run:
///   fvm flutter test \
///     test/features/knowledge_graph_poc/ui/task_knowledge_graph_page_screenshots_test.dart \
///     --update-goldens
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/category_color.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_models.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_scenarios.dart';
import 'package:lotti/features/knowledge_graph_poc/state/task_graph_provider.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/task_knowledge_graph_page.dart';

import '../../../test_utils/screenshot_harness.dart';
import '../../../widget_test_utils.dart';

void main() {
  setUpAll(loadAppFonts);
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  // Authentic category colors (the dev DB's "Lotti" category is #4285F4).
  final categoryColors = {
    catWork: categoryColorFromHex('#4285F4'),
    catWriting: categoryColorFromHex('#E37400'),
    catHealth: categoryColorFromHex('#34A853'),
    catLearning: categoryColorFromHex('#A142F4'),
    catHome: categoryColorFromHex('#F4B400'),
    catAdmin: categoryColorFromHex('#5F6368'),
  };

  // Real category display names (the dev DB's category is "Lotti").
  final categoryNames = {
    catWork: 'Lotti',
    catWriting: 'Docs',
    catHealth: 'Health',
    catLearning: 'Learning',
    catHome: 'Home',
    catAdmin: 'Admin',
  };

  TaskGraphData data(GraphScenario scenario) => TaskGraphData(
    scenario: scenario,
    categoryColors: categoryColors,
    categoryNames: categoryNames,
  );

  testWidgets('task graph page — desktop dark', (tester) async {
    await captureInApp(
      tester,
      child: const TaskKnowledgeGraphPage(taskId: 'demo'),
      name: 'integration_task_graph_desktop_dark',
      size: ScreenshotViewport.desktop,
      overrides: [
        taskGraphProvider(
          'demo',
        ).overrideWith((ref) async => data(taskEgoNetworkScenario())),
      ],
    );
  });

  testWidgets('task graph page — phone dark', (tester) async {
    await captureInApp(
      tester,
      child: const TaskKnowledgeGraphPage(taskId: 'demo'),
      name: 'integration_task_graph_phone_dark',
      overrides: [
        taskGraphProvider(
          'demo',
        ).overrideWith((ref) async => data(taskEgoNetworkScenario())),
      ],
    );
  });

  testWidgets('task graph page — empty state, desktop', (tester) async {
    await captureInApp(
      tester,
      child: const TaskKnowledgeGraphPage(taskId: 'demo'),
      name: 'integration_task_graph_empty_desktop_dark',
      size: ScreenshotViewport.desktop,
      overrides: [
        taskGraphProvider('demo').overrideWith((ref) async => null),
      ],
    );
  });
}
