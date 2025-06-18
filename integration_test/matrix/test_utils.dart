import 'package:matrix/encryption/utils/key_verification.dart';
import 'package:matrix/matrix.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Creates an in-memory Matrix client for testing purposes.
///
/// This client uses an in-memory SQLite database, making it suitable for
/// integration tests that need isolated, temporary storage.
///
/// [deviceDisplayName] is the name shown for this device in Matrix.
/// [dbName] is an optional database name (defaults to 'lotti_sync').
///
/// Returns a configured [Client] instance ready for use.
Future<Client> createInMemoryMatrixClient({
  String? deviceDisplayName,
  String? dbName,
}) async {
  final database = await MatrixSdkDatabase.init(
    'lotti_sync',
    database: await databaseFactoryFfi.openDatabase(
      ':memory:',
      options: OpenDatabaseOptions(),
    ),
    sqfliteFactory: databaseFactoryFfi,
  );

  return Client(
    deviceDisplayName ?? 'lotti',
    verificationMethods: {
      KeyVerificationMethod.emoji,
      KeyVerificationMethod.reciprocate,
    },
    sendTimelineEventTimeout: const Duration(minutes: 2),
    database: database,
  );
}

/// Waits for the specified number of seconds.
///
/// Useful for allowing time for Matrix operations to complete,
/// such as message propagation or device verification.
Future<void> waitSeconds(int seconds) async {
  await Future<void>.delayed(Duration(seconds: seconds));
}