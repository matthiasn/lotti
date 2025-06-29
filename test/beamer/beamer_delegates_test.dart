import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/beamer/locations/calendar_location.dart';
import 'package:lotti/beamer/locations/dashboards_location.dart';
import 'package:lotti/beamer/locations/habits_location.dart';
import 'package:lotti/beamer/locations/journal_location.dart';
import 'package:lotti/beamer/locations/settings_location.dart';
import 'package:lotti/beamer/locations/tasks_location.dart';

void main() {
  group('BeamerDelegates', () {
    test('habitsBeamerDelegate returns HabitsLocation', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/habits'));
      final location =
          habitsBeamerDelegate.locationBuilder(routeInformation, null);
      expect(location, isA<HabitsLocation>());
    });

    test('dashboardsBeamerDelegate returns DashboardsLocation', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/dashboards'));
      final location =
          dashboardsBeamerDelegate.locationBuilder(routeInformation, null);
      expect(location, isA<DashboardsLocation>());
    });

    test('journalBeamerDelegate returns JournalLocation', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/journal'));
      final location =
          journalBeamerDelegate.locationBuilder(routeInformation, null);
      expect(location, isA<JournalLocation>());
    });

    test('tasksBeamerDelegate returns TasksLocation', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/tasks'));
      final location =
          tasksBeamerDelegate.locationBuilder(routeInformation, null);
      expect(location, isA<TasksLocation>());
    });

    test('calendarBeamerDelegate returns CalendarLocation', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/calendar'));
      final location =
          calendarBeamerDelegate.locationBuilder(routeInformation, null);
      expect(location, isA<CalendarLocation>());
    });

    test('settingsBeamerDelegate returns SettingsLocation', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/settings'));
      final location =
          settingsBeamerDelegate.locationBuilder(routeInformation, null);
      expect(location, isA<SettingsLocation>());
    });

    test('returns NotFound for unknown routes', () {
      final routeInformation = RouteInformation(uri: Uri.parse('/unknown'));
      final habitsLocation =
          habitsBeamerDelegate.locationBuilder(routeInformation, null);
      final dashboardsLocation =
          dashboardsBeamerDelegate.locationBuilder(routeInformation, null);
      final journalLocation =
          journalBeamerDelegate.locationBuilder(routeInformation, null);
      final tasksLocation =
          tasksBeamerDelegate.locationBuilder(routeInformation, null);
      final calendarLocation =
          calendarBeamerDelegate.locationBuilder(routeInformation, null);
      final settingsLocation =
          settingsBeamerDelegate.locationBuilder(routeInformation, null);

      expect(habitsLocation, isA<NotFound>());
      expect(dashboardsLocation, isA<NotFound>());
      expect(journalLocation, isA<NotFound>());
      expect(tasksLocation, isA<NotFound>());
      expect(calendarLocation, isA<NotFound>());
      expect(settingsLocation, isA<NotFound>());
    });
  });
}
