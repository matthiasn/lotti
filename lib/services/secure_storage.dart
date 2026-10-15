import 'dart:convert';
import 'dart:io';

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
///   secret containing one when it reloads its file. A value stored raw by an
///   earlier version is rewritten encoded the first time it is read.
/// - Before every write or delete the bundle is read back; a key this process
///   knows to be stored but finds missing is written back from the cache
///   first, so a blanked bundle is repaired instead of overwritten with the
///   one key being written.
///
/// Writes, deletes and cache-missing reads run one at a time, so a repair
/// never resurrects a key a concurrent delete just removed.
class SecureStorage {
  SecureStorage({bool? singleBundle, this._logging})
    : singleBundle = singleBundle ?? Platform.isLinux;

  /// Marks a value stored base64url-encoded. Nothing stored raw starts with
  /// it: the values are JSON objects, API keys and tokens.
  @visibleForTesting
  static const encodedPrefix = 'lotti-b64:';

  /// Whether the platform keeps every key in one shared item (Linux).
  final bool singleBundle;

  final DomainLogger? _logging;
  final _storage = const FlutterSecureStorage();
  final _state = <String, String>{};
  Future<void> _mutations = Future<void>.value();

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
      final value = stored.startsWith(encodedPrefix)
          ? utf8.decode(
              base64Url.decode(stored.substring(encodedPrefix.length)),
            )
          : stored;
      _state[key] = value;
      if (_encoded(value) != stored) await _put(key, value);
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
    await _storage.delete(
      key: key,
      iOptions: await _iOptions(),
      mOptions: await _mOptions(),
    );
  }

  Future<void> _put(String key, String value) async {
    await _storage.write(
      key: key,
      value: _encoded(value),
      iOptions: await _iOptions(),
      mOptions: await _mOptions(),
    );
  }

  /// [value] as stored: encoded when [singleBundle] and the bundle's JSON
  /// would escape one of its characters, raw otherwise.
  String _encoded(String value) {
    if (!singleBundle || !value.codeUnits.any(_escapedInJson)) return value;
    return '$encodedPrefix${base64Url.encode(utf8.encode(value))}';
  }

  static bool _escapedInJson(int unit) =>
      unit < 0x20 || unit == 0x22 || unit == 0x5c;

  Future<T> _serially<T>(Future<T> Function() body) {
    final result = _mutations.then((_) => body());
    _mutations = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<IOSOptions> _iOptions() async =>
      IOSOptions(accountName: (await PackageInfo.fromPlatform()).packageName);

  Future<MacOsOptions> _mOptions() async =>
      MacOsOptions(accountName: (await PackageInfo.fromPlatform()).packageName);
}
