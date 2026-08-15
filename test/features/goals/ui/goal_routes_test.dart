import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/ui/goal_routes.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockNavService mockNavService;

  setUp(() {
    mockNavService = MockNavService();
    getIt.registerSingleton<NavService>(mockNavService);
  });

  tearDown(getIt.reset);

  void setCurrentPath(String path) =>
      when(() => mockNavService.currentPath).thenReturn(path);

  group('goalSurfaceRootPath', () {
    test('defaults to the legacy Agents surface', () {
      // '/tasks', a settings page, the agents tab itself — anything not
      // under /goals keeps the pre-merge behavior.
      for (final path in ['/tasks', '/agents/details/goal-1', '/settings']) {
        setCurrentPath(path);
        expect(goalSurfaceRootPath(), '/agents', reason: path);
      }
    });

    test('resolves to /goals on the unified surface, without matching '
        'lookalike prefixes', () {
      setCurrentPath('/goals');
      expect(goalSurfaceRootPath(), '/goals');
      setCurrentPath('/goals/details/goal-1/chat');
      expect(goalSurfaceRootPath(), '/goals');
      // Root-path match, not a string prefix: a hypothetical sibling route
      // must not be claimed.
      setCurrentPath('/goalsomething');
      expect(goalSurfaceRootPath(), '/agents');
    });
  });

  test('the derived paths stay inside the current surface', () {
    setCurrentPath('/goals/details/goal-1');
    expect(goalCreatePath(), '/goals/create');
    expect(goalDetailPath('goal-1'), '/goals/details/goal-1');
    expect(goalChatPath('goal-1'), '/goals/details/goal-1/chat');
    expect(goalEditPath('goal-1'), '/goals/details/goal-1/edit');

    setCurrentPath('/agents/details/goal-1');
    expect(goalCreatePath(), '/agents/create');
    expect(goalDetailPath('goal-1'), '/agents/details/goal-1');
    expect(goalChatPath('goal-1'), '/agents/details/goal-1/chat');
    expect(goalEditPath('goal-1'), '/agents/details/goal-1/edit');
  });

  test('falls back to /agents when no NavService is registered — the '
      'pre-merge behavior widget tests rely on', () async {
    await getIt.reset();
    expect(goalSurfaceRootPath(), '/agents');
  });
}
