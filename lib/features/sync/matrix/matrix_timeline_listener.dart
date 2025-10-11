import 'dart:async';
import 'dart:io';

import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/client_runner.dart';
import 'package:lotti/features/sync/matrix/last_read.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/matrix/timeline.dart'
    show
        listenToTimelineEvents,
        processNewTimelineEvents,
        processTimelineEventsIncremental;
import 'package:lotti/features/sync/matrix/timeline_context.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';
import 'package:meta/meta.dart';

/// Coordinates Matrix timeline subscriptions and processing for the sync room.
class MatrixTimelineListener implements TimelineContext {
  MatrixTimelineListener({
    required MatrixSessionManager sessionManager,
    required SyncRoomManager roomManager,
    required LoggingService loggingService,
    required UserActivityGate activityGate,
    required JournalDb journalDb,
    required SettingsDb settingsDb,
    required SyncReadMarkerService readMarkerService,
    required SyncEventProcessor eventProcessor,
    required Directory documentsDirectory,
  })  : _sessionManager = sessionManager,
        _roomManager = roomManager,
        _loggingService = loggingService,
        _activityGate = activityGate,
        _journalDb = journalDb,
        _settingsDb = settingsDb,
        _readMarkerService = readMarkerService,
        _eventProcessor = eventProcessor,
        _documentsDirectory = documentsDirectory {
    _clientRunner = ClientRunner<void>(
      callback: (_) async {
        await _activityGate.waitUntilIdle();
        final drained = _drainPendingEvents();
        if (drained.isNotEmpty) {
          await _processPendingEvents(drained);
          return;
        }

        await processNewTimelineEvents(
          listener: this,
          journalDb: _journalDb,
          loggingService: _loggingService,
          readMarkerService: _readMarkerService,
          eventProcessor: _eventProcessor,
          documentsDirectory: _documentsDirectory,
          failureCounts: _eventFailureCounts,
        );
      },
    );
  }

  final MatrixSessionManager _sessionManager;
  final SyncRoomManager _roomManager;
  final LoggingService _loggingService;
  final UserActivityGate _activityGate;
  final JournalDb _journalDb;
  final SettingsDb _settingsDb;
  final SyncReadMarkerService _readMarkerService;
  final SyncEventProcessor _eventProcessor;
  final Directory _documentsDirectory;
  final Map<String, int> _eventFailureCounts = <String, int>{};

  late final ClientRunner<void> _clientRunner;
  Timeline? _timeline;
  String? _lastReadEventContextId;
  StreamSubscription<Event>? _timelineEventSubscription;
  final List<Event> _pendingEvents = <Event>[];
  String? _pendingMarkerEventId;
  Timer? _markerDebounceTimer;
  static const Duration _markerDebounce = Duration(milliseconds: 200);
  // Bound the pending onTimelineEvent queue to avoid unbounded growth
  // during network churn or long UI-idle stretches. When the limit is
  // exceeded, the oldest events are dropped (backpressure) since newer
  // events re-apply current state and the processor deduplicates by id.
  static const int _maxPendingEvents = 1000;
  // Process pending events in batches to keep memory usage stable while
  // deduplicating and ordering the working set. 500 provides a good balance:
  // small enough to bound transient allocations, large enough to amortize
  // per-batch overhead in busy rooms. Related events that span boundaries
  // are still handled correctly because processing is chronological and
  // marker advancement is based on the latest processed event.
  static const int _maxPendingBatchSize = 500;

  @override
  Client get client => _sessionManager.client;

  @override
  SyncRoomManager get roomManager => _roomManager;

  @override
  Timeline? get timeline => _timeline;

  @override
  set timeline(Timeline? value) => _timeline = value;

  ClientRunner<void> get clientRunner => _clientRunner;

  @override
  LoggingService get loggingService => _loggingService;

  SettingsDb get settingsDb => _settingsDb;

  JournalDb get journalDb => _journalDb;

  /// Loads the last processed Matrix event ID so new sessions resume at the
  /// correct timeline position.
  Future<void> initialize() async {
    _lastReadEventContextId = await getLastReadMatrixEventId(_settingsDb);
  }

