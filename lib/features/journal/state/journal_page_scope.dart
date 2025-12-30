import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scoped provider that holds the showTasks value for the current page subtree.
///
/// Must be overridden in a ProviderScope at the page level:
/// ```dart
/// ProviderScope(
///   overrides: [journalPageScopeProvider.overrideWithValue(showTasks)],
///   child: ...,
/// )
/// ```
///
/// Child widgets can then read:
/// ```dart
/// final showTasks = ref.watch(journalPageScopeProvider);
/// final controller = ref.read(journalPageControllerProvider(showTasks).notifier);
/// ```
final journalPageScopeProvider = Provider<bool>((ref) {
  throw UnimplementedError(
    'journalPageScopeProvider must be overridden in a ProviderScope',
  );
});
