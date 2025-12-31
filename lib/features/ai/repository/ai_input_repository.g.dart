// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_input_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(aiInputRepository)
final aiInputRepositoryProvider = AiInputRepositoryProvider._();

final class AiInputRepositoryProvider extends $FunctionalProvider<
    AiInputRepository,
    AiInputRepository,
    AiInputRepository> with $Provider<AiInputRepository> {
  AiInputRepositoryProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'aiInputRepositoryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$aiInputRepositoryHash();

  @$internal
  @override
  $ProviderElement<AiInputRepository> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AiInputRepository create(Ref ref) {
    return aiInputRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiInputRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiInputRepository>(value),
    );
  }
}

String _$aiInputRepositoryHash() => r'72356d962f33b02c178cb29e53700721881021e1';
