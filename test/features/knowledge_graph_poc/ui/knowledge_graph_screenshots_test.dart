/// Throwaway screenshot capture for the knowledge-graph POC (ADR 0029).
///
/// Not a golden test — emits PNGs for the expert panel to review. Run:
///   fvm flutter test \
///     test/features/knowledge_graph_poc/ui/knowledge_graph_screenshots_test.dart \
///     --update-goldens
/// PNGs land in test/features/knowledge_graph_poc/ui/screenshots/ (gitignored).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/knowledge_graph_poc/domain/graph_scenarios.dart';
import 'package:lotti/features/knowledge_graph_poc/ui/knowledge_graph_view.dart';

import '../../../test_utils/screenshot_harness.dart';
import '../../../widget_test_utils.dart';

void main() {
  setUpAll(loadAppFonts);
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  // Explorable world — initial focus, with the inspector (desktop).
  testWidgets('explore world — desktop dark', (tester) async {
    await captureInApp(
      tester,
      child: KnowledgeGraphView(scenario: exploreWorldScenario()),
      name: 'explore_world_desktop_dark',
      size: ScreenshotViewport.desktop,
    );
  });

  // Same world after "walking" across to a node deep in another cluster —
  // shows the trail back to where we came from, the previous-focus ghost, and
  // the Back/Recenter controls.
  testWidgets('explore world — walked, desktop dark', (tester) async {
    await captureInApp(
      tester,
      child: KnowledgeGraphView(
        scenario: exploreWorldScenario(),
        initialFocusId: 'P2T2',
        initialPreviousFocusId: 'P2',
      ),
      name: 'explore_world_walked_desktop_dark',
      size: ScreenshotViewport.desktop,
    );
  });

  testWidgets('explore world — phone dark', (tester) async {
    await captureInApp(
      tester,
      child: KnowledgeGraphView(scenario: exploreWorldScenario()),
      name: 'explore_world_phone_dark',
    );
  });

  // Task ego-network, now with the inspector.
  testWidgets('task ego-network — desktop dark', (tester) async {
    await captureInApp(
      tester,
      child: KnowledgeGraphView(scenario: taskEgoNetworkScenario()),
      name: 'task_ego_desktop_dark',
      size: ScreenshotViewport.desktop,
    );
  });

  testWidgets('task ego-network — phone dark', (tester) async {
    await captureInApp(
      tester,
      child: KnowledgeGraphView(scenario: taskEgoNetworkScenario()),
      name: 'task_ego_phone_dark',
    );
  });
}
