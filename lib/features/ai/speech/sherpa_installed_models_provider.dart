import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/speech/sherpa_model_repository.dart';

/// Device-local readiness, refreshed after explicit model changes. Synced
/// configuration rows are not evidence that this device can transcribe.
final sherpaInstalledModelIdsProvider = FutureProvider<Set<String>>((
  ref,
) async {
  final repository = ref.watch(sherpaModelRepositoryProvider);
  final installed = <String>{};
  for (final model in repository.models) {
    if (await repository.isAvailable(model.id)) installed.add(model.id);
  }
  return installed;
});
