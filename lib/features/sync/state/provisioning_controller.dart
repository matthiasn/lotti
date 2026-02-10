import 'dart:convert';
import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'provisioning_controller.freezed.dart';
part 'provisioning_controller.g.dart';

@freezed
sealed class ProvisioningState with _$ProvisioningState {
  const factory ProvisioningState.initial() = _Initial;
  const factory ProvisioningState.bundleDecoded(
    SyncProvisioningBundle bundle,
  ) = _BundleDecoded;
  const factory ProvisioningState.loggingIn() = _LoggingIn;
  const factory ProvisioningState.joiningRoom() = _JoiningRoom;
  const factory ProvisioningState.rotatingPassword() = _RotatingPassword;
  const factory ProvisioningState.ready(String handoverBase64) = _Ready;
  const factory ProvisioningState.done() = _Done;
  const factory ProvisioningState.error(String message) = _Error;
}

@riverpod
class ProvisioningController extends _$ProvisioningController {
  @override
  ProvisioningState build() => const ProvisioningState.initial();

  /// Decodes a Base64-encoded provisioning bundle string.
  ///
  /// Accepts both padded and unpadded Base64url. Validates the bundle
  /// version, MXID format, room ID format, and homeserver URL.
  SyncProvisioningBundle decodeBundle(String base64String) {
    try {
      final normalized = _normalizeBase64(base64String.trim());
      final bytes = base64Decode(normalized);
      final jsonString = utf8.decode(bytes);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final bundle = SyncProvisioningBundle.fromJson(json);

      if (bundle.v != 1) {
        throw const FormatException('Unsupported bundle version');
      }
      if (!bundle.user.startsWith('@')) {
        throw const FormatException('Invalid MXID: must start with @');
      }
      if (!bundle.roomId.startsWith('!')) {
        throw const FormatException('Invalid room ID: must start with !');
      }
      if (!bundle.homeServer.startsWith('http')) {
        throw const FormatException('Invalid homeserver URL');
      }

      state = ProvisioningState.bundleDecoded(bundle);
      return bundle;
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('Invalid provisioning bundle: $e');
    }
  }

  /// Configures Matrix sync from a decoded provisioning bundle.
  ///
  /// On desktop ([rotatePassword] = true): login -> join room -> rotate
  /// password -> generate handover QR data.
  /// On mobile ([rotatePassword] = false): login -> join room -> done.
  Future<void> configureFromBundle(
    SyncProvisioningBundle bundle, {
    bool rotatePassword = true,
  }) async {
    final matrixService = ref.read(matrixServiceProvider);

    try {
      // Step 1: Login
      state = const ProvisioningState.loggingIn();
      await matrixService.setConfig(
        MatrixConfig(
          homeServer: bundle.homeServer,
          user: bundle.user,
          password: bundle.password,
        ),
      );
      final loggedIn = await matrixService.login();
      if (!loggedIn) {
        state = const ProvisioningState.error('Login failed');
        return;
      }

      // Step 2: Join room
      state = const ProvisioningState.joiningRoom();
      await matrixService.joinRoom(bundle.roomId);
      await matrixService.saveRoom(bundle.roomId);

      // Step 3: Optionally rotate password (desktop only)
      if (!rotatePassword) {
        state = const ProvisioningState.done();
        return;
      }

      state = const ProvisioningState.rotatingPassword();
      final newPassword = _generateSecurePassword();
      await matrixService.changePassword(
        oldPassword: bundle.password,
        newPassword: newPassword,
      );

      // Step 4: Generate handover bundle
      final handoverBundle = SyncProvisioningBundle(
        v: bundle.v,
        homeServer: bundle.homeServer,
        user: bundle.user,
        password: newPassword,
        roomId: bundle.roomId,
      );
      final handoverJson = jsonEncode(handoverBundle.toJson());
      final handoverBase64 = base64UrlEncode(utf8.encode(handoverJson));

      state = ProvisioningState.ready(handoverBase64);
    } catch (e) {
      state = ProvisioningState.error(e.toString());
    }
  }

  /// Resets the controller to its initial state.
  void reset() {
    state = const ProvisioningState.initial();
  }

  /// Normalizes a Base64 string by adding padding if needed and converting
  /// URL-safe characters to standard Base64.
  static String _normalizeBase64(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    final remainder = normalized.length % 4;
    if (remainder != 0) {
      normalized =
          normalized.padRight(normalized.length + (4 - remainder), '=');
    }
    return normalized;
  }

  /// Generates a cryptographically secure random password.
  static String _generateSecurePassword() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }
}
