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
      required ({
        String? configId,
        InferenceProviderType? preselectedType,
      })
          super.argument})
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
        '$argument';
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
    r'8e9c80c6330cb7cd598915227200b612d0edd1c7';

final class InferenceProviderFormControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            InferenceProviderFormController,
            AsyncValue<InferenceProviderFormState?>,
            InferenceProviderFormState?,
            FutureOr<InferenceProviderFormState?>,
            ({
              String? configId,
              InferenceProviderType? preselectedType,
            })> {
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
    InferenceProviderType? preselectedType,
  }) =>
      InferenceProviderFormControllerProvider._(argument: (
        configId: configId,
        preselectedType: preselectedType,
      ), from: this);

  @override
  String toString() => r'inferenceProviderFormControllerProvider';
}

abstract class _$InferenceProviderFormController
    extends $AsyncNotifier<InferenceProviderFormState?> {
  late final _$args = ref.$arg as ({
    String? configId,
    InferenceProviderType? preselectedType,
  });
  String? get configId => _$args.configId;
  InferenceProviderType? get preselectedType => _$args.preselectedType;

  FutureOr<InferenceProviderFormState?> build({
    required String? configId,
    InferenceProviderType? preselectedType,
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
              configId: _$args.configId,
              preselectedType: _$args.preselectedType,
            ));
  }
}
