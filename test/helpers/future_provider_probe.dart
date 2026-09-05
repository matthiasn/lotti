import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Observes the raw computation, including errors Riverpod discards after
/// disposal. Use with real container lifecycle changes and controlled futures
/// to avoid a vacuous "no provider error" assertion after invalidation.
class FutureProviderProbe<T> {
  FutureProviderProbe(FutureProvider<T> original) {
    provider = FutureProvider.autoDispose((ref) async {
      try {
        // The public provider future stops observing a disposed computation.
        // This test-only seam keeps observing its actual async work instead.
        // ignore: invalid_use_of_internal_member
        final result = await original.create(ref);
        results.add(result);
        return result;
      } catch (error) {
        errors.add(error);
        rethrow;
      }
    });
  }

  late final FutureProvider<T> provider;
  final results = <T>[];
  final errors = <Object>[];
}
