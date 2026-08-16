import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/goals/ui/goal_routes.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';

import '../../../mocks/mocks.dart';

/// Minimal location echoing any path, so the helpers can be exercised
/// against a real enclosing Beamer at arbitrary routes.
class _EchoLocation extends BeamLocation<BeamState> {
  _EchoLocation(RouteInformation super.routeInformation, this.child);

  final Widget child;

  @override
  List<String> get pathPatterns => ['*'];

  @override
  List<BeamPage> buildPages(BuildContext context, BeamState state) => [
    BeamPage(
      key: ValueKey('echo-${state.uri.path}'),
      child: child,
    ),
  ];
}

void main() {
  /// Pumps [probe] as a page of a real Beamer whose current route is [path]
  /// and returns the context captured inside that page.
  Future<BuildContext> contextAt(WidgetTester tester, String path) async {
    late BuildContext captured;
    final delegate = BeamerDelegate(
      setBrowserTabTitle: false,
      initialPath: path,
      locationBuilder: (routeInformation, _) => _EchoLocation(
        routeInformation,
        Builder(
          builder: (context) {
            captured = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    addTearDown(delegate.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerDelegate: delegate,
        routeInformationParser: BeamerParser(),
        routeInformationProvider: PlatformRouteInformationProvider(
          initialRouteInformation: RouteInformation(uri: Uri.parse(path)),
        ),
      ),
    );
    return captured;
  }

  group('goalSurfaceRootPath', () {
    testWidgets('resolves /goals from the ENCLOSING delegate route — even a '
        'lookalike prefix stays legacy', (tester) async {
      expect(
        goalSurfaceRootPath(await contextAt(tester, '/goals')),
        '/goals',
      );
      expect(
        goalSurfaceRootPath(
          await contextAt(tester, '/goals/details/goal-1/chat'),
        ),
        '/goals',
      );
      // Root-path match, not a string prefix.
      expect(
        goalSurfaceRootPath(await contextAt(tester, '/goalsomething')),
        '/agents',
      );
    });

    testWidgets('defaults to the legacy Agents surface for agents-hosted '
        'routes', (tester) async {
      expect(
        goalSurfaceRootPath(await contextAt(tester, '/agents/details/goal-1')),
        '/agents',
      );
    });

    testWidgets('falls back to /agents without an enclosing Beamer — the '
        'pre-merge behavior widget tests rely on', (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(goalSurfaceRootPath(captured), '/agents');
    });
  });

  testWidgets('the derived paths stay inside the hosting surface', (
    tester,
  ) async {
    final goalsContext = await contextAt(tester, '/goals/details/goal-1');
    expect(goalCreatePath(goalsContext), '/goals/create');
    expect(goalDetailPath(goalsContext, 'goal-1'), '/goals/details/goal-1');
    expect(
      goalChatPath(goalsContext, 'goal-1'),
      '/goals/details/goal-1/chat',
    );
    expect(
      goalEditPath(goalsContext, 'goal-1'),
      '/goals/details/goal-1/edit',
    );

    final agentsContext = await contextAt(tester, '/agents/details/goal-1');
    expect(goalCreatePath(agentsContext), '/agents/create');
    expect(goalDetailPath(agentsContext, 'goal-1'), '/agents/details/goal-1');
    expect(
      goalChatPath(agentsContext, 'goal-1'),
      '/agents/details/goal-1/chat',
    );
    expect(
      goalEditPath(agentsContext, 'goal-1'),
      '/agents/details/goal-1/edit',
    );
  });

  group('goalDetailPathFromShell', () {
    tearDown(() async {
      if (getIt.isRegistered<NavService>()) {
        getIt.unregister<NavService>();
      }
    });

    test('keeps the legacy Agents target while that tab is enabled — and '
        'as the fallback with no NavService at all', () {
      expect(goalDetailPathFromShell('goal-1'), '/agents/details/goal-1');

      final navService = MockNavService()
        ..agentsPageEnabled = true
        ..unifiedGoalsPageEnabled = true;
      getIt.registerSingleton<NavService>(navService);
      expect(goalDetailPathFromShell('goal-1'), '/agents/details/goal-1');
    });

    test('routes to the unified Goals surface when it is the only enabled '
        'goal tab', () {
      final navService = MockNavService()..unifiedGoalsPageEnabled = true;
      getIt.registerSingleton<NavService>(navService);
      expect(goalDetailPathFromShell('goal-1'), '/goals/details/goal-1');
    });
  });
}
