// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inference_model_form_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(InferenceModelFormController)
final inferenceModelFormControllerProvider =
    InferenceModelFormControllerFamily._();

final class InferenceModelFormControllerProvider extends $AsyncNotifierProvider<
    InferenceModelFormController, InferenceModelFormState?> {
  InferenceModelFormControllerProvider._(
      {required InferenceModelFormControllerFamily super.from,
      required String? super.argument})
      : super(
          retry: null,
          name: r'inferenceModelFormControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$inferenceModelFormControllerHash();

  @override
  String toString() {
    return r'inferenceModelFormControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  InferenceModelFormController create() => InferenceModelFormController();

  @override
  bool operator ==(Object other) {
    return other is InferenceModelFormControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$inferenceModelFormControllerHash() =>
    r'bf4f44475c5e2926b14de33c7d4aea0047d1d60e';

final class InferenceModelFormControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            InferenceModelFormController,
            AsyncValue<InferenceModelFormState?>,
            InferenceModelFormState?,
            FutureOr<InferenceModelFormState?>,
            String?> {
  InferenceModelFormControllerFamily._()
      : super(
          retry: null,
          name: r'inferenceModelFormControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  InferenceModelFormControllerProvider call({
    required String? configId,
  }) =>
      InferenceModelFormControllerProvider._(argument: configId, from: this);

  @override
  String toString() => r'inferenceModelFormControllerProvider';
}

abstract class _$InferenceModelFormController
    extends $AsyncNotifier<InferenceModelFormState?> {
  late final _$args = ref.$arg as String?;
  String? get configId => _$args;

  FutureOr<InferenceModelFormState?> build({
    required String? configId,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref
        as $Ref<AsyncValue<InferenceModelFormState?>, InferenceModelFormState?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<InferenceModelFormState?>,
            InferenceModelFormState?>,
        AsyncValue<InferenceModelFormState?>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              configId: _$args,
            ));
  }
}
