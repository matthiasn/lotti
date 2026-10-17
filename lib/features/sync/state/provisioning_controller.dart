import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:clock/clock.dart' as system_clock;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/database/logging_types.dart';
import 'package:lotti/features/provenance/crypto/ed25519.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/onboarding/onboarding_sync_service.dart';
import 'package:lotti/features/sync/state/bundle_attestation.dart';
import 'package:lotti/features/sync/state/bundle_decode_error.dart';
import 'package:lotti/features/sync/state/matrix_service_provider.dart';
import 'package:lotti/features/sync/state/provisioning_error.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';

part 'provisioning_controller.freezed.dart';

/// State machine for configuring sync on a new device — from a
/// provisioning/handover bundle, or from credentials typed by hand: from
/// [ProvisioningState.initial] through decode, login, room join or creation,
/// and (for `provisioned` bundles) password rotation to [ProvisioningState.done],
/// or [ProvisioningState.error]. [ProvisioningState.ready] carries a freshly
/// minted handover string for chaining a further device.
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
  const factory ProvisioningState.error(ProvisioningError error) = _Error;
}

/// Unsigned bundle schema version. Bumped from 1 to 2 when the `kind`
/// discriminator became required; [kSignedSyncBundleVersion] adds the
/// operator attestation.
const int kSyncBundleVersion = 2;

final NotifierProvider<ProvisioningController, ProvisioningState>
provisioningControllerProvider =
    NotifierProvider.autoDispose<ProvisioningController, ProvisioningState>(
      ProvisioningController.new,
      name: 'provisioningControllerProvider',
    );

class ProvisioningController extends Notifier<ProvisioningState> {
  ProvisioningController({
    OnboardingSyncService? onboardingSyncService,
    Future<Ed25519> Function()? ed25519Loader,
    this._trust = kLottiSyncBundleTrust,
    DateTime Function()? clock,
  }) : _injectedOnboardingSyncService = onboardingSyncService,
       _ed25519Loader = ed25519Loader ?? SodiumEd25519.bundled,
       // Read at call time so fake clocks installed by tests apply.
       _clock = clock ?? (() => system_clock.clock.now());

  final OnboardingSyncService? _injectedOnboardingSyncService;
  final Future<Ed25519> Function() _ed25519Loader;
  final BundleTrust _trust;
  final DateTime Function() _clock;
  SyncProvisioningBundle? _lastBundle;
  MatrixConfig? _lastCredentials;

  late DomainLogger _logger;

  @override
  ProvisioningState build() {
    _logger = ref.watch(domainLoggerProvider);
    return const ProvisioningState.initial();
  }

