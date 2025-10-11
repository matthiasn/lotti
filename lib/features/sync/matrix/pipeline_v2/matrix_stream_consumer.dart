import 'dart:async';
import 'dart:io';

import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/features/sync/matrix/last_read.dart';
import 'package:lotti/features/sync/matrix/pipeline/sync_pipeline.dart';
import 'package:lotti/features/sync/matrix/read_marker_service.dart';
import 'package:lotti/features/sync/matrix/save_attachment.dart';
import 'package:lotti/features/sync/matrix/session_manager.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/features/sync/matrix/timeline_ordering.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// Stream-first, simplified sync consumer (V2 scaffold).
///
/// This initial version only wires the lifecycle and logging; event processing
/// and micro-batching will land incrementally behind the same flag.
class MatrixStreamConsumer implements SyncPipeline {
  MatrixStreamConsumer({
    required MatrixSessionManager sessionManager,
    required SyncRoomManager roomManager,
    required LoggingService loggingService,
    required JournalDb journalDb,
    required SettingsDb settingsDb,
    required SyncEventProcessor eventProcessor,
    required SyncReadMarkerService readMarkerService,
    required Directory documentsDirectory,
    bool collectMetrics = false,
  })  : _sessionManager = sessionManager,
        _roomManager = roomManager,
        _loggingService = loggingService,
        _journalDb = journalDb,
        _settingsDb = settingsDb,
        _eventProcessor = eventProcessor,
        _readMarkerService = readMarkerService,
        _documentsDirectory = documentsDirectory,
        _collectMetrics = collectMetrics;

  final MatrixSessionManager _sessionManager;
  final SyncRoomManager _roomManager;
  final LoggingService _loggingService;
  final JournalDb _journalDb;
  final SettingsDb _settingsDb;
  final SyncEventProcessor _eventProcessor;
  final SyncReadMarkerService _readMarkerService;
  final Directory _documentsDirectory;
  final bool _collectMetrics;

  StreamSubscription<Event>? _sub;
  bool _initialized = false;
  String? _lastProcessedEventId;
  final List<Event> _pending = <Event>[];
  Timer? _flushTimer;
  Timer? _liveScanTimer;
  String? _pendingMarkerEventId;
  Timer? _markerDebounceTimer;
  static const Duration _flushInterval = Duration(milliseconds: 150);
  static const int _maxBatch = 200;
  static const Duration _markerDebounce = Duration(milliseconds: 600);

  // Lightweight metrics counters (dev diagnostics).
  int _metricProcessed = 0;
  int _metricSkipped = 0;
  int _metricFailures = 0;
  int _metricPrefetch = 0;
  int _metricFlushes = 0;
  int _metricCatchupBatches = 0;

