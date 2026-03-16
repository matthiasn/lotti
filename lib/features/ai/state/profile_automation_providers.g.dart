// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_automation_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(profileResolver)
final profileResolverProvider = ProfileResolverProvider._();

final class ProfileResolverProvider
    extends
        $FunctionalProvider<ProfileResolver, ProfileResolver, ProfileResolver>
    with $Provider<ProfileResolver> {
  ProfileResolverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileResolverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileResolverHash();

  @$internal
  @override
  $ProviderElement<ProfileResolver> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ProfileResolver create(Ref ref) {
    return profileResolver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileResolver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileResolver>(value),
    );
  }
}

String _$profileResolverHash() => r'fb5391b72dabad5494bf369ec6b23410448cd05b';

@ProviderFor(profileAutomationResolver)
final profileAutomationResolverProvider = ProfileAutomationResolverProvider._();

final class ProfileAutomationResolverProvider
    extends
        $FunctionalProvider<
          ProfileAutomationResolver,
          ProfileAutomationResolver,
          ProfileAutomationResolver
        >
    with $Provider<ProfileAutomationResolver> {
  ProfileAutomationResolverProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileAutomationResolverProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileAutomationResolverHash();

  @$internal
  @override
  $ProviderElement<ProfileAutomationResolver> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProfileAutomationResolver create(Ref ref) {
    return profileAutomationResolver(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileAutomationResolver value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileAutomationResolver>(value),
    );
  }
}

String _$profileAutomationResolverHash() =>
    r'e886ecc80bcb10cdd6f68940d8054cb815f01622';

@ProviderFor(profileAutomationService)
final profileAutomationServiceProvider = ProfileAutomationServiceProvider._();

final class ProfileAutomationServiceProvider
    extends
        $FunctionalProvider<
          ProfileAutomationService,
          ProfileAutomationService,
          ProfileAutomationService
        >
    with $Provider<ProfileAutomationService> {
  ProfileAutomationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profileAutomationServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profileAutomationServiceHash();

  @$internal
  @override
  $ProviderElement<ProfileAutomationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProfileAutomationService create(Ref ref) {
    return profileAutomationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfileAutomationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfileAutomationService>(value),
    );
  }
}

String _$profileAutomationServiceHash() =>
    r'cdae853b1374dc8bb4532686f54bae3fe2c9ff28';
