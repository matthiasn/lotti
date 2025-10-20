import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'config_flag_provider.g.dart';

/// Shared stream of all config flags, broadcast so multiple listeners can subscribe.
final configFlagsStreamProvider = Provider<Stream<Set<ConfigFlag>>>((ref) {
  final db = ref.watch(journalDbProvider);
  return db.watchConfigFlags().asBroadcastStream();
});

/// Provides a stream of the status (bool) for a specific config flag.
/// Returns false by default if the flag doesn't exist or has no status.
@riverpod
Stream<bool> configFlag(Ref ref, String flagName) {
  // Derive from the shared broadcast stream to avoid multiple subscriptions
  final flagsStream = ref.watch(configFlagsStreamProvider);
  return flagsStream.map((Set<ConfigFlag> flags) {
    final flag = flags.cast<ConfigFlag?>().firstWhere(
          (ConfigFlag? f) => f?.name == flagName,
          orElse: () => null,
        );
    return flag?.status ?? false;
  });
}
