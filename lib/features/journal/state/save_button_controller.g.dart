// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'save_button_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SaveButtonController)
final saveButtonControllerProvider = SaveButtonControllerFamily._();

final class SaveButtonControllerProvider
    extends $AsyncNotifierProvider<SaveButtonController, bool?> {
  SaveButtonControllerProvider._(
      {required SaveButtonControllerFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'saveButtonControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$saveButtonControllerHash();

  @override
  String toString() {
    return r'saveButtonControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  SaveButtonController create() => SaveButtonController();

  @override
  bool operator ==(Object other) {
    return other is SaveButtonControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$saveButtonControllerHash() =>
    r'9182c8dbd4ede104a007b687a993aa73a1f2a9a4';

final class SaveButtonControllerFamily extends $Family
    with
        $ClassFamilyOverride<SaveButtonController, AsyncValue<bool?>, bool?,
            FutureOr<bool?>, String> {
  SaveButtonControllerFamily._()
      : super(
          retry: null,
          name: r'saveButtonControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  SaveButtonControllerProvider call({
    required String id,
  }) =>
      SaveButtonControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'saveButtonControllerProvider';
}

abstract class _$SaveButtonController extends $AsyncNotifier<bool?> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  FutureOr<bool?> build({
    required String id,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<bool?>, bool?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<bool?>, bool?>,
        AsyncValue<bool?>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              id: _$args,
            ));
  }
}
