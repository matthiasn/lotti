import 'dart:async';

import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/client_runner.dart';
import 'package:lotti/features/sync/matrix/last_read.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/matrix/timeline.dart'
    show listenToTimelineEvents, processNewTimelineEvents;
import 'package:lotti/features/sync/matrix/timeline_context.dart';
import 'package:lotti/features/user_activity/state/user_activity_gate.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// Coordinates Matrix timeline subscriptions and processing for the sync room.
class MatrixTimelineListener implements TimelineContext {
  MatrixTimelineListener({
    required MatrixSessionManager sessionManager,
    required SyncRoomManager roomManager,
    required LoggingService loggingService,
    required UserActivityGate activityGate,
    JournalDb? overriddenJournalDb,
    SettingsDb? overriddenSettingsDb,
    SyncReadMarkerService? readMarkerService,
    SyncEventProcessor? eventProcessor,
  })  : _sessionManager = sessionManager,
        _roomManager = roomManager,
        _loggingService = loggingService,
        _activityGate = activityGate,
        _overriddenJournalDb = overriddenJournalDb,
        _overriddenSettingsDb = overriddenSettingsDb,
        _readMarkerService = readMarkerService,
        _eventProcessor = eventProcessor {
    _clientRunner = ClientRunner<void>(
      callback: (_) async {
        await _activityGate.waitUntilIdle();
        await processNewTimelineEvents(
          listener: this,
          overriddenJournalDb: _overriddenJournalDb,
          overriddenLoggingService: _loggingService,
          overriddenSettingsDb: _overriddenSettingsDb,
          readMarkerService: _readMarkerService,
          eventProcessor: _eventProcessor,
        );
      },
    );
  }

  final MatrixSessionManager _sessionManager;
  final SyncRoomManager _roomManager;
  final LoggingService _loggingService;
  final UserActivityGate _activityGate;
  final JournalDb? _overriddenJournalDb;
  final SettingsDb? _overriddenSettingsDb;
  final SyncReadMarkerService? _readMarkerService;
  final SyncEventProcessor? _eventProcessor;

  late final ClientRunner<void> _clientRunner;
  Timeline? _timeline;
  String? _lastReadEventContextId;

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

  SettingsDb? get overriddenSettingsDb => _overriddenSettingsDb;

  JournalDb? get overriddenJournalDb => _overriddenJournalDb;

  /// Loads the last processed Matrix event ID so new sessions resume at the
  /// correct timeline position.
  Future<void> initialize() async {
    _lastReadEventContextId =
        await getLastReadMatrixEventId(_overriddenSettingsDb);
  }

  /// Attaches the timeline listener when a sync room is available.
  Future<void> start() async {
    await listenToTimelineEvents(listener: this);
  }

  /// Schedules a timeline refresh through the internal runner.
  @override
  void enqueueTimelineRefresh() {
    _clientRunner.enqueueRequest(null);
  }

  /// Releases resources and terminates active subscriptions.
  Future<void> dispose() async {
    _clientRunner.close();
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
}
