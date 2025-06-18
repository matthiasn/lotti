import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/config.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'matrix/isolate_messages.dart';
import 'matrix/matrix_test_client.dart';
import 'matrix/test_utils.dart';

/// Integration tests for the Matrix synchronization service.
///
/// These tests verify that:
/// - Two Matrix clients can connect and authenticate
/// - Clients can create and join rooms
/// - Device verification works correctly
/// - Messages are properly synchronized between clients
///
/// ## Prerequisites
///
/// These tests require a running Matrix server. Use the provided script:
/// ```bash
/// integration_test/run_matrix_tests.sh
/// ```
///
/// This script will:
/// 1. Start a local Dendrite server via Docker
/// 2. Create test users
/// 3. Run the tests with proper environment variables
///
/// ## Environment Variables
///
/// - `TEST_USER1`: First test user's username
/// - `TEST_USER2`: Second test user's username
/// - `TEST_SERVER`: Matrix homeserver URL (optional)
/// - `TEST_PASSWORD`: Password for test users (optional)
/// - `SLOW_NETWORK`: Set to simulate degraded network conditions
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MatrixService Tests', () {
    // Environment variable names
    const testUserEnv1 = 'TEST_USER1';
    const testUserEnv2 = 'TEST_USER2';
    const testServerEnv = 'TEST_SERVER';
    const testPasswordEnv = 'TEST_PASSWORD';
    const testSlowNetworkEnv = 'SLOW_NETWORK';

    // Check for slow network mode
    const testSlowNetwork = bool.fromEnvironment(testSlowNetworkEnv);
    if (testSlowNetwork) {
      debugPrint('Testing with degraded network.');
    }

    // Validate required environment variables
    if (!const bool.hasEnvironment(testUserEnv1)) {
      debugPrint('TEST_USER1 not defined!!! Run via run_matrix_tests.sh');
      exit(1);
    }

    if (!const bool.hasEnvironment(testUserEnv2)) {
      debugPrint('TEST_USER2 not defined!!! Run via run_matrix_tests.sh');
      exit(1);
    }

    // Read configuration from environment
    const aliceUserName = String.fromEnvironment(testUserEnv1);
    const bobUserName = String.fromEnvironment(testUserEnv2);

    const testHomeServer = bool.hasEnvironment(testServerEnv)
        ? String.fromEnvironment(testServerEnv)
        : testSlowNetwork
            ? 'http://localhost:18008'
            : 'http://localhost:8008';
    const testPassword = bool.hasEnvironment(testPasswordEnv)
        ? String.fromEnvironment(testPasswordEnv)
        : '?Secret123@';

    // Create Matrix configurations for test users
    const config1 = MatrixConfig(
      homeServer: testHomeServer,
      user: aliceUserName,
      password: testPassword,
    );

    const config2 = MatrixConfig(
      homeServer: testHomeServer,
      user: bobUserName,
      password: testPassword,
    );

    // Default delay between operations
    const defaultDelay = 5;

    test(
      'Create room, join, verify devices, and sync messages',
      () async {
        // Create temporary directory for test data
        final tmpDir = await getTemporaryDirectory();
        final docDir = Directory('${tmpDir.path}/${const Uuid().v1()}')
          ..createSync(recursive: true);
        debugPrint('Created temporary docDir ${docDir.path}');

        // Create test clients in isolates
        final alice = MatrixTestClient(name: 'Alice', config: config1);
        final bob = MatrixTestClient(name: 'Bob', config: config2);

        try {
          // Start isolates
          debugPrint('\n--- Starting Alice isolate');
          await alice.start(docDir.path);

          debugPrint('\n--- Starting Bob isolate');
          await bob.start(docDir.path);

          // Login both clients
          debugPrint('\n--- Alice goes live');
          await alice.login();

          debugPrint('\n--- Bob goes live');
          await bob.login();

          // Create and join room
          debugPrint('\n--- Alice creates room');
          final roomId = await alice.createRoom();
          debugPrint('Alice - room created: $roomId');
          expect(roomId, isNotEmpty);

          // Invite Bob to the room
          debugPrint('\n--- Alice invites Bob into room $roomId');
          await alice.inviteUser(bobUserName);
          await waitSeconds(defaultDelay);

          // Bob joins the room
          debugPrint('\n--- Bob joins room');
          await bob.joinRoom(roomId);
          await waitSeconds(defaultDelay);

          // Start key verification process
          debugPrint('\n--- Starting key verification');
          await alice.startKeyVerification();
          await bob.startKeyVerification();
          await waitSeconds(defaultDelay);

          // Wait for unverified devices to appear
          StatsResponse aliceStats;
          StatsResponse bobStats;
          do {
            await waitSeconds(1);
            aliceStats = await alice.getStats();
            bobStats = await bob.getStats();
          } while (aliceStats.unverifiedDevices == 0 ||
              bobStats.unverifiedDevices == 0);

          debugPrint(
              '\nAlice - unverified devices: ${aliceStats.unverifiedDevices}');
          debugPrint('Bob - unverified devices: ${bobStats.unverifiedDevices}');

          // Verify devices
          debugPrint('\n--- Alice verifies Bob');
          await alice.verifyDevice();
          await waitSeconds(defaultDelay);

          // Wait for verification to complete
          do {
            await waitSeconds(1);
            aliceStats = await alice.getStats();
            bobStats = await bob.getStats();
          } while (aliceStats.unverifiedDevices > 0 ||
              bobStats.unverifiedDevices > 0);

          debugPrint('\n--- Alice and Bob both have no unverified devices');
          expect(aliceStats.unverifiedDevices, 0);
          expect(bobStats.unverifiedDevices, 0);

          // Send test messages
          const n = testSlowNetwork ? 10 : 100;

          debugPrint('\n--- Alice sends $n messages');
          await alice.sendTestMessages(n, roomId);

          debugPrint('\n--- Bob sends $n messages');
          await bob.sendTestMessages(n, roomId);

          // Wait for messages to be received
          debugPrint('\n--- Waiting for messages to be received');
          do {
            await waitSeconds(2);
            aliceStats = await alice.getStats();
            bobStats = await bob.getStats();
            debugPrint(
                'Alice: ${aliceStats.messageCount}, Bob: ${bobStats.messageCount}');
          } while (aliceStats.messageCount < n || bobStats.messageCount < n);

          // Verify final message counts
          debugPrint('\n--- Alice finished receiving messages');
          expect(aliceStats.messageCount, n);
          debugPrint('Alice persisted ${aliceStats.messageCount} entries');

          debugPrint('\n--- Bob finished receiving messages');
          expect(bobStats.messageCount, n);
          debugPrint('Bob persisted ${bobStats.messageCount} entries');
        } finally {
          // Clean up - always shutdown isolates
          debugPrint('\n--- Shutting down isolates');
          await alice.shutdown();
          await bob.shutdown();
        }
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  });
}

const uuid = Uuid();
