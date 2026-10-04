import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';

/// Provides the configured [MatrixService]. Must be overridden in [ProviderScope].
final matrixServiceProvider = Provider<MatrixService>(
  (ref) => throw UnimplementedError(
    'matrixServiceProvider must be overridden before use.',
  ),
  name: 'matrixServiceProvider',
);
