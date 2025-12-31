// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_prompt_setup_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for [ProviderPromptSetupService].

@ProviderFor(providerPromptSetupService)
final providerPromptSetupServiceProvider =
    ProviderPromptSetupServiceProvider._();

/// Provider for [ProviderPromptSetupService].

final class ProviderPromptSetupServiceProvider extends $FunctionalProvider<
    ProviderPromptSetupService,
    ProviderPromptSetupService,
    ProviderPromptSetupService> with $Provider<ProviderPromptSetupService> {
  /// Provider for [ProviderPromptSetupService].
  ProviderPromptSetupServiceProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'providerPromptSetupServiceProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$providerPromptSetupServiceHash();

  @$internal
  @override
  $ProviderElement<ProviderPromptSetupService> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ProviderPromptSetupService create(Ref ref) {
    return providerPromptSetupService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProviderPromptSetupService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProviderPromptSetupService>(value),
    );
  }
}

String _$providerPromptSetupServiceHash() =>
    r'7f4934b665d1a00e29f5fc63c6a09310538bebf1';
