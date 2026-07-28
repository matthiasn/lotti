import 'package:lotti/features/sync/gateway/matrix_sdk_gateway.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';

/// Room setup for the two-device Matrix integration tests.
///
/// Production code never creates a sync room or invites anyone into one: rooms
/// are created out of band and every device receives the room id through its
/// provisioning bundle (see `ProvisioningController`). These tests are the only
/// thing left that has to stand up a fresh room and get a second account into
/// it, so the two calls live here rather than as `MatrixService` API surface
/// that nothing in the app would use.
Future<String> createTestSyncRoom(
  MatrixSdkGateway gateway, {
  String name = 'Lotti Sync Integration Test',
}) => gateway.createRoom(name: name);

/// Invites [userId] into the service's currently configured sync room.
///
/// Throws if no room is configured, so a mis-sequenced test fails on the
/// invite rather than silently on a later assertion.
Future<void> inviteToTestSyncRoom(
  MatrixService service, {
  required String userId,
}) async {
  final room = service.syncRoom;
  if (room == null) {
    throw StateError(
      'inviteToTestSyncRoom: no sync room configured on ${service.client.userID}',
    );
  }
  await room.invite(userId);
}
