import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'config_flag_provider.g.dart';

/// Provides a stream of the status (bool) for a specific config flag.
/// Returns false by default if the flag doesn't exist or has no status.
@riverpod
Stream<bool> configFlag(Ref ref, String flagName) {
  final db = ref.watch(journalDbProvider);
  return db.watchConfigFlags().map((Set<ConfigFlag> flags) {
    final flag = flags.cast<ConfigFlag?>().firstWhere(
          (ConfigFlag? f) => f?.name == flagName,
          orElse: () => null,
        );
    return flag?.status ?? false;
  });
}
