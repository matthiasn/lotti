// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dashscope_inference_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(dashScopeInferenceRepository)
final dashScopeInferenceRepositoryProvider =
    DashScopeInferenceRepositoryProvider._();

final class DashScopeInferenceRepositoryProvider extends $FunctionalProvider<
    DashScopeInferenceRepository,
    DashScopeInferenceRepository,
    DashScopeInferenceRepository> with $Provider<DashScopeInferenceRepository> {
  DashScopeInferenceRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'dashScopeInferenceRepositoryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$dashScopeInferenceRepositoryHash();

  @$internal
  @override
  $ProviderElement<DashScopeInferenceRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DashScopeInferenceRepository create(Ref ref) {
    return dashScopeInferenceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DashScopeInferenceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DashScopeInferenceRepository>(value),
    );
  }
}

String _$dashScopeInferenceRepositoryHash() =>
    r'e3f21359d72ce546f12ec732f65b69e814ee397f';
