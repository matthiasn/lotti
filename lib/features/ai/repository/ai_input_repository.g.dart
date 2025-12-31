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
          isAutoDispose: false,
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

String _$aiInputRepositoryHash() => r'e51003db310e1baa103851d163173a2acf68976c';
