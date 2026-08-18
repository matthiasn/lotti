import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/ui/goal_routes.dart';

void main() {
  group('goal routes', () {
    test('every goal route hangs off the goals root', () {
      // The shell persists the current path; a route that escaped /goals
      // would restore into a different tab.
      expect(goalDetailPath('g1'), startsWith(goalsRootPath));
      expect(goalChatPath('g1'), startsWith(goalDetailPath('g1')));
      expect(goalEditPath('g1'), startsWith(goalDetailPath('g1')));
      expect(goalTimelinePath('g1'), startsWith(goalDetailPath('g1')));
      expect(goalCreatePath, startsWith(goalsRootPath));
    });

    test('the sub-routes are distinct from one another', () {
      final paths = {
        goalDetailPath('g1'),
        goalChatPath('g1'),
        goalEditPath('g1'),
        goalTimelinePath('g1'),
      };
      expect(paths, hasLength(4));
    });

    test('the rail is dropped before it can squeeze the dashboard', () {
      // The rail only earns its width when the dashboard still has a usable
      // measure beside it.
      expect(kGoalTimelineRailWidth, greaterThan(0));
      expect(kGoalTimelineRailFoldWidth, greaterThan(kGoalTimelineRailWidth));
    });
  });
}
