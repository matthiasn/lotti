import 'package:lotti/features/sync/matrix/sent_event_registry.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// Minimal interface required by timeline helpers. Implemented by the concrete
/// timeline listener to decouple helper functions from their dependencies.
abstract class TimelineContext {
  LoggingService get loggingService;

  SyncRoomManager get roomManager;

  Client get client;

  Timeline? get timeline;

  set timeline(Timeline? value);

  String? get lastReadEventContextId;

  set lastReadEventContextId(String? value);

  SentEventRegistry get sentEventRegistry;

  void enqueueTimelineRefresh();
}
