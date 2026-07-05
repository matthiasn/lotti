import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/impact_analysis_body.dart';
import 'package:lotti/features/ai_consumption/ui/impact_analysis_page.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/insights/ui/widgets/insights_surfaces.dart';
import 'package:lotti/utils/device_region.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  testWidgets('hosts the shared dashboard body on the insights page surface', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1280, 1100)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repository = MockConsumptionRepository();
    when(
      () => repository.metricRowsInRange(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => repository.newestEventsInRange(
        start: any(named: 'start'),
        end: any(named: 'end'),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const ImpactAnalysisPage(),
        overrides: [
          consumptionRepositoryProvider.overrideWithValue(repository),
          consumptionRefetchThrottleProvider.overrideWithValue(null),
          maybeUpdateNotificationsProvider.overrideWith((ref) => null),
          categoriesStreamProvider.overrideWith((ref) => Stream.value([])),
          firstDayOfWeekIndexProvider.overrideWith(
            (ref) => DateTime.monday % 7,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    // The route host is a thin shell: page-surface Scaffold + SafeArea around
    // the same body the Settings panel embeds.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(
      scaffold.backgroundColor,
      insightsPageSurface(tester.element(find.byType(ImpactAnalysisPage))),
    );
    expect(
      find.descendant(
        of: find.byType(SafeArea),
        matching: find.byType(ImpactAnalysisBody),
      ),
      findsOneWidget,
    );
  });
}
