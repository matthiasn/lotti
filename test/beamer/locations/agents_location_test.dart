import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/agents_location.dart';
import 'package:lotti/features/goals/ui/pages/agents_page.dart';
import 'package:lotti/features/goals/ui/pages/create_goal_agent_page.dart';
import 'package:lotti/features/goals/ui/pages/goal_agent_detail_page.dart';

import '../../mocks/mocks.dart';

void main() {
  group('AgentsLocation', () {
    final context = MockBuildContext();

    List<BeamPage> pagesFor(
      String path, [
      Map<String, String> params = const {},
    ]) {
      final routeInformation = RouteInformation(uri: Uri.parse(path));
      final location = AgentsLocation(routeInformation);
      final state = BeamState.fromRouteInformation(routeInformation);
      return location.buildPages(
        context,
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

    test('the root path builds only the list page', () {
      final pages = pagesFor('/agents');
      expect(pages, hasLength(1));
      expect(pages.single.child, isA<AgentsPage>());
    });

    test('/agents/create stacks the creation page on the list', () {
      final pages = pagesFor('/agents/create');
      expect(pages, hasLength(2));
      expect(pages.last.child, isA<CreateGoalAgentPage>());
    });

    test('a detail path stacks the detail page carrying the agent id', () {
      final pages = pagesFor('/agents/details/goal-1', {'agentId': 'goal-1'});
      expect(pages, hasLength(2));
      final detail = pages.last.child as GoalAgentDetailPage;
      expect(detail.agentId, 'goal-1');
    });
  });
}
