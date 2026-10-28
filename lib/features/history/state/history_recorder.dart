import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/features/history/domain/history_entry.dart';
import 'package:lotti/features/history/state/history_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/nav_service.dart';

/// Turns navigation into history: every entity the user brings on screen is
/// handed to [HistoryService.record].
///
/// Two signals mean "now showing an entity":
///
/// - **the active tab's route** — a tab delegate moving while its tab is in
///   front, or a tab coming to the front already standing on a detail route;
/// - **the desktop detail selection** — the wide layout opens a linked task,
///   entry or project in the detail pane without moving the URL, so those
///   selections are watched too. The desktop tasks tab goes **by id
///   only**: `desktopSelectedTaskId` is the task in view, so its route is
///   never read there.
///
/// What neither signal shows — a linked task pushed on the phone's
/// navigator — is reported through [recordVisit].
///
/// A delegate or selection in a tab that is *not* in front is ignored: every
/// tab is mounted at once, and a background tab can move on its own (the
/// logbook's auto-selection) without the user having looked at anything.
class HistoryRecorder {
  HistoryRecorder({
    required NavService navService,
    required this._service,
    required this._logger,
  }) : _nav = navService;

  final NavService _nav;
  final HistoryService _service;
  final DomainLogger _logger;

  final List<VoidCallback> _detach = [];
  StreamSubscription<int>? _indexSubscription;

  /// The tab delegates whose routes can show an entity.
  List<BeamerDelegate> get _entityDelegates => [
    _nav.tasksDelegate,
    _nav.journalDelegate,
    _nav.projectsDelegate,
    _nav.eventsDelegate,
    _nav.relationshipsDelegate,
    _nav.dashboardsDelegate,
    _nav.habitsDelegate,
  ];

  /// The desktop selections, each with the tab it belongs to and the route
  /// that shows the selected entity.
  List<
    ({
      ValueListenable<String?> selection,
      BeamerDelegate tab,
      HistoryTarget Function(String id) target,
    })
  >
  get _desktopSelections => [
    (
      selection: _nav.desktopSelectedTaskId,
      tab: _nav.tasksDelegate,
      target: _taskTarget,
    ),
    (
      selection: _nav.desktopSelectedEntryId,
      tab: _nav.journalDelegate,
      target: (id) => HistoryTarget(
        kind: HistoryEntityKind.entry,
        entityId: id,
        route: '/journal/$id',
      ),
    ),
    (
      selection: _nav.desktopSelectedProjectId,
      tab: _nav.projectsDelegate,
      target: (id) => HistoryTarget(
        kind: HistoryEntityKind.project,
        entityId: id,
        route: '/projects/$id',
      ),
    ),
    (
      selection: _nav.desktopSelectedRelationshipId,
      tab: _nav.relationshipsDelegate,
      target: (id) => HistoryTarget(
        kind: HistoryEntityKind.person,
        entityId: id,
        route: '/people/$id',
      ),
    ),
    (
      selection: _nav.desktopSelectedDashboardId,
      tab: _nav.dashboardsDelegate,
      target: (id) => HistoryTarget(
        kind: HistoryEntityKind.dashboard,
        entityId: id,
        route: '/dashboards/$id',
      ),
    ),
  ];

  /// Starts listening. The tab index stream replays the current tab, so
  /// whatever the app restored onto is recorded straight away.
  void start() {
    if (_indexSubscription != null) return;
    for (final delegate in _entityDelegates) {
      void onRouteChanged() {
        // On desktop the tasks tab is recorded from its selected id alone,
        // which follows the route a microtask later.
        if (_tracksTaskById(delegate)) return;
        if (_isFront(delegate)) _recordShownBy(delegate);
      }

      delegate.addListener(onRouteChanged);
      _detach.add(() => delegate.removeListener(onRouteChanged));
    }
    for (final (:selection, :tab, :target) in _desktopSelections) {
      void onSelectionChanged() {
        final id = selection.value;
        if (id != null && _isFront(tab)) _record(target(id));
      }

      selection.addListener(onSelectionChanged);
      _detach.add(() => selection.removeListener(onSelectionChanged));
    }
    _indexSubscription = _nav.getIndexStream().listen((index) {
      final delegates = _nav.beamerDelegates;
      if (index < 0 || index >= delegates.length) return;
      _recordShownBy(delegates[index]);
    });
  }

  /// Records a visit the navigation service cannot see — a linked task
  /// pushed onto the phone's navigator, which leaves the URL where it was.
  Future<void> recordVisit(HistoryTarget target) => _record(target);

  bool _isFront(BeamerDelegate delegate) =>
      _nav.beamerDelegates.indexOf(delegate) == _nav.index;

  /// Whether [delegate]'s tab is recorded by the id of the task in view
  /// rather than by its route: the desktop tasks tab, whose URL keeps the
  /// task it was opened at while linked tasks replace it in the pane.
  /// `desktopSelectedTaskId` is the task actually shown.
  bool _tracksTaskById(BeamerDelegate delegate) =>
      _nav.isDesktopMode && identical(delegate, _nav.tasksDelegate);

  Future<void> _recordShownBy(BeamerDelegate delegate) async {
    final target = _tracksTaskById(delegate)
        ? switch (_nav.desktopSelectedTaskId.value) {
            final id? => _taskTarget(id),
            null => null,
          }
        : historyTargetForRoute(delegate.configuration.uri.path);
    if (target != null) await _record(target);
  }

  static HistoryTarget _taskTarget(String id) => HistoryTarget(
    kind: HistoryEntityKind.task,
    entityId: id,
    route: '/tasks/$id',
  );

  /// Records [target], reporting a failure instead of throwing: every call
  /// starts from a listener nobody awaits, and a lost visit costs only a row.
  Future<void> _record(HistoryTarget target) async {
    try {
      await _service.record(target);
    } catch (error, stackTrace) {
      _logger.error(
        LogDomain.navigation,
        error,
        stackTrace: stackTrace,
        subDomain: 'history.record',
      );
    }
  }

  Future<void> dispose() async {
    for (final detach in _detach) {
      detach();
    }
    _detach.clear();
    await _indexSubscription?.cancel();
    _indexSubscription = null;
  }
}
