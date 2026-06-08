import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/habits_location.dart';
import 'package:lotti/features/habits/ui/habits_page.dart';
import '../../mocks/mocks.dart';

void main() {
  group('HabitsLocation', () {
    late MockBuildContext mockBuildContext;

    setUp(() {
      mockBuildContext = MockBuildContext();
    });

    test('pathPatterns are correct', () {
      final location = HabitsLocation(
        RouteInformation(uri: Uri.parse('/habits')),
      );
      expect(location.pathPatterns, ['/habits']);
    });

    test('buildPages builds HabitsTabPage', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/habits'));
      final location = HabitsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 1);
      expect(pages[0].key, const ValueKey('habits'));
      expect(pages[0].title, 'Habits');
      expect(pages[0].child, isA<HabitsTabPage>());
    });

    test('buildPages ignores unknown sub-paths and still returns only the '
        'habits root page', () {
      // `buildPages` is state-independent: it always emits the single root
      // page regardless of trailing segments, so an unknown sub-path must not
      // push an extra page onto the stack.
      final routeInformation = RouteInformation(
        uri: Uri.parse('/habits/unknown'),
      );
      final location = HabitsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 1);
      expect(pages.single.key, const ValueKey('habits'));
      expect(pages.single.child, isA<HabitsTabPage>());
    });
  });
}
