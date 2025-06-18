import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:lotti/classes/config.dart';

import 'isolate_messages.dart';
import 'isolate_worker.dart';

/// A test client that manages a Matrix client running in a separate isolate.
///
/// This class provides a high-level interface for controlling a Matrix client
/// in an isolate, handling all the complexity of inter-isolate communication.
/// Each instance represents a separate Matrix user/device combination.
///
/// Example usage:
/// ```dart
/// final alice = MatrixTestClient(name: 'Alice', config: aliceConfig);
/// await alice.start(docDir.path);
/// await alice.login();
/// final roomId = await alice.createRoom();
/// await alice.sendTestMessages(10, roomId);
/// await alice.shutdown();
/// ```
class MatrixTestClient {
  MatrixTestClient({
    required this.name,
    required this.config,
  });

  /// A human-readable name for this client (e.g., "Alice", "Bob").
  /// Used for logging and debugging purposes.
  final String name;

  /// Matrix configuration containing server URL, username, and password.
  final MatrixConfig config;

  /// The isolate running the Matrix client.
  Isolate? isolate;

  /// SendPort for communicating with the isolate.
  SendPort? sendPort;

  /// Controller for broadcasting responses from the isolate.
  final _responseController = StreamController<dynamic>.broadcast();

  /// Whether this client has been initialized.
  bool _isInitialized = false;

  /// Stream of responses from the isolate.
  /// Consumers can listen to this stream and filter for specific response types.
  Stream<dynamic> get responses => _responseController.stream;

