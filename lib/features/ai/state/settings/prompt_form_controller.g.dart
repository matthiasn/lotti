// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prompt_form_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PromptFormController)
final promptFormControllerProvider = PromptFormControllerFamily._();

final class PromptFormControllerProvider
    extends $AsyncNotifierProvider<PromptFormController, PromptFormState?> {
  PromptFormControllerProvider._(
      {required PromptFormControllerFamily super.from,
      required String? super.argument})
      : super(
          retry: null,
          name: r'promptFormControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$promptFormControllerHash();

  @override
  String toString() {
    return r'promptFormControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PromptFormController create() => PromptFormController();

  @override
  bool operator ==(Object other) {
    return other is PromptFormControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$promptFormControllerHash() =>
    r'52ee237720b1639af32808fe8d534f8d295cc16f';

final class PromptFormControllerFamily extends $Family
    with
        $ClassFamilyOverride<PromptFormController, AsyncValue<PromptFormState?>,
            PromptFormState?, FutureOr<PromptFormState?>, String?> {
  PromptFormControllerFamily._()
      : super(
          retry: null,
          name: r'promptFormControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  PromptFormControllerProvider call({
    required String? configId,
  }) =>
      PromptFormControllerProvider._(argument: configId, from: this);

  @override
  String toString() => r'promptFormControllerProvider';
}

abstract class _$PromptFormController extends $AsyncNotifier<PromptFormState?> {
  late final _$args = ref.$arg as String?;
  String? get configId => _$args;

  FutureOr<PromptFormState?> build({
    required String? configId,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<PromptFormState?>, PromptFormState?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<PromptFormState?>, PromptFormState?>,
        AsyncValue<PromptFormState?>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              configId: _$args,
            ));
  }
}
