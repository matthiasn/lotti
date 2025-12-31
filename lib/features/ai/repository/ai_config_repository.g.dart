// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_config_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiConfigRepository)
final aiConfigRepositoryProvider = AiConfigRepositoryProvider._();

final class AiConfigRepositoryProvider extends $FunctionalProvider<
    AiConfigRepository,
    AiConfigRepository,
    AiConfigRepository> with $Provider<AiConfigRepository> {
  AiConfigRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'aiConfigRepositoryProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$aiConfigRepositoryHash();

  @$internal
  @override
  $ProviderElement<AiConfigRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AiConfigRepository create(Ref ref) {
    return aiConfigRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiConfigRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiConfigRepository>(value),
    );
  }
}

String _$aiConfigRepositoryHash() =>
    r'5b73533a1244a647454ee5fe18ac987e91ec18e3';