  /// Starts the isolate and initializes the Matrix client.
  ///
  /// This method:
  /// 1. Spawns a new isolate for the Matrix client
  /// 2. Establishes communication channels
  /// 3. Initializes the Matrix client with the provided configuration
  ///
  /// [docDirPath] is the path to the documents directory for storing local data.
  ///
  /// Throws [TimeoutException] if initialization takes longer than 30 seconds.
  Future<void> start(String docDirPath) async {
    debugPrint('$name: Starting isolate...');
    final receivePort = ReceivePort();
    final completer = Completer<SendPort>();

    // Set up listener for messages from the isolate
    receivePort.listen((message) {
      if (message is SendPort) {
        debugPrint('$name: Received SendPort from isolate');
        completer.complete(message);
      } else if (message is DebugMessage) {
        debugPrint('[ISOLATE $name] ${message.message}');
      } else {
        _responseController.add(message);
      }
    });

    debugPrint('$name: Spawning isolate...');
    final rootIsolateToken = RootIsolateToken.instance!;
    isolate = await Isolate.spawn(
      matrixClientIsolate,
      [receivePort.sendPort, rootIsolateToken],
    );

    debugPrint('$name: Waiting for SendPort...');
    sendPort = await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw TimeoutException('Failed to receive SendPort from isolate');
      },
    );
    _isInitialized = true;

    // Initialize the isolate with configuration
    sendPort!.send(InitMessage(
      homeServer: config.homeServer,
      user: config.user,
      password: config.password,
      deviceName: name,
      docDirPath: docDirPath,
    ));

    debugPrint('$name: Waiting for initialization response...');
    await _waitForResponse<StatusResponse>((r) => r.message == 'Initialized')
        .timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException('Isolate initialization timeout');
      },
    );
    debugPrint('$name: Initialization complete!');
  }

  /// Waits for a specific response from the isolate.
  ///
  /// [predicate] is a function that returns true when the desired response is received.
  ///
  /// Returns the first response of type [T] that matches the predicate.
  Future<T> _waitForResponse<T>(bool Function(T) predicate) async {
    final response = await responses
        .where((r) => r is T)
        .cast<T>()
        .firstWhere(predicate);
    return response;
  }

  /// Logs in to the Matrix server.
  ///
  /// Throws [TimeoutException] if login takes longer than 30 seconds.
  /// Throws [StateError] if the client hasn't been started.
  Future<void> login() async {
    _ensureInitialized();
    debugPrint('$name: Sending LoginMessage to isolate...');
    sendPort!.send(LoginMessage());
    debugPrint('$name: LoginMessage sent, waiting for response...');
    await _waitForResponse<StatusResponse>(
      (r) => r.message.startsWith('Logged in'),
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw TimeoutException('Login timeout after 30 seconds');
      },
    );
  }

  /// Creates a new Matrix room.
  ///
  /// Returns the room ID of the newly created room.
  /// Throws [StateError] if the client hasn't been started.
  Future<String> createRoom() async {
    _ensureInitialized();
    sendPort!.send(CreateRoomMessage());
    final response = await _waitForResponse<RoomCreatedResponse>((_) => true);
    return response.roomId;
  }

  /// Joins an existing Matrix room.
  ///
  /// [roomId] is the ID of the room to join.
  /// Throws [StateError] if the client hasn't been started.
  Future<void> joinRoom(String roomId) async {
    _ensureInitialized();
    sendPort!.send(JoinRoomMessage(roomId));
    await _waitForResponse<StatusResponse>((r) => r.message == 'Joined room');
  }

  /// Invites a user to the sync room.
  ///
  /// [userId] is the Matrix user ID to invite (e.g., "@user:example.com").
  /// Throws [StateError] if the client hasn't been started.
  Future<void> inviteUser(String userId) async {
    _ensureInitialized();
    sendPort!.send(InviteUserMessage(userId));
    await _waitForResponse<StatusResponse>((r) => r.message == 'Invited user');
  }

  /// Starts listening for key verification requests.
  ///
  /// This sets up listeners for both incoming and outgoing verification requests.
  /// Throws [StateError] if the client hasn't been started.
  Future<void> startKeyVerification() async {
    _ensureInitialized();
    sendPort!.send(StartKeyVerificationMessage());
    await _waitForResponse<StatusResponse>(
      (r) => r.message == 'Verification listeners started',
    );
  }

  /// Verifies the first unverified device.
  ///
  /// Throws [StateError] if the client hasn't been started.
  Future<void> verifyDevice() async {
    _ensureInitialized();
    sendPort!.send(VerifyDeviceMessage());
    await _waitForResponse<StatusResponse>(
      (r) => r.message == 'Device verified',
    );
  }

  /// Sends test messages to a room.
  ///
  /// [count] is the number of messages to send.
  /// [roomId] is the room to send messages to.
  /// Throws [StateError] if the client hasn't been started.
  Future<void> sendTestMessages(int count, String roomId) async {
    _ensureInitialized();
    sendPort!.send(SendTestMessagesMessage(count: count, roomId: roomId));
    await _waitForResponse<StatusResponse>((r) => r.message == 'Messages sent');
  }

  /// Gets statistics from the Matrix client.
  ///
  /// Returns a [StatsResponse] containing message counts and device verification status.
  /// Throws [StateError] if the client hasn't been started.
  Future<StatsResponse> getStats() async {
    _ensureInitialized();
    sendPort!.send(GetStatsMessage());
    return _waitForResponse<StatsResponse>((_) => true);
  }

  /// Shuts down the isolate and cleans up resources.
  ///
  /// This method:
  /// 1. Sends a shutdown message to the isolate
  /// 2. Waits for confirmation (with timeout)
  /// 3. Kills the isolate
  /// 4. Closes the response stream
  ///
  /// Safe to call multiple times or on an uninitialized client.
  Future<void> shutdown() async {
    if (_isInitialized && sendPort != null) {
      sendPort!.send(ShutdownMessage());
      try {
        await _waitForResponse<StatusResponse>(
          (r) => r.message == 'Shutdown complete',
        ).timeout(const Duration(seconds: 5));
      } catch (e) {
        debugPrint('Error during shutdown: $e');
      }
    }
    isolate?.kill();
    await _responseController.close();
  }

  /// Ensures the client has been initialized before performing operations.
  ///
  /// Throws [StateError] if [start] hasn't been called successfully.
  void _ensureInitialized() {
    if (!_isInitialized || sendPort == null) {
      throw StateError('MatrixTestClient not initialized. Call start() first.');
    }
  }
}