// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inference_provider_form_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(InferenceProviderFormController)
final inferenceProviderFormControllerProvider =
    InferenceProviderFormControllerFamily._();

final class InferenceProviderFormControllerProvider
    extends $AsyncNotifierProvider<InferenceProviderFormController,
        InferenceProviderFormState?> {
  InferenceProviderFormControllerProvider._(
      {required InferenceProviderFormControllerFamily super.from,
      required String? super.argument})
      : super(
          retry: null,
          name: r'inferenceProviderFormControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$inferenceProviderFormControllerHash();

  @override
  String toString() {
    return r'inferenceProviderFormControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  InferenceProviderFormController create() => InferenceProviderFormController();

  @override
  bool operator ==(Object other) {
    return other is InferenceProviderFormControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$inferenceProviderFormControllerHash() =>
    r'df276f0f35c1c2ef7ecaa279e1a5f9ffba791c88';

final class InferenceProviderFormControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            InferenceProviderFormController,
            AsyncValue<InferenceProviderFormState?>,
            InferenceProviderFormState?,
            FutureOr<InferenceProviderFormState?>,
            String?> {
  InferenceProviderFormControllerFamily._()
      : super(
          retry: null,
          name: r'inferenceProviderFormControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  InferenceProviderFormControllerProvider call({
    required String? configId,
  }) =>
      InferenceProviderFormControllerProvider._(argument: configId, from: this);

  @override
  String toString() => r'inferenceProviderFormControllerProvider';
}

abstract class _$InferenceProviderFormController
    extends $AsyncNotifier<InferenceProviderFormState?> {
  late final _$args = ref.$arg as String?;
  String? get configId => _$args;

  FutureOr<InferenceProviderFormState?> build({
    required String? configId,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<InferenceProviderFormState?>,
        InferenceProviderFormState?>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<InferenceProviderFormState?>,
            InferenceProviderFormState?>,
        AsyncValue<InferenceProviderFormState?>,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              configId: _$args,
            ));
  }
}
