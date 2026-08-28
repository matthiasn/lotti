import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/habits_location.dart';
import 'package:lotti/features/habits/ui/habits_page.dart';
import 'package:lotti/features/habits/ui/pages/habit_editor_page.dart';

import '../../mocks/mocks.dart';

void main() {
  group('HabitsLocation', () {
    late MockBuildContext mockBuildContext;

    setUp(() {
      mockBuildContext = MockBuildContext();
    });

    List<BeamPage> pagesFor(String path, {Map<String, String>? params}) {
      final routeInformation = RouteInformation(uri: Uri.parse(path));
      final location = HabitsLocation(routeInformation);
      var beamState = BeamState.fromRouteInformation(routeInformation);
      if (params != null) {
        beamState = beamState.copyWith(pathParameters: params);
      }
      return location.buildPages(mockBuildContext, beamState);
    }

    test('pathPatterns cover the tab, create and edit', () {
      final location = HabitsLocation(
        RouteInformation(uri: Uri.parse('/habits')),
      );
      expect(location.pathPatterns, [
        '/habits',
        '/habits/create',
        '/habits/edit/:habitId',
      ]);
    });

    test('the root builds only the tab page', () {
      final pages = pagesFor('/habits');
      expect(pages.length, 1);
      expect(pages[0].key, const ValueKey('habits'));
      expect(pages[0].title, 'Habits');
      expect(pages[0].child, isA<HabitsTabPage>());
    });

    test('create stacks the editor in create mode over the tab', () {
      final pages = pagesFor('/habits/create');
      expect(pages.length, 2);
      final editor = pages[1].child as HabitEditorPage;
      expect(editor.isCreate, isTrue);
      expect(editor.habitId, isNull);
      expect(editor.returnPath, '/habits');
      expect(pages[1].popToNamed, '/habits');
    });

    test('edit stacks the editor for the habit over the tab', () {
      final pages = pagesFor(
        '/habits/edit/habit-7',
        params: {'habitId': 'habit-7'},
      );
      expect(pages.length, 2);
      expect(pages[1].key, const ValueKey('habits-edit-habit-7'));
      final editor = pages[1].child as HabitEditorPage;
      expect(editor.habitId, 'habit-7');
      expect(editor.isCreate, isFalse);
      expect(pages[1].popToNamed, '/habits');
    });

    test('an unknown sub-path still returns only the root page', () {
      final pages = pagesFor('/habits/unknown');
      expect(pages.length, 1);
      expect(pages.single.child, isA<HabitsTabPage>());
    });

    test('editPath and createPath are the routes the location serves', () {
      expect(HabitsLocation.createPath, '/habits/create');
      expect(HabitsLocation.editPath('x'), '/habits/edit/x');
    });
  });
}