  /// Decodes a Base64-encoded provisioning bundle string.
  ///
  /// Accepts both padded and unpadded Base64url. Validates the bundle
  /// version, MXID format, room ID format, and homeserver URL. The `kind`
  /// discriminator is required — it determines whether this consumption
  /// rotates the password (`provisioned`) or joins without rotating
  /// (`handover`). v:1 bundles (which predate the discriminator) are
  /// rejected. A v:3 bundle must carry its attestation; whether that
  /// attestation is trusted is decided by [configureFromBundle], which needs
  /// the asynchronously loaded Ed25519 implementation.
  SyncProvisioningBundle decodeBundle(String base64String) {
    try {
      final normalized = _normalizeBase64(base64String.trim());
      final bytes = base64Decode(normalized);
      final jsonString = utf8.decode(bytes);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      final rawVersion = json['v'];
      if (rawVersion is! int) {
        // Never announced a version at all, so "update both devices" would be
        // a guess. The payload is simply not a pairing code.
        throw const BundleDecodeException(
          BundleDecodeError.malformedPayload,
          'Missing or non-integer bundle version',
        );
      }
      if (rawVersion != kSyncBundleVersion &&
          rawVersion != kSignedSyncBundleVersion) {
        // A real version this build does not speak: the devices are on
        // different Lotti releases. Reported separately because the remedy is
        // "update", not "get a fresh code".
        throw const BundleDecodeException(
          BundleDecodeError.unsupportedVersion,
          'Unsupported bundle version',
        );
      }
      if (json['kind'] is! String) {
        throw const BundleDecodeException(
          BundleDecodeError.malformedPayload,
          'Missing bundle kind discriminator',
        );
      }

      if (rawVersion == kSignedSyncBundleVersion && json['att'] is! Map) {
        throw const BundleDecodeException(
          BundleDecodeError.malformedPayload,
          'A v3 bundle must carry its attestation',
        );
      }

      final parsed = SyncProvisioningBundle.fromJson(json);
      // An attestation only means something in the schema that defines it;
      // a v2 bundle is treated as unsigned whatever else it carries.
      final bundle = rawVersion == kSyncBundleVersion
          ? parsed.copyWith(att: null)
          : parsed;

      if (!bundle.user.startsWith('@')) {
        throw const BundleDecodeException(
          BundleDecodeError.malformedPayload,
          'Invalid MXID: must start with @',
        );
      }
      if (!bundle.roomId.startsWith('!')) {
        throw const BundleDecodeException(
          BundleDecodeError.malformedPayload,
          'Invalid room ID: must start with !',
        );
      }
      if (!bundle.homeServer.startsWith('https://')) {
        throw const BundleDecodeException(
          BundleDecodeError.malformedPayload,
          'Invalid homeserver URL: must start with https://',
        );
      }

      state = ProvisioningState.bundleDecoded(bundle);
      return bundle;
    } on FormatException {
      rethrow;
    } catch (e) {
      throw BundleDecodeException(
        BundleDecodeError.malformedPayload,
        'Invalid provisioning bundle: $e',
      );
    }
  }

  /// Configures Matrix sync from a decoded provisioning bundle.
  ///
  /// The flow is determined by [SyncProvisioningBundle.kind]:
  /// * `provisioned` (fresh CLI bundle) → login → join room → rotate
  ///   password → emit `ready(handoverBase64)` so the user can hand off
  ///   the rotated credential to further devices.
  /// * `handover` (bundle from a peer) → login → join room → `done`.
  ///   The password is *not* rotated — every peer shares the same live
  ///   credential.
  Future<void> configureFromBundle(SyncProvisioningBundle bundle) async {
    _lastBundle = bundle;
    _lastCredentials = null;
    final rotatePassword = bundle.kind == SyncBundleKind.provisioned;

    // Read dependencies eagerly and prevent auto-disposal while this async
    // operation is in-flight. Without keepAlive(), a page transition (e.g.
    // bundle-import → config) can briefly leave zero watchers, causing
    // Riverpod to dispose the controller mid-operation.
    final link = ref.keepAlive();
    final matrixService = ref.read(matrixServiceProvider);
    final loggingService = _logger;
    final onboardingSyncService = rotatePassword
        ? null
        : _injectedOnboardingSyncService ?? getIt<OnboardingSyncService>();
    String? inboundPreflightRoundId;

    try {
      // Step 1: Login
      state = const ProvisioningState.loggingIn();

      // Before anything touches the current session: a forged or phishing
      // bundle must not even log the existing account out.
      try {
        // libsodium is only needed to check a signature; an unsigned bundle
        // for a self-hosted server pairs without it, as it always did.
        BundleAttestationVerifier(
          ed25519: bundle.att == null ? null : await _ed25519Loader(),
          trust: _trust,
        ).verify(bundle, now: _clock());
      } on UntrustedBundleException catch (e) {
        loggingService.log(
          LogDomain.sync,
          'Refused untrusted bundle: ${e.failure.name}',
          subDomain: 'configureFromBundle.verify',
          level: InsightLevel.warn,
        );
        state = const ProvisioningState.error(
          ProvisioningError.untrustedBundle,
        );
        return;
      }

      final oldConfig = await matrixService.loadConfig();
      final oldRoomId = await matrixService.getRoom();

      // Persist the gate before changing the current Matrix session. A failed
      // preflight therefore leaves the existing account connected, while a
      // successful one is already durable before login can start background
      // lifecycle processing and gap detection.
      if (onboardingSyncService != null) {
        inboundPreflightRoundId = await onboardingSyncService
            .beginInboundPreflight(
              recipientUserId: bundle.user,
            );
      }

      final newConfig = MatrixConfig(
        homeServer: bundle.homeServer,
        user: bundle.user,
        password: bundle.password,
        attestation: bundle.att,
      );
      final loggedIn = await _switchSession(matrixService, newConfig);
      if (!loggedIn) {
        await _cancelInboundPreflight(
          onboardingSyncService,
          inboundPreflightRoundId,
          loggingService,
        );
        inboundPreflightRoundId = null;
        // Restore previous config and reconnect so the user does not end up
        // disconnected after a failed provisioning attempt.
        await _restorePreviousSession(matrixService, oldConfig, oldRoomId);
        state = const ProvisioningState.error(ProvisioningError.loginFailed);
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

      // Step 4: Generate handover bundle. Tagged as `handover` so the
      // next device consuming it joins without rotating the password.
      final handoverBundle = _handoverBundle(
        homeServer: bundle.homeServer,
        user: bundle.user,
        password: newPassword,
        roomId: bundle.roomId,
        attestation: bundle.att,
      );
      state = ProvisioningState.ready(_encodeBundle(handoverBundle));
    } catch (e, stackTrace) {
      loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: stackTrace,
        subDomain: 'configureFromBundle',
      );
      await _cancelInboundPreflight(
        onboardingSyncService,
        inboundPreflightRoundId,
        loggingService,
      );
      state = const ProvisioningState.error(
        ProvisioningError.configurationError,
      );
    } finally {
      link.close();
    }
  }

