// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'image_paste_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ImagePasteController)
final imagePasteControllerProvider = ImagePasteControllerFamily._();

final class ImagePasteControllerProvider
    extends $AsyncNotifierProvider<ImagePasteController, bool> {
  ImagePasteControllerProvider._(
      {required ImagePasteControllerFamily super.from,
      required ({
        String? linkedFromId,
        String? categoryId,
      })
          super.argument})
      : super(
          retry: null,
          name: r'imagePasteControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$imagePasteControllerHash();

  @override
  String toString() {
    return r'imagePasteControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  ImagePasteController create() => ImagePasteController();

  @override
  bool operator ==(Object other) {
    return other is ImagePasteControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$imagePasteControllerHash() =>
    r'35d26a325dc17dfd5cd8b062bfca05d46b1e54b8';

final class ImagePasteControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            ImagePasteController,
            AsyncValue<bool>,
            bool,
            FutureOr<bool>,
            ({
              String? linkedFromId,
              String? categoryId,
            })> {
  ImagePasteControllerFamily._()
      : super(
          retry: null,
          name: r'imagePasteControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  ImagePasteControllerProvider call({
    required String? linkedFromId,
    required String? categoryId,
  }) =>
      ImagePasteControllerProvider._(argument: (
        linkedFromId: linkedFromId,
        categoryId: categoryId,
      ), from: this);

  @override
  String toString() => r'imagePasteControllerProvider';
}

abstract class _$ImagePasteController extends $AsyncNotifier<bool> {
  late final _$args = ref.$arg as ({
    String? linkedFromId,
    String? categoryId,
  });
  String? get linkedFromId => _$args.linkedFromId;
  String? get categoryId => _$args.categoryId;

  FutureOr<bool> build({
    required String? linkedFromId,
    required String? categoryId,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool>, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<bool>, bool>,
        AsyncValue<bool>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              linkedFromId: _$args.linkedFromId,
              categoryId: _$args.categoryId,
            ));
  }
}
