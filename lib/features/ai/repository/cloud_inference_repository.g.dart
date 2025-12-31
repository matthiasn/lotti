// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cloud_inference_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(cloudInferenceRepository)
final cloudInferenceRepositoryProvider = CloudInferenceRepositoryProvider._();

final class CloudInferenceRepositoryProvider extends $FunctionalProvider<
    CloudInferenceRepository,
    CloudInferenceRepository,
    CloudInferenceRepository> with $Provider<CloudInferenceRepository> {
  CloudInferenceRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'cloudInferenceRepositoryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$cloudInferenceRepositoryHash();

  @$internal
  @override
  $ProviderElement<CloudInferenceRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CloudInferenceRepository create(Ref ref) {
    return cloudInferenceRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CloudInferenceRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CloudInferenceRepository>(value),
    );
  }
}

String _$cloudInferenceRepositoryHash() =>
    r'3223bed2333313813c785dada91b960d0205de38';
