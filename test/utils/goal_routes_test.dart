import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/goal_routes.dart';

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
  });
}
