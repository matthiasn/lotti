import 'package:lotti/providers/service_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'config_flag_provider.g.dart';

/// Provides a stream of the status (bool) for a specific config flag.
/// Returns false by default if the flag doesn't exist or has no status.
@riverpod
Stream<bool> configFlag(Ref ref, String flagName) {
  final db = ref.watch(journalDbProvider);
  return db.watchConfigFlag(flagName);
}
