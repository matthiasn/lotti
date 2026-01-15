import 'package:beamer/beamer.dart';
import 'package:lotti/beamer/locations/calendar_location.dart';
import 'package:lotti/beamer/locations/daily_os_location.dart';
import 'package:lotti/beamer/locations/dashboards_location.dart';
import 'package:lotti/beamer/locations/habits_location.dart';
import 'package:lotti/beamer/locations/journal_location.dart';
import 'package:lotti/beamer/locations/settings_location.dart';
import 'package:lotti/beamer/locations/tasks_location.dart';

final habitsBeamerDelegate = BeamerDelegate(
  initialPath: '/habits',
  updateParent: false,
  updateFromParent: false,
  locationBuilder: (routeInformation, _) {
    if (routeInformation.uri.path.contains('habits')) {
      return HabitsLocation(routeInformation);
    }
    return NotFound(path: routeInformation.uri.path);
  },
);

final dashboardsBeamerDelegate = BeamerDelegate(
  initialPath: '/dashboards',
  updateParent: false,
  updateFromParent: false,
  locationBuilder: (routeInformation, _) {
    if (routeInformation.uri.path.contains('dashboards')) {
      return DashboardsLocation(routeInformation);
    }
    return NotFound(path: routeInformation.uri.path);
  },
);

final journalBeamerDelegate = BeamerDelegate(
  initialPath: '/journal',
  updateParent: false,
  updateFromParent: false,
  locationBuilder: (routeInformation, _) {
    if (routeInformation.uri.path.contains('journal')) {
      return JournalLocation(routeInformation);
    }
    return NotFound(path: routeInformation.uri.path);
  },
);

final tasksBeamerDelegate = BeamerDelegate(
  initialPath: '/tasks',
  updateParent: false,
  updateFromParent: false,
  locationBuilder: (routeInformation, _) {
    if (routeInformation.uri.path.contains('tasks')) {
      return TasksLocation(routeInformation);
    }
    return NotFound(path: routeInformation.uri.path);
  },
);

final calendarBeamerDelegate = BeamerDelegate(
  initialPath: '/calendar',
  updateParent: false,
  updateFromParent: false,
  locationBuilder: (routeInformation, _) {
    if (routeInformation.uri.path.contains('calendar')) {
      return CalendarLocation(routeInformation);
    }
    return NotFound(path: routeInformation.uri.path);
  },
);

final settingsBeamerDelegate = BeamerDelegate(
  initialPath: '/settings',
  updateParent: false,
  updateFromParent: false,
  locationBuilder: (routeInformation, _) {
    if (routeInformation.uri.path.contains('settings')) {
      return SettingsLocation(routeInformation);
    }
    return NotFound(path: routeInformation.uri.path);
  },
);

final dailyOsBeamerDelegate = BeamerDelegate(
  initialPath: '/daily-os',
  updateParent: false,
  updateFromParent: false,
  locationBuilder: (routeInformation, _) {
    if (routeInformation.uri.path.contains('daily-os')) {
      return DailyOsLocation(routeInformation);
    }
    return NotFound(path: routeInformation.uri.path);
  },
);