  /// Signs in with [config] and configures sync around the account's *own*
  /// sync room — the Linux path for an account's first device when no
  /// pairing code exists yet (GitHub #4055).
  ///
  /// Login, then use the account's existing sync room — the one its other
  /// devices use — or create the encrypted sync room when it has none, and
  /// persist it, then `ready`. Creating one unconditionally split an account
  /// whose devices were already syncing into two rooms that never met. The
  /// password is the user's own and is **never rotated**: rotation exists to
  /// spend a one-time CLI bundle, and here there is no bundle — only a
  /// credential the user manages themselves. A failed login restores
  /// whatever session was active before.
  Future<void> configureFromCredentials(MatrixConfig config) async {
    _lastCredentials = config;
    _lastBundle = null;

    final link = ref.keepAlive();
    final matrixService = ref.read(matrixServiceProvider);
    final loggingService = _logger;

    try {
      state = const ProvisioningState.loggingIn();

      final oldConfig = await matrixService.loadConfig();
      final oldRoomId = await matrixService.getRoom();

      final loggedIn = await _switchSession(matrixService, config);
      if (!loggedIn) {
        await _restorePreviousSession(matrixService, oldConfig, oldRoomId);
        state = const ProvisioningState.error(ProvisioningError.loginFailed);
        return;
      }

      state = const ProvisioningState.joiningRoom();
      final existing = await matrixService.findSyncRoom();
      // Joining the room found applies what a sync room needs, such as its
      // retention policy; the account is already a member.
      if (existing != null) await matrixService.joinRoom(existing);
      final roomId = existing ?? await matrixService.createRoom();
      await matrixService.saveRoom(roomId);

      final handoverBundle = _handoverBundle(
        homeServer: config.homeServer,
        user: config.user,
        password: config.password,
        roomId: roomId,
        attestation: config.attestation,
      );
      state = ProvisioningState.ready(_encodeBundle(handoverBundle));
    } catch (e, stackTrace) {
      loggingService.error(
        LogDomain.sync,
        e,
        stackTrace: stackTrace,
        subDomain: 'configureFromCredentials',
      );
      state = const ProvisioningState.error(
        ProvisioningError.configurationError,
      );
    } finally {
      link.close();
    }
  }

