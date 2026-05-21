// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'change_set_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provides a [ChangeSetConfirmationService] with all dependencies resolved.

@ProviderFor(changeSetConfirmationService)
final changeSetConfirmationServiceProvider =
    ChangeSetConfirmationServiceProvider._();

/// Provides a [ChangeSetConfirmationService] with all dependencies resolved.

final class ChangeSetConfirmationServiceProvider
    extends
        $FunctionalProvider<
          ChangeSetConfirmationService,
          ChangeSetConfirmationService,
          ChangeSetConfirmationService
        >
    with $Provider<ChangeSetConfirmationService> {
  /// Provides a [ChangeSetConfirmationService] with all dependencies resolved.
  ChangeSetConfirmationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'changeSetConfirmationServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$changeSetConfirmationServiceHash();

  @$internal
  @override
  $ProviderElement<ChangeSetConfirmationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ChangeSetConfirmationService create(Ref ref) {
    return changeSetConfirmationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChangeSetConfirmationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChangeSetConfirmationService>(value),
    );
  }
}

String _$changeSetConfirmationServiceHash() =>
    r'18488f1f8bde1f183ad98d584b413d9c2bc2f457';
