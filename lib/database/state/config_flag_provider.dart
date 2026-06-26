import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/providers/service_providers.dart';

/// Provides a stream of the status (bool) for a specific config flag.
/// Returns false by default if the flag doesn't exist or has no status.
final StreamProviderFamily<bool, String> configFlagProvider = StreamProvider
    .autoDispose
    .family<bool, String>(
      configFlag,
      name: 'configFlagProvider',
    );
Stream<bool> configFlag(Ref ref, String flagName) {
  final db = ref.watch(journalDbProvider);
  return db.watchConfigFlag(flagName);
}