  /// Replaces the live Matrix session with one for [config] and reports
  /// whether the credential login succeeded.
  ///
  /// Logs out first, so the session manager actually attempts a credential
  /// login instead of silently reusing the current session, and clears the
  /// persisted room pointer before the credentials change so reconnecting
  /// cannot auto-join a room that belongs to the previous account.
  Future<bool> _switchSession(
    MatrixService matrixService,
    MatrixConfig config,
  ) async {
    if (matrixService.isLoggedIn()) {
      await matrixService.logout();
    }
    await matrixService.clearPersistedRoom();
    await matrixService.setConfig(config);
    return matrixService.login(waitForLifecycle: false);
  }

  Future<void> _cancelInboundPreflight(
    OnboardingSyncService? service,
    String? roundId,
    DomainLogger loggingService,
  ) async {
    if (service == null || roundId == null) return;
    try {
      await service.cancelInboundPreflight(roundId);
    } catch (error, stackTrace) {
      loggingService.error(
        LogDomain.sync,
        error,
        stackTrace: stackTrace,
        subDomain: 'configureFromBundle.cancelPreflight',
      );
    }
  }

  Future<void> _restorePreviousSession(
    MatrixService matrixService,
    MatrixConfig? oldConfig,
    String? oldRoomId,
  ) async {
    if (oldConfig == null) {
      await matrixService.deleteConfig();
      return;
    }
    await matrixService.setConfig(oldConfig);
    if (oldRoomId != null) {
      await matrixService.saveRoom(oldRoomId);
    }
    await matrixService.login(waitForLifecycle: false);
  }

  /// Resets the controller to its initial state.
  void reset() {
    _lastBundle = null;
    _lastCredentials = null;
    state = const ProvisioningState.initial();
  }

  /// Regenerates a handover QR payload from the persisted Matrix config.
  ///
  /// Returns the Base64url-encoded provisioning bundle, or `null` when no
  /// config or room ID is available. This allows desktop users to re-display
  /// the QR code after closing and reopening the sync settings modal.
  Future<String?> regenerateHandover() async {
    final matrixService = ref.read(matrixServiceProvider);
    final config = await matrixService.loadConfig();
    final roomId = matrixService.syncRoomId;
    if (config == null || roomId == null) return null;

    return _encodeBundle(
      _handoverBundle(
        homeServer: config.homeServer,
        user: config.user,
        password: config.password,
        roomId: roomId,
        attestation: config.attestation,
      ),
    );
  }

  /// A handover for the next device: v3 carrying the account's attestation
  /// when it has one, so an operator homeserver accepts it, else v2.
  static SyncProvisioningBundle _handoverBundle({
    required String homeServer,
    required String user,
    required String password,
    required String roomId,
    required BundleAttestation? attestation,
  }) => SyncProvisioningBundle(
    v: attestation == null ? kSyncBundleVersion : kSignedSyncBundleVersion,
    kind: SyncBundleKind.handover,
    homeServer: homeServer,
    user: user,
    password: password,
    roomId: roomId,
    att: attestation,
  );

  /// The wire form of a bundle: its JSON, Base64url-encoded.
  static String _encodeBundle(SyncProvisioningBundle bundle) =>
      base64UrlEncode(utf8.encode(jsonEncode(bundle.toJson())));

  /// Retries the last configuration attempt.
  ///
  /// Only meaningful when the current state is [ProvisioningState.error].
  /// Re-uses the bundle from the last [configureFromBundle] call — rotation
  /// behaviour is derived from the bundle's `kind` — or the credentials from
  /// the last [configureFromCredentials] call, whichever came last.
  Future<void> retry() async {
    final bundle = _lastBundle;
    if (bundle != null) {
      await configureFromBundle(bundle);
      return;
    }
    final credentials = _lastCredentials;
    if (credentials != null) {
      await configureFromCredentials(credentials);
    }
  }

  /// Normalizes a Base64 string by adding padding if needed and converting
  /// URL-safe characters to standard Base64.
  static String _normalizeBase64(String input) {
    var normalized = input.replaceAll('-', '+').replaceAll('_', '/');
    final remainder = normalized.length % 4;
    if (remainder != 0) {
      normalized = normalized.padRight(
        normalized.length + (4 - remainder),
        '=',
      );
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
