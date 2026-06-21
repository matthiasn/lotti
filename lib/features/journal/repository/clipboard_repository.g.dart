// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clipboard_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The platform [SystemClipboard] (null where unsupported), wrapped in a
/// provider so clipboard access can be overridden in tests. Used by the
/// image-paste flow to detect and read pasteable images.

@ProviderFor(clipboardRepository)
final clipboardRepositoryProvider = ClipboardRepositoryProvider._();

/// The platform [SystemClipboard] (null where unsupported), wrapped in a
/// provider so clipboard access can be overridden in tests. Used by the
/// image-paste flow to detect and read pasteable images.

final class ClipboardRepositoryProvider
    extends
        $FunctionalProvider<
          SystemClipboard?,
          SystemClipboard?,
          SystemClipboard?
        >
    with $Provider<SystemClipboard?> {
  /// The platform [SystemClipboard] (null where unsupported), wrapped in a
  /// provider so clipboard access can be overridden in tests. Used by the
  /// image-paste flow to detect and read pasteable images.
  ClipboardRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clipboardRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clipboardRepositoryHash();

  @$internal
  @override
  $ProviderElement<SystemClipboard?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SystemClipboard? create(Ref ref) {
    return clipboardRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SystemClipboard? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SystemClipboard?>(value),
    );
  }
}

String _$clipboardRepositoryHash() =>
    r'eb05e5d6d99885a2f58405d5da7a86fa23c54c12';
