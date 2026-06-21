// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inference_status_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Holds the [InferenceStatus] for a single (id, responseType) pair.
///
/// Defaults to [InferenceStatus.idle] and is briefly kept alive after disposal
/// ([inferenceStateCacheDuration]) so a status set just before teardown isn't
/// lost. Updated via [setStatus] by the inference runners.

@ProviderFor(InferenceStatusController)
final inferenceStatusControllerProvider = InferenceStatusControllerFamily._();

/// Holds the [InferenceStatus] for a single (id, responseType) pair.
///
/// Defaults to [InferenceStatus.idle] and is briefly kept alive after disposal
/// ([inferenceStateCacheDuration]) so a status set just before teardown isn't
/// lost. Updated via [setStatus] by the inference runners.
final class InferenceStatusControllerProvider
    extends $NotifierProvider<InferenceStatusController, InferenceStatus> {
  /// Holds the [InferenceStatus] for a single (id, responseType) pair.
  ///
  /// Defaults to [InferenceStatus.idle] and is briefly kept alive after disposal
  /// ([inferenceStateCacheDuration]) so a status set just before teardown isn't
  /// lost. Updated via [setStatus] by the inference runners.
  InferenceStatusControllerProvider._({
    required InferenceStatusControllerFamily super.from,
    required ({String id, AiResponseType aiResponseType}) super.argument,
  }) : super(
         retry: null,
         name: r'inferenceStatusControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$inferenceStatusControllerHash();

  @override
  String toString() {
    return r'inferenceStatusControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  InferenceStatusController create() => InferenceStatusController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(InferenceStatus value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<InferenceStatus>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is InferenceStatusControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$inferenceStatusControllerHash() =>
    r'42c736c8fcb9f21c98683e879518cfda4ab88120';

/// Holds the [InferenceStatus] for a single (id, responseType) pair.
///
/// Defaults to [InferenceStatus.idle] and is briefly kept alive after disposal
/// ([inferenceStateCacheDuration]) so a status set just before teardown isn't
/// lost. Updated via [setStatus] by the inference runners.

final class InferenceStatusControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          InferenceStatusController,
          InferenceStatus,
          InferenceStatus,
          InferenceStatus,
          ({String id, AiResponseType aiResponseType})
        > {
  InferenceStatusControllerFamily._()
    : super(
        retry: null,
        name: r'inferenceStatusControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Holds the [InferenceStatus] for a single (id, responseType) pair.
  ///
  /// Defaults to [InferenceStatus.idle] and is briefly kept alive after disposal
  /// ([inferenceStateCacheDuration]) so a status set just before teardown isn't
  /// lost. Updated via [setStatus] by the inference runners.

  InferenceStatusControllerProvider call({
    required String id,
    required AiResponseType aiResponseType,
  }) => InferenceStatusControllerProvider._(
    argument: (id: id, aiResponseType: aiResponseType),
    from: this,
  );

  @override
  String toString() => r'inferenceStatusControllerProvider';
}

/// Holds the [InferenceStatus] for a single (id, responseType) pair.
///
/// Defaults to [InferenceStatus.idle] and is briefly kept alive after disposal
/// ([inferenceStateCacheDuration]) so a status set just before teardown isn't
/// lost. Updated via [setStatus] by the inference runners.

abstract class _$InferenceStatusController extends $Notifier<InferenceStatus> {
  late final _$args = ref.$arg as ({String id, AiResponseType aiResponseType});
  String get id => _$args.id;
  AiResponseType get aiResponseType => _$args.aiResponseType;

  InferenceStatus build({
    required String id,
    required AiResponseType aiResponseType,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<InferenceStatus, InferenceStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<InferenceStatus, InferenceStatus>,
              InferenceStatus,
              Object?,
              Object?
            >;
    element.handleCreate(
      ref,
      () => build(id: _$args.id, aiResponseType: _$args.aiResponseType),
    );
  }
}

/// True when ANY of [responseTypes] is currently running for [id].
///
/// Aggregates the per-type [InferenceStatusController]s so a widget can show a
/// single "AI is working" indicator without subscribing to each type itself.

@ProviderFor(InferenceRunningController)
final inferenceRunningControllerProvider = InferenceRunningControllerFamily._();

/// True when ANY of [responseTypes] is currently running for [id].
///
/// Aggregates the per-type [InferenceStatusController]s so a widget can show a
/// single "AI is working" indicator without subscribing to each type itself.
final class InferenceRunningControllerProvider
    extends $NotifierProvider<InferenceRunningController, bool> {
  /// True when ANY of [responseTypes] is currently running for [id].
  ///
  /// Aggregates the per-type [InferenceStatusController]s so a widget can show a
  /// single "AI is working" indicator without subscribing to each type itself.
  InferenceRunningControllerProvider._({
    required InferenceRunningControllerFamily super.from,
    required ({String id, Set<AiResponseType> responseTypes}) super.argument,
  }) : super(
         retry: null,
         name: r'inferenceRunningControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$inferenceRunningControllerHash();

  @override
  String toString() {
    return r'inferenceRunningControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  InferenceRunningController create() => InferenceRunningController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is InferenceRunningControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$inferenceRunningControllerHash() =>
    r'98e6bb2372af2115718976c3eb9f9651da5ec5f1';

/// True when ANY of [responseTypes] is currently running for [id].
///
/// Aggregates the per-type [InferenceStatusController]s so a widget can show a
/// single "AI is working" indicator without subscribing to each type itself.

final class InferenceRunningControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          InferenceRunningController,
          bool,
          bool,
          bool,
          ({String id, Set<AiResponseType> responseTypes})
        > {
  InferenceRunningControllerFamily._()
    : super(
        retry: null,
        name: r'inferenceRunningControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// True when ANY of [responseTypes] is currently running for [id].
  ///
  /// Aggregates the per-type [InferenceStatusController]s so a widget can show a
  /// single "AI is working" indicator without subscribing to each type itself.

  InferenceRunningControllerProvider call({
    required String id,
    required Set<AiResponseType> responseTypes,
  }) => InferenceRunningControllerProvider._(
    argument: (id: id, responseTypes: responseTypes),
    from: this,
  );

  @override
  String toString() => r'inferenceRunningControllerProvider';
}

/// True when ANY of [responseTypes] is currently running for [id].
///
/// Aggregates the per-type [InferenceStatusController]s so a widget can show a
/// single "AI is working" indicator without subscribing to each type itself.

abstract class _$InferenceRunningController extends $Notifier<bool> {
  late final _$args =
      ref.$arg as ({String id, Set<AiResponseType> responseTypes});
  String get id => _$args.id;
  Set<AiResponseType> get responseTypes => _$args.responseTypes;

  bool build({required String id, required Set<AiResponseType> responseTypes});
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleCreate(
      ref,
      () => build(id: _$args.id, responseTypes: _$args.responseTypes),
    );
  }
}
