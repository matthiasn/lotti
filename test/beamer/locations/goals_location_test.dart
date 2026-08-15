import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/goals_location.dart';
import 'package:lotti/features/goals/ui/pages/unified_goals_page.dart';
import '../../mocks/mocks.dart';

void main() {
  group('GoalsLocation', () {
    late MockBuildContext mockBuildContext;

    setUp(() {
      mockBuildContext = MockBuildContext();
    });

    test('pathPatterns are correct', () {
      final location = GoalsLocation(
        RouteInformation(uri: Uri.parse('/goals')),
      );
      expect(location.pathPatterns, ['/goals']);
    });

    test('buildPages builds UnifiedGoalsPage', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/goals'));
      final location = GoalsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 1);
      expect(pages[0].key, const ValueKey('goals'));
      expect(pages[0].title, 'Goals');
      expect(pages[0].child, isA<UnifiedGoalsPage>());
    });

    test('buildPages ignores unknown sub-paths and still returns only the '
        'goals root page', () {
      // `buildPages` is state-independent: it always emits the single root
      // page regardless of trailing segments, so an unknown sub-path must not
      // push an extra page onto the stack.
      final routeInformation = RouteInformation(
        uri: Uri.parse('/goals/unknown'),
      );
      final location = GoalsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 1);
      expect(pages.single.key, const ValueKey('goals'));
      expect(pages.single.child, isA<UnifiedGoalsPage>());
    });
  });
}
