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
///   selections are watched too.
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
      target: (id) => HistoryTarget(
        kind: HistoryEntityKind.task,
        entityId: id,
        route: '/tasks/$id',
      ),
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
        if (_isFront(delegate)) _recordRouteOf(delegate);
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
      _recordRouteOf(delegates[index]);
    });
  }

  bool _isFront(BeamerDelegate delegate) =>
      _nav.beamerDelegates.indexOf(delegate) == _nav.index;

  Future<void> _recordRouteOf(BeamerDelegate delegate) async {
    final uri = delegate.configuration.uri;
    final target = historyTargetForRoute(uri.path);
    if (target != null) await _record(_visibleTask(target) ?? target);
  }

  /// The linked task actually on screen when [target] is the base of the
  /// desktop detail stack: the URL stays at the base while linked tasks are
  /// pushed above it, so the route alone would name a task the user is not
  /// looking at. Null when the route itself is what shows.
  ///
  /// A route that is *not* the stack's base is believed over the stack,
  /// which `TasksLocation` resets to it only after this listener has run.
  HistoryTarget? _visibleTask(HistoryTarget target) {
    if (target.kind != HistoryEntityKind.task) return null;
    final stack = _nav.desktopTaskDetailStack.value;
    if (stack.length < 2 || stack.first != target.entityId) return null;
    final top = stack.last;
    return HistoryTarget(
      kind: HistoryEntityKind.task,
      entityId: top,
      route: '/tasks/$top',
    );
  }

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
