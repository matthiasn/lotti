// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_model_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides the model repository — the Hugging Face downloader in production;
/// tests override it with a fake.

@ProviderFor(ttsModelRepository)
final ttsModelRepositoryProvider = TtsModelRepositoryProvider._();

/// Provides the model repository — the Hugging Face downloader in production;
/// tests override it with a fake.

final class TtsModelRepositoryProvider
    extends
        $FunctionalProvider<
          TtsModelRepository,
          TtsModelRepository,
          TtsModelRepository
        >
    with $Provider<TtsModelRepository> {
  /// Provides the model repository — the Hugging Face downloader in production;
  /// tests override it with a fake.
  TtsModelRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ttsModelRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ttsModelRepositoryHash();

  @$internal
  @override
  $ProviderElement<TtsModelRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TtsModelRepository create(Ref ref) {
    return ttsModelRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TtsModelRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TtsModelRepository>(value),
    );
  }
}

String _$ttsModelRepositoryHash() =>
    r'18ad7554e51706b03d07fe99b851bfe2495a6fce';
