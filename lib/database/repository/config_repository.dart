import 'package:lotti/database/database.dart';
import 'package:lotti/database/journal_db/config_flags.dart';

/// Repository interface for configuration operations
abstract class IConfigRepository {
  Future<bool> getFlag(String flagName);
  Stream<bool> watchFlag(String flagName);
  Stream<Set<String>> watchActiveFlagNames();
  Future<void> setFlag(String flagName, {required bool value});
  Future<void> toggleFlag(String flagName);
  Future<ConfigFlag?> getFlagByName(String flagName);
  Future<void> insertFlagIfNotExists(ConfigFlag flag);
}

/// Concrete implementation of config repository
class ConfigRepository implements IConfigRepository {
  ConfigRepository(this._db);

  final JournalDb _db;

  @override
  Future<bool> getFlag(String flagName) => _db.getConfigFlag(flagName);

  @override
  Stream<bool> watchFlag(String flagName) => _db.watchConfigFlag(flagName);

  @override
  Stream<Set<String>> watchActiveFlagNames() =>
      _db.watchActiveConfigFlagNames();

  @override
  Future<void> setFlag(String flagName, {required bool value}) =>
      _db.setConfigFlag(flagName, value: value);

  @override
  Future<void> toggleFlag(String flagName) => _db.toggleConfigFlag(flagName);

  @override
  Future<ConfigFlag?> getFlagByName(String flagName) =>
      _db.getConfigFlagByName(flagName);

  @override
  Future<void> insertFlagIfNotExists(ConfigFlag flag) =>
      _db.insertFlagIfNotExists(flag);
}