  /// Attaches the timeline listener when a sync room is available.
  Future<void> start() async {
    await listenToTimelineEvents(listener: this);
    // Also listen to the client's decrypted timeline events to schedule a
    // refresh after the SDK has fully applied the update. This avoids racing
    // the timeline's own callbacks which may fire before its event list is
    // updated.
    await _timelineEventSubscription?.cancel();
    _timelineEventSubscription =
        client.onTimelineEvent.stream.listen((Event event) {
      final roomId = _roomManager.currentRoomId;
      if (roomId != null && event.roomId == roomId) {
        // Apply backpressure: cap the buffer and drop oldest if over limit.
        if (_pendingEvents.length >= _maxPendingEvents) {
          _pendingEvents.removeAt(0);
        }
        _pendingEvents.add(event);
        enqueueTimelineRefresh();
      }
    });
  }

  /// Schedules a timeline refresh through the internal runner.
  @override
  void enqueueTimelineRefresh() {
    _clientRunner.enqueueRequest(null);
  }

  /// Releases resources and terminates active subscriptions.
  Future<void> dispose() async {
    // Flush any pending read marker before tearing down timers/subscriptions.
    if (_pendingMarkerEventId != null) {
      await _flushReadMarker();
    }
    _clientRunner.close();
    await _timelineEventSubscription?.cancel();
    _markerDebounceTimer?.cancel();
    final timeline = _timeline;
    if (timeline != null) {
      timeline.cancelSubscriptions();
    }
  }

  @override
  String? get lastReadEventContextId => _lastReadEventContextId;

  @override
  set lastReadEventContextId(String? value) {
    _lastReadEventContextId = value;
  }

  // Drain and clear pending onTimelineEvent buffer.
  List<Event> _drainPendingEvents() {
    if (_pendingEvents.isEmpty) {
      return const <Event>[];
    }
    final copy = List<Event>.from(_pendingEvents);
    _pendingEvents.clear();
    return copy;
  }

  Future<void> _processPendingEvents(List<Event> events) async {
    // Sort chronologically (oldest first) once for deterministic batching.
    events.sort(TimelineEventOrdering.compare);

    // Deduplicate and process in bounded batches to avoid large temporary
    // allocations for very large bursts.
    var start = 0;
    String? latestIdOverall;
    while (start < events.length) {
      final end = (start + _maxPendingBatchSize).clamp(0, events.length);
      final window = events.sublist(start, end);
      start = end;

      final seen = <String>{};
      final unique = <Event>[
        for (final e in window)
          if (seen.add(e.eventId)) e,
      ];

      if (unique.isEmpty) continue;

      final latestId = await processTimelineEventsIncremental(
        listener: this,
        events: unique,
        journalDb: _journalDb,
        loggingService: _loggingService,
        readMarkerService: _readMarkerService,
        eventProcessor: _eventProcessor,
        documentsDirectory: _documentsDirectory,
        failureCounts: _eventFailureCounts,
      );

      if (latestId != null) {
        latestIdOverall = latestId;
      }
    }

    if (latestIdOverall != null) {
      lastReadEventContextId = latestIdOverall;
      _pendingMarkerEventId = latestIdOverall;
      _scheduleMarkerFlush();
    }
  }

  void _scheduleMarkerFlush() {
    _markerDebounceTimer?.cancel();
    _markerDebounceTimer = Timer(_markerDebounce, _flushReadMarker);
  }

  Future<void> _flushReadMarker() async {
    final id = _pendingMarkerEventId;
    final timeline = _timeline;
    final room = _roomManager.currentRoom;
    if (id == null || room == null) {
      return;
    }
    _pendingMarkerEventId = null;
    await _readMarkerService.updateReadMarker(
      client: client,
      room: room,
      eventId: id,
      timeline: timeline,
    );
  }

  // Test-use-only: allow setting a pending marker to exercise dispose flush.
  @visibleForTesting
  set debugPendingMarker(String? id) {
    _pendingMarkerEventId = id;
  }

  @visibleForTesting
  String? get debugPendingMarker => _pendingMarkerEventId;

  // Test-use-only: process a supplied event list through the incremental
  // pipeline (exercises debounce behaviour without relying on SDK streams).
  @visibleForTesting
  Future<void> debugProcessPendingEvents(List<Event> events) async {
    await _processPendingEvents(events);
  }

  // Test-use-only: enqueue a pending event using the same path as the SDK
  // listener but callable from tests to validate backpressure behaviour.
  @visibleForTesting
  void debugEnqueuePendingEvent(Event event) {
    if (_pendingEvents.length >= _maxPendingEvents) {
      _pendingEvents.removeAt(0);
    }
    _pendingEvents.add(event);
  }

  @visibleForTesting
  int get debugPendingLength => _pendingEvents.length;
}
