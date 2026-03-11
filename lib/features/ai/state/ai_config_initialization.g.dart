// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_config_initialization.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Seeds default inference profiles and backfills known models on startup.
///
/// This runs independently of the agents feature flag so that all users
/// get up-to-date local model configs and seeded profiles.

@ProviderFor(aiConfigInitialization)
final aiConfigInitializationProvider = AiConfigInitializationProvider._();

/// Seeds default inference profiles and backfills known models on startup.
///
/// This runs independently of the agents feature flag so that all users
/// get up-to-date local model configs and seeded profiles.

final class AiConfigInitializationProvider
    extends $FunctionalProvider<AsyncValue<void>, void, FutureOr<void>>
    with $FutureModifier<void>, $FutureProvider<void> {
  /// Seeds default inference profiles and backfills known models on startup.
  ///
  /// This runs independently of the agents feature flag so that all users
  /// get up-to-date local model configs and seeded profiles.
  AiConfigInitializationProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiConfigInitializationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiConfigInitializationHash();

  @$internal
  @override
  $FutureProviderElement<void> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<void> create(Ref ref) {
    return aiConfigInitialization(ref);
  }
}

String _$aiConfigInitializationHash() =>
    r'f0c5fea0728f92cb37e494f1103fc067bd82049f';
