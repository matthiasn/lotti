import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:meta/meta.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Read-through cache over the platform keychain ([FlutterSecureStorage]) for
/// secrets: the Matrix config JSON, inference-provider API keys, the GitHub
/// account record.
///
/// Values are namespaced by the app's package name (iOS/macOS `accountName`)
/// so multiple build flavours do not collide in the shared keychain. The
/// in-memory [_state] map caches the first read of each key for the process
/// lifetime; [writeValue] deletes before writing to keep the cache and the
/// backing store consistent.
///
/// On Linux the plugin keeps every key in **one** libsecret item, a JSON
/// object, so one bad read there loses all of them (#4789). Two guards apply
/// when [singleBundle] is set:
///
/// - A value the bundle's JSON would escape (a quote, a backslash, a control
///   character) is stored base64url-encoded behind [encodedPrefix], so the
///   bundle never holds a backslash: an unencrypted gnome-keyring blanks any
///   secret containing one when it reloads its file. Every value an earlier
///   version stored raw is rewritten encoded before the first access, whether
///   it is ever read or not.
/// - Before every write or delete the bundle is read back; a key this process
///   knows to be stored but finds missing is written back from the cache
///   first, so a blanked bundle is repaired instead of overwritten with the
///   one key being written.
///
/// Writes, deletes and cache-missing reads run one at a time, so a repair
/// never resurrects a key a concurrent delete just removed.
class SecureStorage {
  SecureStorage({
    bool? singleBundle,
    this._logging,
    @visibleForTesting FlutterSecureStorage? storage,
    @visibleForTesting bool? loginKeychain,
  }) : singleBundle = singleBundle ?? Platform.isLinux,
       _storage = storage ?? const FlutterSecureStorage(),
       _loginKeychain = loginKeychain ?? (Platform.isMacOS && kDebugMode);

  /// Marks a value stored base64url-encoded, on a [singleBundle] keystore
  /// only. A value that itself starts with it is encoded too, so a read never
  /// mistakes it; elsewhere nothing is encoded and nothing decoded.
  @visibleForTesting
  static const encodedPrefix = 'lotti-b64:';

  /// Whether the platform keeps every key in one shared item (Linux).
  final bool singleBundle;

  final DomainLogger? _logging;
  final FlutterSecureStorage _storage;

  /// Whether this process keeps its secrets in the macOS login keychain: a
  /// Debug build there ([macOsOptions]).
  final bool _loginKeychain;
  final _state = <String, String>{};
  Future<void> _mutations = Future<void>.value();
  bool _migrated = false;

  /// Returns the value for [key], reading from the keychain on a cache miss
  /// and memoising the result. `null` when the key is absent in both the cache
  /// and the keychain.
  ///
  /// A cache miss waits for pending writes and deletes, so it never caches a
  /// value one of them is replacing or removing.
  Future<String?>? readValue(String key) async {
    final cached = _state[key];
    if (cached != null) return cached;

    return _serially(() async {
      final stored = await _storage.read(
        key: key,
        iOptions: await _iOptions(),
        mOptions: await _mOptions(),
      );
      if (stored == null) return null;
      final value = singleBundle && stored.startsWith(encodedPrefix)
          ? utf8.decode(
              base64Url.decode(stored.substring(encodedPrefix.length)),
            )
          : stored;
      _state[key] = value;
      return value;
    });
  }

  Future<String?>? read({required String key}) async {
    return readValue(key);
  }

  /// Persists [value] under [key] in both the in-memory cache and the
  /// keychain, deleting any prior entry first so the two stay in sync.
  Future<void> writeValue(String key, String value) => _serially(() async {
    await _repairBundle();
    await _remove(key);
    _state[key] = value;
    await _put(key, value);
  });

  Future<void> write({
    required String key,
    required String value,
  }) async {
    await writeValue(key, value);
  }

  /// Removes [key] from both the in-memory cache and the keychain.
  Future<void> delete({required String key}) => _serially(() async {
    await _repairBundle();
    await _remove(key);
  });

  /// Writes back every cached key the bundle no longer holds. A no-op unless
  /// [singleBundle]; nothing is missing in the common case.
  Future<void> _repairBundle() async {
    if (!singleBundle || _state.isEmpty) return;
    final stored = await _storage.readAll(
      iOptions: await _iOptions(),
      mOptions: await _mOptions(),
    );
    final missing = _state.keys.where((key) => !stored.containsKey(key));
    if (missing.isEmpty) return;
    final keys = missing.toList();
    _logging?.error(
      LogDomain.persistence,
      StateError('secure storage bundle lost ${keys.length} key(s)'),
      subDomain: 'secureStorage.repair',
      message: 'Restored ${keys.length} of ${_state.length} cached keys',
    );
    for (final key in keys) {
      await _put(key, _state[key]!);
    }
  }

