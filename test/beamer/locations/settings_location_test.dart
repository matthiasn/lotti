import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/locations/settings_location.dart';
import 'package:lotti/features/settings/ui/pages/settings_page.dart';
import 'package:lotti/features/settings/ui/pages/tags/tags_page.dart';
import 'package:mocktail/mocktail.dart';

class MockBuildContext extends Mock implements BuildContext {}

void main() {
  group('SettingsLocation', () {
    late MockBuildContext mockBuildContext;

    setUp(() {
      mockBuildContext = MockBuildContext();
    });

    test('pathPatterns are correct', () {
      final location =
          SettingsLocation(RouteInformation(uri: Uri.parse('/settings')));
      expect(location.pathPatterns, [
        '/settings',
        '/settings/ai',
        '/settings/tags',
        '/settings/tags/:tagEntityId',
        '/settings/tags/create/:tagType',
        '/settings/categories',
        '/settings/categories/:categoryId',
        '/settings/categories/create',
        '/settings/categories2',
        '/settings/categories2/create',
        '/settings/categories2/:categoryId',
        '/settings/dashboards',
        '/settings/dashboards/:dashboardId',
        '/settings/dashboards/create',
        '/settings/measurables',
        '/settings/measurables/:measurableId',
        '/settings/measurables/create',
        '/settings/habits',
        '/settings/habits/by_id/:habitId',
        '/settings/habits/create',
        '/settings/habits/search/:searchTerm',
        '/settings/flags',
        '/settings/theming',
        '/settings/advanced',
        '/settings/outbox_monitor',
        '/settings/logging',
        '/settings/advanced/logging/:logEntryId',
        '/settings/advanced/conflicts/:conflictId',
        '/settings/advanced/conflicts/:conflictId/edit',
        '/settings/advanced/conflicts',
        '/settings/maintenance',
      ]);
    });

    test('buildPages builds SettingsPage', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/settings'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 1);
      expect(pages[0].key, isA<ValueKey<String>>());
      expect(pages[0].child, isA<SettingsPage>());
    });

    test('buildPages builds TagsPage', () {
      final routeInformation =
          RouteInformation(uri: Uri.parse('/settings/tags'));
      final location = SettingsLocation(routeInformation);
      final beamState = BeamState.fromRouteInformation(routeInformation);
      final pages = location.buildPages(
        mockBuildContext,
        beamState,
      );
      expect(pages.length, 2);
      expect(pages[0].key, isA<ValueKey<String>>());
      expect(pages[0].child, isA<SettingsPage>());
      expect(pages[1].key, isA<ValueKey<String>>());
      expect(pages[1].child, isA<TagsPage>());
    });
  });
}
