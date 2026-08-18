import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/goals_location.dart';
import 'package:lotti/features/goals/ui/pages/create_goal_agent_page.dart';
import 'package:lotti/features/goals/ui/pages/goal_agent_chat_page.dart';
import 'package:lotti/features/goals/ui/pages/goal_agent_detail_page.dart';
import 'package:lotti/features/goals/ui/pages/unified_goals_page.dart';

import '../../widget_test_utils.dart';

void main() {
  group('GoalsLocation', () {
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
      final location = GoalsLocation(routeInformation);
      final state = BeamState.fromRouteInformation(routeInformation);
      return location.buildPages(
        captured,
        state.copyWith(pathParameters: {...state.pathParameters, ...params}),
      );
    }

    test('pathPatterns cover list, create, detail, edit, chat and timeline', () {
      final location = GoalsLocation(
        RouteInformation(uri: Uri.parse('/goals')),
      );
      expect(location.pathPatterns, [
        '/goals',
        '/goals/create',
        '/goals/details/:agentId',
        '/goals/details/:agentId/edit',
        '/goals/details/:agentId/chat',
        '/goals/details/:agentId/timeline',
      ]);
    });

    testWidgets('the root path builds only the list page, localized', (
      tester,
    ) async {
      final pages = await pagesFor(tester, '/goals');
      expect(pages.length, 1);
      expect(pages.single.key, const ValueKey('goals'));
      expect(pages.single.title, 'Goals');
      expect(pages.single.child, isA<UnifiedGoalsPage>());
    });

    testWidgets('an unknown sub-path still renders only the goals root '
        'page', (tester) async {
      // Anything malformed renders the plain list, mirroring the agents tab.
      final pages = await pagesFor(tester, '/goals/unknown');
      expect(pages.length, 1);
      expect(pages.single.key, const ValueKey('goals'));
      expect(pages.single.child, isA<UnifiedGoalsPage>());
    });

    testWidgets('hosts the creation wizard under /goals/create', (
      tester,
    ) async {
      // The tab's primary actions must work — and Back must return here —
      // even when the independent agents flag is off.
      final pages = await pagesFor(tester, '/goals/create');
      expect(pages.length, 2);
      expect(pages.last.key, const ValueKey('goals-create'));
      expect(pages.last.child, isA<CreateGoalAgentPage>());
    });

    testWidgets('hosts the goal detail, chat and edit pages under '
        '/goals/details', (tester) async {
      final detail = await pagesFor(
        tester,
        '/goals/details/goal-1',
        {'agentId': 'goal-1'},
      );
      expect(detail.length, 2);
      expect(detail.last.key, const ValueKey('goals-details-goal-1'));
      expect(detail.last.child, isA<GoalAgentDetailPage>());

      final chat = await pagesFor(
        tester,
        '/goals/details/goal-1/chat',
        {'agentId': 'goal-1'},
      );
      expect(chat.length, 3);
      expect(chat.last.key, const ValueKey('goals-details-goal-1-chat'));
      expect(chat.last.child, isA<GoalAgentChatPage>());

      final edit = await pagesFor(
        tester,
        '/goals/details/goal-1/edit',
        {'agentId': 'goal-1'},
      );
      expect(edit.length, 3);
      expect(edit.last.key, const ValueKey('goals-details-goal-1-edit'));
      final editPage = edit.last.child as CreateGoalAgentPage;
      expect(editPage.agentId, 'goal-1');
    });
  });
}
