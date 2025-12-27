import 'dart:convert';

import 'package:lotti/features/sync/matrix/consts.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// Custom state event type used to identify Lotti sync rooms.
/// New rooms created after this feature will have this state event set.
const String lottiSyncRoomStateType = 'm.lotti.sync_room';

/// Represents a candidate sync room discovered during room discovery.
class SyncRoomCandidate {
  const SyncRoomCandidate({
    required this.roomId,
    required this.roomName,
    required this.createdAt,
    required this.memberCount,
    required this.hasStateMarker,
    required this.hasLottiContent,
  });

  /// The Matrix room ID (e.g., !abc123:matrix.org).
  final String roomId;

  /// Human-readable room name, or null if not set.
  final String? roomName;

  /// Approximate creation time based on room state, or null if unknown.
  final DateTime? createdAt;

  /// Number of members in the room.
  final int memberCount;

  /// True if room has the explicit Lotti state marker.
  final bool hasStateMarker;

  /// True if room contains Lotti sync message content.
  final bool hasLottiContent;

  /// Confidence level for this being a Lotti sync room.
  /// Higher is more confident.
  int get confidence {
    var score = 0;
    if (hasStateMarker) score += 10;
    if (hasLottiContent) score += 5;
    return score;
  }

  @override
  String toString() => 'SyncRoomCandidate(roomId: $roomId, name: $roomName, '
      'confidence: $confidence)';
}

/// Service for discovering existing Lotti sync rooms when a user logs in.
///
/// This enables the single-user multi-device flow where Device B can discover
/// and join an existing sync room instead of waiting for an invite.
class SyncRoomDiscoveryService {
  SyncRoomDiscoveryService({
    required LoggingService loggingService,
  }) : _loggingService = loggingService;

  final LoggingService _loggingService;

  /// Discovers potential Lotti sync rooms from the client's joined rooms.
  ///
  /// Returns a list of [SyncRoomCandidate] sorted by confidence (highest first).
  /// Only returns rooms that are:
  /// 1. Encrypted
  /// 2. Private (not public/world-readable)
  /// 3. Have either the Lotti state marker OR contain Lotti sync messages
  Future<List<SyncRoomCandidate>> discoverSyncRooms(Client client) async {
    final candidates = <SyncRoomCandidate>[];

    for (final room in client.rooms) {
      final candidate = await _evaluateRoom(room);
      if (candidate != null) {
        candidates.add(candidate);
      }
    }

    // Sort by confidence descending, then by creation date descending
    candidates.sort((a, b) {
      final confidenceCompare = b.confidence.compareTo(a.confidence);
      if (confidenceCompare != 0) return confidenceCompare;

      final aCreated = a.createdAt;
      final bCreated = b.createdAt;
      if (aCreated == null && bCreated == null) return 0;
      if (aCreated == null) return 1;
      if (bCreated == null) return -1;
      return bCreated.compareTo(aCreated);
    });

    _loggingService.captureEvent(
      'Discovered ${candidates.length} potential sync rooms',
      domain: 'SYNC_ROOM_DISCOVERY',
      subDomain: 'discover',
    );

    return candidates;
  }

  /// Checks if the user has any existing sync rooms.
  Future<bool> hasExistingSyncRooms(Client client) async {
    final rooms = await discoverSyncRooms(client);
    return rooms.isNotEmpty;
  }

  /// Evaluates a single room to determine if it's a Lotti sync room candidate.
  Future<SyncRoomCandidate?> _evaluateRoom(Room room) async {
    // Must be encrypted
    if (!room.encrypted) {
      return null;
    }

    // Must be private (not public)
    if (room.joinRules == JoinRules.public) {
      return null;
    }

    // Check for explicit Lotti state marker
    final hasStateMarker = _hasLottiStateMarker(room);

    // Check for Lotti sync content in recent messages
    final hasLottiContent = await _hasLottiSyncContent(room);

    // Must have at least one indicator
    if (!hasStateMarker && !hasLottiContent) {
      return null;
    }

    return SyncRoomCandidate(
      roomId: room.id,
      roomName: room.name.isNotEmpty ? room.name : null,
      createdAt: _extractCreationTime(room),
      memberCount: room.summary.mJoinedMemberCount ?? 1,
      hasStateMarker: hasStateMarker,
      hasLottiContent: hasLottiContent,
    );
  }

  /// Checks if the room has the explicit Lotti sync room state marker.
  bool _hasLottiStateMarker(Room room) {
    try {
      final stateEvent = room.getState(lottiSyncRoomStateType);
      return stateEvent != null;
    } catch (_) {
      return false;
    }
  }

  /// Checks if the room contains Lotti sync message content.
  ///
  /// Examines the room's timeline for messages with:
  /// 1. msgtype == syncMessageType ('com.lotti.sync.message'), OR
  /// 2. Base64-encoded JSON with a 'runtimeType' field (fallback detection)
  Future<bool> _hasLottiSyncContent(Room room) async {
    try {
      // Get a timeline snapshot to check for sync messages
      final timeline = await room.getTimeline(limit: 50);

      // Check recent events in the timeline
      for (final event in timeline.events.take(50)) {
        if (_isLottiSyncEvent(event)) {
          return true;
        }
      }

      return false;
    } catch (e) {
      _loggingService.captureEvent(
        'Error checking room ${room.id} for sync content: $e',
        domain: 'SYNC_ROOM_DISCOVERY',
        subDomain: 'hasLottiSyncContent',
      );
      return false;
    }
  }

  /// Determines if an event is a Lotti sync message.
  bool _isLottiSyncEvent(Event event) {
    // Check by msgtype first (preferred method)
    final content = event.content;
    final msgType = content['msgtype'];
    if (msgType == syncMessageType) {
      return true;
    }

    // Fallback: check for base64-encoded JSON with runtimeType
    return _isLikelySyncPayloadEvent(event);
  }

  /// Checks if an event likely contains a sync payload via base64 content.
  bool _isLikelySyncPayloadEvent(Event event) {
    try {
      final text = event.text;
      if (text.isEmpty) return false;

      final decoded = utf8.decode(base64.decode(text));
      final obj = json.decode(decoded);
      return obj is Map<String, dynamic> && obj['runtimeType'] is String;
    } catch (_) {
      return false;
    }
  }

  /// Attempts to extract the room creation time from state events.
  DateTime? _extractCreationTime(Room room) {
    try {
      final stateEvent = room.getState('m.room.create');
      // getState returns StrippedStateEvent, but for joined rooms
      // it may be an Event with originServerTs
      if (stateEvent is Event) {
        return stateEvent.originServerTs;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Sets the Lotti sync room state marker on a room.
  ///
  /// Call this when creating a new sync room to enable future discovery.
  Future<void> markRoomAsLottiSync(Room room) async {
    try {
      await room.client.setRoomStateWithKey(
        room.id,
        lottiSyncRoomStateType,
        '',
        {
          'version': 1,
          'created_by': 'lotti',
          'marked_at': DateTime.now().toIso8601String(),
        },
      );
      _loggingService.captureEvent(
        'Marked room ${room.id} as Lotti sync room',
        domain: 'SYNC_ROOM_DISCOVERY',
        subDomain: 'markRoom',
      );
    } catch (e, st) {
      _loggingService.captureException(
        e,
        domain: 'SYNC_ROOM_DISCOVERY',
        subDomain: 'markRoom',
        stackTrace: st,
      );
    }
  }
}
