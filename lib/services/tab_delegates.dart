import 'package:beamer/beamer.dart';

/// The navigator behind each tab of the app shell.
///
/// The shell builds them, since each one routes into the feature pages it
/// hosts, and hands them to `NavService` through this value, so
/// the navigation state in `lib/services` never imports the shell.
final class TabDelegates {
  const TabDelegates({
    required this.tasks,
    required this.projects,
    required this.calendar,
    required this.habits,
    required this.goals,
    required this.dashboards,
    required this.journal,
    required this.events,
    required this.relationships,
    required this.settings,
  });

  final BeamerDelegate tasks;
  final BeamerDelegate projects;
  final BeamerDelegate calendar;
  final BeamerDelegate habits;
  final BeamerDelegate goals;
  final BeamerDelegate dashboards;
  final BeamerDelegate journal;
  final BeamerDelegate events;
  final BeamerDelegate relationships;
  final BeamerDelegate settings;
}
