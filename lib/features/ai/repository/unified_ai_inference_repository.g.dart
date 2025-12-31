// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unified_ai_inference_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(unifiedAiInferenceRepository)
final unifiedAiInferenceRepositoryProvider =
    UnifiedAiInferenceRepositoryProvider._();

final class UnifiedAiInferenceRepositoryProvider extends $FunctionalProvider<
    UnifiedAiInferenceRepository,
    UnifiedAiInferenceRepository,
    UnifiedAiInferenceRepository> with $Provider<UnifiedAiInferenceRepository> {
  UnifiedAiInferenceRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'unifiedAiInferenceRepositoryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$unifiedAiInferenceRepositoryHash();

  @$internal
  @override
  $ProviderElement<UnifiedAiInferenceRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UnifiedAiInferenceRepository create(Ref ref) {
    return unifiedAiInferenceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UnifiedAiInferenceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UnifiedAiInferenceRepository>(value),
    );
  }
}

String _$unifiedAiInferenceRepositoryHash() =>
    r'af4642cc72b01bec46157b65e5faa2b770993f2f';
