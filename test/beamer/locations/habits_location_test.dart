import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/habits_location.dart';
import 'package:lotti/blocs/habits/habits_cubit.dart';
import 'package:lotti/features/habits/ui/habits_page.dart';
import 'package:mocktail/mocktail.dart';

class MockBuildContext extends Mock implements BuildContext {}

void main() {
  group('HabitsLocation', () {
    late MockBuildContext mockBuildContext;

    setUp(() {
      mockBuildContext = MockBuildContext();
    });

    test('pathPatterns are correct', () {
      final location =
          HabitsLocation(RouteInformation(uri: Uri.parse('/habits')));
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
      expect(pages[0].key, isA<ValueKey<String>>());
      expect(pages[0].child, isA<BlocProvider<HabitsCubit>>());
      final blocProvider = pages[0].child as BlocProvider<HabitsCubit>;
      expect(blocProvider.child, isA<HabitsTabPage>());
    });
  });
}