  Future<void> _remove(String key) async {
    _state.remove(key);
    try {
      await _storage.delete(
        key: key,
        iOptions: await _iOptions(),
        mOptions: await _mOptions(),
      );
    } on PlatformException catch (error) {
      if (!refusedOnlyAsSynchronizable(error, loginKeychain: _loginKeychain)) {
        rethrow;
      }
    }
  }

  /// Whether a failed delete only means its iCloud half was refused, so
  /// nothing of the key is left on this device.
  ///
  /// The plugin deletes twice, as a synchronizable item and as a local one,
  /// and reports the first failure. A synchronizable item lives only in the
  /// data protection keychain, which a [loginKeychain] build cannot reach:
  /// that half answers -34018 (errSecMissingEntitlement) on every call, and
  /// when the local half found nothing the plugin reports the -34018 — so
  /// every delete, and every write, which deletes first, failed. Measured
  /// with an ad-hoc signed sandboxed app on 2026-11-02: the synchronizable
  /// delete of a missing item answers -34018, the local one -25300.
  @visibleForTesting
  static bool refusedOnlyAsSynchronizable(
    PlatformException error, {
    required bool loginKeychain,
  }) => loginKeychain && error.details == _errSecMissingEntitlement;

  static const _errSecMissingEntitlement = -34018;

  Future<void> _put(String key, String value) async {
    await _storage.write(
      key: key,
      value: _encoded(value),
      iOptions: await _iOptions(),
      mOptions: await _mOptions(),
    );
  }

  /// Rewrites every value an earlier version stored raw that the bundle's
  /// JSON escapes — read or not, any profile's — so the bundle holds no
  /// backslash. Runs once per instance, before its first keystore access; a
  /// failed pass is tried again on the next one.
  Future<void> _migrateBundle() async {
    if (!singleBundle || _migrated) return;
    final stored = await _storage.readAll(
      iOptions: await _iOptions(),
      mOptions: await _mOptions(),
    );
    for (final MapEntry(:key, :value) in stored.entries) {
      if (!value.startsWith(encodedPrefix) && _encoded(value) != value) {
        await _put(key, value);
      }
    }
    _migrated = true;
  }

  /// [value] as stored: encoded when [singleBundle] and the bundle's JSON
  /// would escape one of its characters, or it starts with [encodedPrefix]
  /// so a read would take it for encoded; raw otherwise.
  String _encoded(String value) {
    if (!singleBundle ||
        !value.startsWith(encodedPrefix) &&
            !value.codeUnits.any(_escapedInJson)) {
      return value;
    }
    return '$encodedPrefix${base64Url.encode(utf8.encode(value))}';
  }

  static bool _escapedInJson(int unit) =>
      unit < 0x20 || unit == 0x22 || unit == 0x5c;

  /// Runs [body] after every keystore access queued before it, migrating the
  /// bundle first if this instance has not yet.
  Future<T> _serially<T>(Future<T> Function() body) {
    final result = _mutations.then((_) async {
      await _migrateBundle();
      return body();
    });
    _mutations = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<IOSOptions> _iOptions() async =>
      IOSOptions(accountName: (await PackageInfo.fromPlatform()).packageName);

  Future<MacOsOptions> _mOptions() async => macOsOptions(
    accountName: (await PackageInfo.fromPlatform()).packageName,
    debugBuild: kDebugMode,
  );

  /// The macOS keychain options for [accountName].
  ///
  /// The data protection keychain needs the `keychain-access-groups`
  /// entitlement, which only a team-signed build carries (Profile, Release).
  /// The Debug build is signed to run locally, with no team and no keychain
  /// group (`RunnerDebug.entitlements`), and that keychain refuses it on every
  /// call (-34018, errSecMissingEntitlement): no API key could be saved, and
  /// deleting a provider failed on removing its key. A [debugBuild] uses the
  /// login keychain instead, which a sandboxed app may use for its own items.
  /// No Debug build ever stored a key in the other one, so none is lost.
  @visibleForTesting
  static MacOsOptions macOsOptions({
    required String accountName,
    required bool debugBuild,
  }) => MacOsOptions(
    accountName: accountName,
    usesDataProtectionKeychain: !debugBuild,
  );
}
