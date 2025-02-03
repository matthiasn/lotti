// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_paste_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$imagePasteControllerHash() =>
    r'5b545dd1cbc757ecba3b2231fecc8c374725f380';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

abstract class _$ImagePasteController
    extends BuildlessAutoDisposeAsyncNotifier<bool> {
  late final String? linkedFromId;
  late final String? categoryId;

  FutureOr<bool> build({
    required String? linkedFromId,
    required String? categoryId,
  });
}

/// See also [ImagePasteController].
@ProviderFor(ImagePasteController)
const imagePasteControllerProvider = ImagePasteControllerFamily();

/// See also [ImagePasteController].
class ImagePasteControllerFamily extends Family<AsyncValue<bool>> {
  /// See also [ImagePasteController].
  const ImagePasteControllerFamily();

  /// See also [ImagePasteController].
  ImagePasteControllerProvider call({
    required String? linkedFromId,
    required String? categoryId,
  }) {
    return ImagePasteControllerProvider(
      linkedFromId: linkedFromId,
      categoryId: categoryId,
    );
  }

  @override
  ImagePasteControllerProvider getProviderOverride(
    covariant ImagePasteControllerProvider provider,
  ) {
    return call(
      linkedFromId: provider.linkedFromId,
      categoryId: provider.categoryId,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'imagePasteControllerProvider';
}

/// See also [ImagePasteController].
class ImagePasteControllerProvider
    extends AutoDisposeAsyncNotifierProviderImpl<ImagePasteController, bool> {
  /// See also [ImagePasteController].
  ImagePasteControllerProvider({
    required String? linkedFromId,
    required String? categoryId,
  }) : this._internal(
          () => ImagePasteController()
            ..linkedFromId = linkedFromId
            ..categoryId = categoryId,
          from: imagePasteControllerProvider,
          name: r'imagePasteControllerProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$imagePasteControllerHash,
          dependencies: ImagePasteControllerFamily._dependencies,
          allTransitiveDependencies:
              ImagePasteControllerFamily._allTransitiveDependencies,
          linkedFromId: linkedFromId,
          categoryId: categoryId,
        );

  ImagePasteControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.linkedFromId,
    required this.categoryId,
  }) : super.internal();

  final String? linkedFromId;
  final String? categoryId;

  @override
  FutureOr<bool> runNotifierBuild(
    covariant ImagePasteController notifier,
  ) {
    return notifier.build(
      linkedFromId: linkedFromId,
      categoryId: categoryId,
    );
  }

  @override
  Override overrideWith(ImagePasteController Function() create) {
    return ProviderOverride(
      origin: this,
      override: ImagePasteControllerProvider._internal(
        () => create()
          ..linkedFromId = linkedFromId
          ..categoryId = categoryId,
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        linkedFromId: linkedFromId,
        categoryId: categoryId,
      ),
    );
  }

  @override
  AutoDisposeAsyncNotifierProviderElement<ImagePasteController, bool>
      createElement() {
    return _ImagePasteControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ImagePasteControllerProvider &&
        other.linkedFromId == linkedFromId &&
        other.categoryId == categoryId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, linkedFromId.hashCode);
    hash = _SystemHash.combine(hash, categoryId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ImagePasteControllerRef on AutoDisposeAsyncNotifierProviderRef<bool> {
  /// The parameter `linkedFromId` of this provider.
  String? get linkedFromId;

  /// The parameter `categoryId` of this provider.
  String? get categoryId;
}

class _ImagePasteControllerProviderElement
    extends AutoDisposeAsyncNotifierProviderElement<ImagePasteController, bool>
    with ImagePasteControllerRef {
  _ImagePasteControllerProviderElement(super.provider);

  @override
  String? get linkedFromId =>
      (origin as ImagePasteControllerProvider).linkedFromId;
  @override
  String? get categoryId => (origin as ImagePasteControllerProvider).categoryId;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
