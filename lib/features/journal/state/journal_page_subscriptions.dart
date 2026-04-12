import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/journal/utils/entry_type_gating.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/platform.dart';
import 'package:rxdart/rxdart.dart';

/// Callback record for config-flag changes.
typedef JournalConfigFlags = ({
  bool events,
  bool habits,
  bool dashboards,
  bool vectorSearch,
  bool projects,
});

/// Manages the reactive stream subscriptions for the journal page controller,
/// keeping the subscription wiring out of the controller class.
class JournalPageSubscriptions {
  JournalPageSubscriptions({
    required JournalDb db,
    required UpdateNotifications updateNotifications,
  }) : _db = db,
       _updateNotifications = updateNotifications;

  final JournalDb _db;
  final UpdateNotifications _updateNotifications;

  StreamSubscription<JournalConfigFlags>? _configFlagsSub;
  StreamSubscription<bool>? _privateFlagSub;
  StreamSubscription<Set<String>>? _updatesSub;

  /// Starts listening to config flags, the private-entries flag, and
  /// update notifications.
  ///
  /// [onPrivateFlagChanged] is called when the show-private toggle changes.
  /// [onJournalConfigFlagsChanged] is called when any feature flag changes.
  /// [onUpdateNotification] is called with affected IDs when entities change.
  void setup({
    required bool showTasks,
    // ignore: avoid_positional_boolean_parameters
    required void Function(bool showPrivate) onPrivateFlagChanged,
    required void Function(JournalConfigFlags flags)
    onJournalConfigFlagsChanged,
    required Future<void> Function(Set<String> affectedIds)
    onUpdateNotification,
  }) {
    _privateFlagSub = _db
        .watchConfigFlag('private')
        .listen(
          onPrivateFlagChanged,
        );

    _configFlagsSub =
        Rx.combineLatest5<bool, bool, bool, bool, bool, JournalConfigFlags>(
          _db.watchConfigFlag(enableEventsFlag),
          _db.watchConfigFlag(enableHabitsPageFlag),
          _db.watchConfigFlag(enableDashboardsPageFlag),
          _db.watchConfigFlag(enableVectorSearchFlag),
          _db.watchConfigFlag(enableProjectsFlag),
          (events, habits, dashboards, vectorSearch, projects) => (
            events: events,
            habits: habits,
            dashboards: dashboards,
            vectorSearch: vectorSearch,
            projects: projects,
          ),
        ).listen(onJournalConfigFlagsChanged);

    _updatesSub = _updateNotifications.updateStream.listen(
      onUpdateNotification,
    );
  }

  void dispose() {
    _configFlagsSub?.cancel();
    _privateFlagSub?.cancel();
    _updatesSub?.cancel();
  }

  /// Applies config-flag changes, updating the mutable fields and returning
  /// actions the controller should take.
  ///
  /// This is a pure helper — it reads the previous state, computes the new
  /// state, and returns a result record. The controller applies the mutations.
  static ConfigFlagResult applyJournalConfigFlags({
    required JournalConfigFlags flags,
    required bool showTasks,
    required bool enableEvents,
    required bool enableHabits,
    required bool enableDashboards,
    required bool enableVectorSearch,
    required bool enableProjects,
    required SearchMode searchMode,
    required bool hasExplicitSearchModeSelection,
    required Set<String> selectedEntryTypes,
    required Set<String> selectedProjectIds,
  }) {
    final oldAllowed = computeAllowedEntryTypes(
      events: enableEvents,
      habits: enableHabits,
      dashboards: enableDashboards,
    ).toSet();

    var newSearchMode = searchMode;
    var shouldRefresh = false;
    var newProjectIds = selectedProjectIds;

    if (showTasks &&
        isDesktop &&
        flags.vectorSearch &&
        !hasExplicitSearchModeSelection &&
        searchMode != SearchMode.vector) {
      newSearchMode = SearchMode.vector;
      shouldRefresh = true;
    } else if (!flags.vectorSearch && searchMode == SearchMode.vector) {
      newSearchMode = SearchMode.fullText;
      shouldRefresh = true;
    }
    if (!flags.projects && selectedProjectIds.isNotEmpty) {
      newProjectIds = {};
      shouldRefresh = true;
    }

    final newAllowed = computeAllowedEntryTypes(
      events: flags.events,
      habits: flags.habits,
      dashboards: flags.dashboards,
    ).toSet();

    final hadAllPreviouslySelected =
        oldAllowed.isNotEmpty && setEquals(selectedEntryTypes, oldAllowed);

    Set<String> newEntryTypes;
    if (selectedEntryTypes.isEmpty || hadAllPreviouslySelected) {
      newEntryTypes = newAllowed;
    } else {
      newEntryTypes = selectedEntryTypes.intersection(newAllowed);
    }

    final entryTypesChanged = !setEquals(selectedEntryTypes, newEntryTypes);

    return ConfigFlagResult(
      enableEvents: flags.events,
      enableHabits: flags.habits,
      enableDashboards: flags.dashboards,
      enableVectorSearch: flags.vectorSearch,
      enableProjects: flags.projects,
      searchMode: newSearchMode,
      selectedEntryTypes: newEntryTypes,
      selectedProjectIds: newProjectIds,
      shouldRefresh: shouldRefresh,
      entryTypesChanged: entryTypesChanged,
    );
  }
}

/// Result of applying config-flag changes.
class ConfigFlagResult {
  const ConfigFlagResult({
    required this.enableEvents,
    required this.enableHabits,
    required this.enableDashboards,
    required this.enableVectorSearch,
    required this.enableProjects,
    required this.searchMode,
    required this.selectedEntryTypes,
    required this.selectedProjectIds,
    required this.shouldRefresh,
    required this.entryTypesChanged,
  });

  final bool enableEvents;
  final bool enableHabits;
  final bool enableDashboards;
  final bool enableVectorSearch;
  final bool enableProjects;
  final SearchMode searchMode;
  final Set<String> selectedEntryTypes;
  final Set<String> selectedProjectIds;
  final bool shouldRefresh;
  final bool entryTypesChanged;
}