  Client get _client => _sessionManager.client;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    // Ensure room snapshot is hydrated similarly to V1.
    await _roomManager.initialize();
    _lastProcessedEventId = await getLastReadMatrixEventId(_settingsDb);
    _initialized = true;
  }

  @override
  Future<void> start() async {
    // Ensure room snapshot exists, then catch up and attach streaming.
    if (_roomManager.currentRoom == null) {
      await _roomManager.hydrateRoomSnapshot(client: _client);
    }
    await _attachCatchUp();
    await _sub?.cancel();
    _sub = _client.onTimelineEvent.stream.listen((event) {
      final roomId = _roomManager.currentRoomId;
      if (roomId == null || event.roomId != roomId) return;
      _enqueue(event);
    });

    // Also attach live timeline listeners to proactively scan in case the
    // client-level stream is delayed or suppressed on some platforms.
    final room = _roomManager.currentRoom;
    if (room != null) {
      try {
        final tl = await room.getTimeline(
          onNewEvent: _scheduleLiveScan,
          onInsert: (_) => _scheduleLiveScan(),
          onChange: (_) => _scheduleLiveScan(),
          onRemove: (_) => _scheduleLiveScan(),
          onUpdate: _scheduleLiveScan,
        );
        _liveTimeline = tl;
      } catch (e, st) {
        _loggingService.captureException(
          e,
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'attach.liveTimeline',
          stackTrace: st,
        );
      }
    }
    _loggingService.captureEvent(
      'MatrixStreamConsumer started',
      domain: 'MATRIX_SYNC_V2',
      subDomain: 'start',
    );
  }

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _flushTimer?.cancel();
    _liveScanTimer?.cancel();
    _markerDebounceTimer?.cancel();
    _loggingService.captureEvent(
      'MatrixStreamConsumer disposed',
      domain: 'MATRIX_SYNC_V2',
      subDomain: 'dispose',
    );
  }

  void _enqueue(Event event) {
    _pending.add(event);
    if (_pending.length >= _maxBatch) {
      unawaited(_flush());
      return;
    }
    _flushTimer ??= Timer(_flushInterval, () {
      _flushTimer = null;
      unawaited(_flush());
    });
  }

  Future<void> _attachCatchUp() async {
    try {
      final room = _roomManager.currentRoom;
      final roomId = _roomManager.currentRoomId;
      if (room == null || roomId == null) {
        _loggingService.captureEvent(
          'No active room for catch-up',
          domain: 'MATRIX_SYNC_V2',
          subDomain: 'catchup',
        );
        return;
      }
      const limits = <int>[200, 500, 1000];
      for (final limit in limits) {
        final snapshot = await room.getTimeline(limit: limit);
        final events = List<Event>.from(snapshot.events)
          ..sort(TimelineEventOrdering.compare);
        final idx = _findLastIndex(events, _lastProcessedEventId);
        final slice = idx >= 0 ? events.sublist(idx + 1) : events;
        if (slice.isNotEmpty) {
          if (_collectMetrics) _metricCatchupBatches++;
          await _processOrdered(slice);
          snapshot.cancelSubscriptions();
          break;
        }
        snapshot.cancelSubscriptions();
      }
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'catchup',
        stackTrace: st,
      );
    }
  }

  Timeline? _liveTimeline;

  void _scheduleLiveScan() {
    _liveScanTimer?.cancel();
    _liveScanTimer = Timer(const Duration(milliseconds: 120), () {
      unawaited(_scanLiveTimeline());
    });
  }

  Future<void> _scanLiveTimeline() async {
    final tl = _liveTimeline;
    if (tl == null) return;
    try {
      final events = List<Event>.from(tl.events)
        ..sort(TimelineEventOrdering.compare);
      final idx = _findLastIndex(events, _lastProcessedEventId);
      final slice = idx >= 0 ? events.sublist(idx + 1) : events;
      if (slice.isNotEmpty) {
        await _processOrdered(slice);
        if (_collectMetrics) {
          _loggingService.captureEvent(
            'v2 liveScan processed=${slice.length} latest=${_lastProcessedEventId ?? 'null'}',
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'liveScan',
          );
        }
      }
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'liveScan',
        stackTrace: st,
      );
    }
  }

  int _findLastIndex(List<Event> ordered, String? id) {
    if (id == null) return -1;
    for (var i = ordered.length - 1; i >= 0; i--) {
      if (ordered[i].eventId == id) return i;
    }
    return -1;
  }

  Future<void> _flush() async {
    if (_pending.isEmpty) return;
    final queue = List<Event>.from(_pending);
    _pending.clear();
    queue.sort(TimelineEventOrdering.compare);
    // Deduplicate by id while preserving chronological order.
    final seen = <String>{};
    final ordered = <Event>[
      for (final e in queue)
        if (seen.add(e.eventId)) e,
    ];
    await _processOrdered(ordered);
    if (_collectMetrics) {
      _metricFlushes++;
      _loggingService.captureEvent(
        'v2 metrics flush=$_metricFlushes processed=$_metricProcessed skipped=$_metricSkipped failures=$_metricFailures prefetch=$_metricPrefetch catchup=$_metricCatchupBatches',
        domain: 'MATRIX_SYNC_V2',
        subDomain: 'metrics',
      );
    }
  }

  Future<void> _processOrdered(List<Event> ordered) async {
    final room = _roomManager.currentRoom;
    if (room == null || ordered.isEmpty) return;

    // First pass: prefetch attachments for remote events.
    for (final e in ordered) {
      final isRemote = e.senderId != _client.userID;
      if (isRemote && e.attachmentMimetype.isNotEmpty) {
        await saveAttachment(
          e,
          loggingService: _loggingService,
          documentsDirectory: _documentsDirectory,
        );
        if (_collectMetrics) _metricPrefetch++;
      }
    }

    // Second pass: process text events and compute advancement.
    String? latestEventId;
    num? latestTs;
    for (final e in ordered) {
      final ts = TimelineEventOrdering.timestamp(e);
      final id = e.eventId;
      final content = e.content;
      final msgType = content['msgtype'];
      var processedOk = true;
      if (msgType == syncMessageType) {
        try {
          await _eventProcessor.process(event: e, journalDb: _journalDb);
          if (_collectMetrics) _metricProcessed++;
        } catch (err, st) {
          processedOk = false;
          _loggingService.captureException(
            err,
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'process',
            stackTrace: st,
          );
          if (_collectMetrics) _metricFailures++;
        }
      } else {
        if (_collectMetrics) _metricSkipped++;
      }
      if (processedOk &&
          TimelineEventOrdering.isNewer(
            candidateTimestamp: ts,
            candidateEventId: id,
            latestTimestamp: latestTs,
            latestEventId: latestEventId,
          )) {
        latestTs = ts;
        latestEventId = id;
      }
    }

    if (latestEventId != null) {
      _lastProcessedEventId = latestEventId;
      _pendingMarkerEventId = latestEventId;
      _scheduleMarkerFlush(room);
    }
  }

  Map<String, int> metricsSnapshot() => <String, int>{
        'processed': _metricProcessed,
        'skipped': _metricSkipped,
        'failures': _metricFailures,
        'prefetch': _metricPrefetch,
        'flushes': _metricFlushes,
        'catchupBatches': _metricCatchupBatches,
      };

  void _scheduleMarkerFlush(Room room) {
    _markerDebounceTimer?.cancel();
    _markerDebounceTimer = Timer(_markerDebounce, () {
      unawaited(
        _flushReadMarker(room).catchError((Object error, StackTrace stack) {
          _loggingService.captureException(
            error,
            domain: 'MATRIX_SYNC_V2',
            subDomain: 'flushReadMarker',
            stackTrace: stack,
          );
        }),
      );
    });
  }

  Future<void> _flushReadMarker(Room room) async {
    final id = _pendingMarkerEventId;
    if (id == null) return;
    _pendingMarkerEventId = null;
    await _readMarkerService.updateReadMarker(
      client: _client,
      room: room,
      eventId: id,
    );
  }
}
