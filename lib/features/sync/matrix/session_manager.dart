import 'package:lotti/classes/config.dart';
import 'package:lotti/features/sync/gateway/matrix_sync_gateway.dart';
import 'package:lotti/features/sync/matrix/client.dart';
import 'package:lotti/features/sync/matrix/sync_room_manager.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:matrix/matrix.dart';

/// Coordinates Matrix client connectivity, login/logout flows, and ensures the
/// persisted sync room is rejoined after successful authentication.
class MatrixSessionManager {
  MatrixSessionManager({
    required MatrixSyncGateway gateway,
    required SyncRoomManager roomManager,
    required LoggingService loggingService,
  })  : _gateway = gateway,
        _roomManager = roomManager,
        _loggingService = loggingService;

  final MatrixSyncGateway _gateway;
  final SyncRoomManager _roomManager;
  final LoggingService _loggingService;

  SyncRoomManager get roomManager => _roomManager;

  MatrixConfig? matrixConfig;
  LoginResponse? loginResponse;
  String? deviceDisplayName;

  Client get client => _gateway.client;

  /// Exposes the client's timeline event stream without leaking SDK-specific
  /// controller types to tests or call-sites.
  Stream<Event> get timelineEvents => _gateway.client.onTimelineEvent.stream;

  /// Establishes a Matrix session and, if requested, performs an interactive
  /// login. Returns `true` when connectivity succeeded.
  Future<bool> connect({required bool shouldAttemptLogin}) async {
    try {
      final config = matrixConfig;
      if (config == null) {
        _loggingService.captureEvent(
          'Matrix configuration missing – cannot establish session.',
          domain: 'MATRIX_SESSION_MANAGER',
          subDomain: 'connect',
        );
        return false;
      }

      await _gateway.connect(config);

      if (!client.isLogged() && shouldAttemptLogin) {
        final initialDeviceDisplayName =
            deviceDisplayName ?? await createMatrixDeviceName();
        loginResponse = await _gateway.login(
          config,
          deviceDisplayName: initialDeviceDisplayName,
        );
        _loggingService.captureEvent(
          'Logged in to homeserver as ${loginResponse?.userId}, '
          'deviceId ${loginResponse?.deviceId}',
          domain: 'MATRIX_SESSION_MANAGER',
          subDomain: 'login',
        );
      }

      await _roomManager.initialize();

      if (client.isLogged()) {
        await _roomManager.hydrateRoomSnapshot(client: client);
        final savedRoomId = await _roomManager.loadPersistedRoomId();
        if (savedRoomId != null && client.getRoomById(savedRoomId) == null) {
          try {
            await _roomManager.joinRoom(savedRoomId);
          } catch (error, stackTrace) {
            _loggingService.captureException(
              error,
              domain: 'MATRIX_SESSION_MANAGER',
              subDomain: 'connect.join',
              stackTrace: stackTrace,
            );
            var notInRoom = false;
            if (error is MatrixException) {
              final code = error.errcode;
              notInRoom = code == 'M_FORBIDDEN' || code == 'M_NOT_FOUND';
            }
            if (notInRoom) {
              await _roomManager.clearPersistedRoom(
                subDomain: 'connect.join.clear',
              );
            }
          }
        }
      }

      return true;
    } catch (error, stackTrace) {
      _loggingService.captureException(
        error,
        domain: 'MATRIX_SESSION_MANAGER',
        subDomain: 'connect',
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  bool isLoggedIn() => client.isLogged();

  Future<void> logout() => _gateway.logout();

  Future<void> dispose() => _gateway.dispose();
}
