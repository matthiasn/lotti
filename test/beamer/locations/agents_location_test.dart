import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/agents_location.dart';
import 'package:lotti/features/goals/ui/pages/agents_page.dart';
import 'package:lotti/features/goals/ui/pages/create_goal_agent_page.dart';
import 'package:lotti/features/goals/ui/pages/goal_agent_detail_page.dart';

import '../../widget_test_utils.dart';

void main() {
  group('AgentsLocation', () {
    Future<List<BeamPage>> pagesFor(
      WidgetTester tester,
      String path, [
      Map<String, String> params = const {},
    ]) async {
      // Titles resolve through localizations, so buildPages needs a real
      // localized context rather than a mock.
      late BuildContext captured;
      await tester.pumpWidget(
        makeTestableWidget(
          Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final routeInformation = RouteInformation(uri: Uri.parse(path));
      final location = AgentsLocation(routeInformation);
      final state = BeamState.fromRouteInformation(routeInformation);
      return location.buildPages(
        captured,
        state.copyWith(pathParameters: {...state.pathParameters, ...params}),
      );
    }

    test('pathPatterns cover list, create and detail', () {
      final location = AgentsLocation(
        RouteInformation(uri: Uri.parse('/agents')),
      );
      expect(location.pathPatterns, [
        '/agents',
        '/agents/create',
        '/agents/details/:agentId',
      ]);
    });

    testWidgets('the root path builds only the list page, localized', (
      tester,
    ) async {
      final pages = await pagesFor(tester, '/agents');
      expect(pages, hasLength(1));
      expect(pages.single.child, isA<AgentsPage>());
      expect(pages.single.title, 'Agents');
    });

    testWidgets('/agents/create stacks the creation page on the list', (
      tester,
    ) async {
      final pages = await pagesFor(tester, '/agents/create');
      expect(pages, hasLength(2));
      expect(pages.last.child, isA<CreateGoalAgentPage>());
      expect(pages.last.title, 'New goal agent');
    });

    testWidgets('a detail path stacks the detail page carrying the agent '
        'id', (tester) async {
      final pages = await pagesFor(tester, '/agents/details/goal-1', {
        'agentId': 'goal-1',
      });
      expect(pages, hasLength(2));
      final detail = pages.last.child as GoalAgentDetailPage;
      expect(detail.agentId, 'goal-1');
    });
  });
}
