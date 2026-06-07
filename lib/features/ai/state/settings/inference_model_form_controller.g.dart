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

final class InferenceModelFormControllerProvider
    extends
        $AsyncNotifierProvider<
          InferenceModelFormController,
          InferenceModelFormState?
        > {
  InferenceModelFormControllerProvider._({
    required InferenceModelFormControllerFamily super.from,
    required ({String? configId, String? preselectedProviderId}) super.argument,
  }) : super(
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
        '$argument';
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
    r'41cfab6c4b163c669090277c8845ab320e503d06';

final class InferenceModelFormControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          InferenceModelFormController,
          AsyncValue<InferenceModelFormState?>,
          InferenceModelFormState?,
          FutureOr<InferenceModelFormState?>,
          ({String? configId, String? preselectedProviderId})
        > {
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
    String? preselectedProviderId,
  }) => InferenceModelFormControllerProvider._(
    argument: (
      configId: configId,
      preselectedProviderId: preselectedProviderId,
    ),
    from: this,
  );

  @override
  String toString() => r'inferenceModelFormControllerProvider';
}

abstract class _$InferenceModelFormController
    extends $AsyncNotifier<InferenceModelFormState?> {
  late final _$args =
      ref.$arg as ({String? configId, String? preselectedProviderId});
  String? get configId => _$args.configId;
  String? get preselectedProviderId => _$args.preselectedProviderId;

  FutureOr<InferenceModelFormState?> build({
    required String? configId,
    String? preselectedProviderId,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<InferenceModelFormState?>,
              InferenceModelFormState?
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<InferenceModelFormState?>,
                InferenceModelFormState?
              >,
              AsyncValue<InferenceModelFormState?>,
              Object?,
              Object?
            >;
    element.handleCreate(
      ref,
      () => build(
        configId: _$args.configId,
        preselectedProviderId: _$args.preselectedProviderId,
      ),
    );
  }
}
