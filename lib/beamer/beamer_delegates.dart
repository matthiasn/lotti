import 'package:beamer/beamer.dart';
import 'package:lotti/beamer/locations/dashboards_location.dart';
import 'package:lotti/beamer/locations/journal_location.dart';
import 'package:lotti/beamer/locations/settings_location.dart';
import 'package:lotti/beamer/locations/tasks_location.dart';

final dashboardsBeamerDelegate = BeamerDelegate(
  initialPath: '/dashboards',
  locationBuilder: (routeInformation, _) {
    if (routeInformation.location!.contains('dashboards')) {
      return DashboardsLocation(routeInformation);
    }
    return NotFound(path: routeInformation.location!);
  },
);

final journalBeamerDelegate = BeamerDelegate(
  initialPath: '/journal',
  locationBuilder: (routeInformation, _) {
    if (routeInformation.location!.contains('journal')) {
      return JournalLocation(routeInformation);
    }
    return NotFound(path: routeInformation.location!);
  },
);

final tasksBeamerDelegate = BeamerDelegate(
  initialPath: '/tasks',
  locationBuilder: (routeInformation, _) {
    if (routeInformation.location!.contains('tasks')) {
      return TasksLocation(routeInformation);
    }
    return NotFound(path: routeInformation.location!);
  },
);

final settingsBeamerDelegate = BeamerDelegate(
  initialPath: '/settings',
  locationBuilder: (routeInformation, _) {
    if (routeInformation.location!.contains('settings')) {
      return SettingsLocation(routeInformation);
    }
    return NotFound(path: routeInformation.location!);
  },
);
