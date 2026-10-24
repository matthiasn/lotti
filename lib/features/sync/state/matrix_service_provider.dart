import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/sync_service.dart';

/// Provides the configured [SyncService] — `MatrixService` in-process, the
/// sync isolate's proxy with `use_isolate_sync` on. Must be overridden in
/// [ProviderScope].
final matrixServiceProvider = Provider<SyncService>(
  (ref) => throw UnimplementedError(
    'matrixServiceProvider must be overridden before use.',
  ),
  name: 'matrixServiceProvider',
);
