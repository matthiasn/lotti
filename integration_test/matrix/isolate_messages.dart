/// Messages used for communication between the main isolate and Matrix client isolates.
///
/// These message types provide a structured way to communicate with Matrix clients
/// running in separate isolates, ensuring type safety and clear intent for each
/// operation.

/// Base class for all isolate messages.
abstract class IsolateMessage {}

/// Message to initialize a Matrix client in an isolate.
///
/// This message contains all the necessary configuration to set up a Matrix client,
/// including server details, credentials, and file system paths.
class InitMessage extends IsolateMessage {
  InitMessage({
    required this.homeServer,
    required this.user,
    required this.password,
    required this.deviceName,
    required this.docDirPath,
  });

  /// The Matrix homeserver URL (e.g., "https://matrix.example.com").
  final String homeServer;

  /// The Matrix username (without @ prefix).
  final String user;

  /// The user's password for authentication.
  final String password;

  /// A unique name for this device/client instance.
  final String deviceName;

  /// Path to the documents directory for storing local data.
  final String docDirPath;
}

/// Message to trigger login to the Matrix server.
class LoginMessage extends IsolateMessage {}

/// Message to create a new Matrix room.
class CreateRoomMessage extends IsolateMessage {}

/// Message to join an existing Matrix room.
class JoinRoomMessage extends IsolateMessage {
  JoinRoomMessage(this.roomId);

  /// The ID of the room to join.
  final String roomId;
}

/// Message to invite a user to the sync room.
class InviteUserMessage extends IsolateMessage {
  InviteUserMessage(this.userId);

  /// The Matrix user ID to invite (e.g., "@user:example.com").
  final String userId;
}

/// Message to start listening for key verification requests.
class StartKeyVerificationMessage extends IsolateMessage {}

/// Message to verify an unverified device.
class VerifyDeviceMessage extends IsolateMessage {}

/// Message to send test messages to a room.
class SendTestMessagesMessage extends IsolateMessage {
  SendTestMessagesMessage({
    required this.count,
    required this.roomId,
  });

  /// Number of test messages to send.
  final int count;

  /// The room ID where messages should be sent.
  final String roomId;
}

/// Message to request statistics from the Matrix client.
class GetStatsMessage extends IsolateMessage {}

/// Message to shutdown the isolate gracefully.
class ShutdownMessage extends IsolateMessage {}

// Response types

/// Response containing a newly created room ID.
class RoomCreatedResponse {
  RoomCreatedResponse(this.roomId);
  final String roomId;
}

/// Response containing Matrix client statistics.
class StatsResponse {
  StatsResponse({
    required this.messageCount,
    required this.unverifiedDevices,
  });

  /// Number of messages received and stored.
  final int messageCount;

  /// Number of devices that are not yet verified.
  final int unverifiedDevices;
}

/// Generic status response for operations that don't return specific data.
class StatusResponse {
  StatusResponse(this.message);

  /// Human-readable status message.
  final String message;
}

/// Debug message sent from isolate to main isolate for logging.
class DebugMessage {
  DebugMessage(this.message);

  /// The debug message to log.
  final String message;
}