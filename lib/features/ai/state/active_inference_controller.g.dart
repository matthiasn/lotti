// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_inference_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Tracks the active inference (if any) for a single (entityId, responseType)
/// pair. State is null when idle and an [ActiveInferenceData] while a run is in
/// flight. The provider is kept alive briefly after disposal
/// ([inferenceStateCacheDuration]) and disposes the current data's progress
/// stream on teardown.

@ProviderFor(ActiveInferenceController)
final activeInferenceControllerProvider = ActiveInferenceControllerFamily._();

/// Tracks the active inference (if any) for a single (entityId, responseType)
/// pair. State is null when idle and an [ActiveInferenceData] while a run is in
/// flight. The provider is kept alive briefly after disposal
/// ([inferenceStateCacheDuration]) and disposes the current data's progress
/// stream on teardown.
final class ActiveInferenceControllerProvider
    extends $NotifierProvider<ActiveInferenceController, ActiveInferenceData?> {
  /// Tracks the active inference (if any) for a single (entityId, responseType)
  /// pair. State is null when idle and an [ActiveInferenceData] while a run is in
  /// flight. The provider is kept alive briefly after disposal
  /// ([inferenceStateCacheDuration]) and disposes the current data's progress
  /// stream on teardown.
  ActiveInferenceControllerProvider._({
    required ActiveInferenceControllerFamily super.from,
    required ({String entityId, AiResponseType aiResponseType}) super.argument,
  }) : super(
         retry: null,
         name: r'activeInferenceControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activeInferenceControllerHash();

  @override
  String toString() {
    return r'activeInferenceControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  ActiveInferenceController create() => ActiveInferenceController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActiveInferenceData? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActiveInferenceData?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ActiveInferenceControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activeInferenceControllerHash() =>
    r'bf81922d7ae90001c2eb6a04613dc20038380e9f';

/// Tracks the active inference (if any) for a single (entityId, responseType)
/// pair. State is null when idle and an [ActiveInferenceData] while a run is in
/// flight. The provider is kept alive briefly after disposal
/// ([inferenceStateCacheDuration]) and disposes the current data's progress
/// stream on teardown.

final class ActiveInferenceControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ActiveInferenceController,
          ActiveInferenceData?,
          ActiveInferenceData?,
          ActiveInferenceData?,
          ({String entityId, AiResponseType aiResponseType})
        > {
  ActiveInferenceControllerFamily._()
    : super(
        retry: null,
        name: r'activeInferenceControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Tracks the active inference (if any) for a single (entityId, responseType)
  /// pair. State is null when idle and an [ActiveInferenceData] while a run is in
  /// flight. The provider is kept alive briefly after disposal
  /// ([inferenceStateCacheDuration]) and disposes the current data's progress
  /// stream on teardown.

  ActiveInferenceControllerProvider call({
    required String entityId,
    required AiResponseType aiResponseType,
  }) => ActiveInferenceControllerProvider._(
    argument: (entityId: entityId, aiResponseType: aiResponseType),
    from: this,
  );

  @override
  String toString() => r'activeInferenceControllerProvider';
}

/// Tracks the active inference (if any) for a single (entityId, responseType)
/// pair. State is null when idle and an [ActiveInferenceData] while a run is in
/// flight. The provider is kept alive briefly after disposal
/// ([inferenceStateCacheDuration]) and disposes the current data's progress
/// stream on teardown.

abstract class _$ActiveInferenceController
    extends $Notifier<ActiveInferenceData?> {
  late final _$args =
      ref.$arg as ({String entityId, AiResponseType aiResponseType});
  String get entityId => _$args.entityId;
  AiResponseType get aiResponseType => _$args.aiResponseType;

  ActiveInferenceData? build({
    required String entityId,
    required AiResponseType aiResponseType,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ActiveInferenceData?, ActiveInferenceData?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ActiveInferenceData?, ActiveInferenceData?>,
              ActiveInferenceData?,
              Object?,
              Object?
            >;
    element.handleCreate(
      ref,
      () => build(
        entityId: _$args.entityId,
        aiResponseType: _$args.aiResponseType,
      ),
    );
  }
}

/// Resolves the active inference for an entity regardless of response type.
///
/// Scans every [AiResponseType]'s [ActiveInferenceController] and returns the
/// first in-flight run, or null if the entity is idle. Because the unified
/// controller registers active inference for BOTH the primary and linked
/// entity, this also reports runs that were started against a linked entity.

@ProviderFor(ActiveInferenceByEntity)
final activeInferenceByEntityProvider = ActiveInferenceByEntityFamily._();

/// Resolves the active inference for an entity regardless of response type.
///
/// Scans every [AiResponseType]'s [ActiveInferenceController] and returns the
/// first in-flight run, or null if the entity is idle. Because the unified
/// controller registers active inference for BOTH the primary and linked
/// entity, this also reports runs that were started against a linked entity.
final class ActiveInferenceByEntityProvider
    extends $NotifierProvider<ActiveInferenceByEntity, ActiveInferenceData?> {
  /// Resolves the active inference for an entity regardless of response type.
  ///
  /// Scans every [AiResponseType]'s [ActiveInferenceController] and returns the
  /// first in-flight run, or null if the entity is idle. Because the unified
  /// controller registers active inference for BOTH the primary and linked
  /// entity, this also reports runs that were started against a linked entity.
  ActiveInferenceByEntityProvider._({
    required ActiveInferenceByEntityFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'activeInferenceByEntityProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$activeInferenceByEntityHash();

  @override
  String toString() {
    return r'activeInferenceByEntityProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ActiveInferenceByEntity create() => ActiveInferenceByEntity();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ActiveInferenceData? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ActiveInferenceData?>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ActiveInferenceByEntityProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$activeInferenceByEntityHash() =>
    r'8154dbc469fdbab7f789ab4e56f4b8c801ce5fe1';

/// Resolves the active inference for an entity regardless of response type.
///
/// Scans every [AiResponseType]'s [ActiveInferenceController] and returns the
/// first in-flight run, or null if the entity is idle. Because the unified
/// controller registers active inference for BOTH the primary and linked
/// entity, this also reports runs that were started against a linked entity.

final class ActiveInferenceByEntityFamily extends $Family
    with
        $ClassFamilyOverride<
          ActiveInferenceByEntity,
          ActiveInferenceData?,
          ActiveInferenceData?,
          ActiveInferenceData?,
          String
        > {
  ActiveInferenceByEntityFamily._()
    : super(
        retry: null,
        name: r'activeInferenceByEntityProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Resolves the active inference for an entity regardless of response type.
  ///
  /// Scans every [AiResponseType]'s [ActiveInferenceController] and returns the
  /// first in-flight run, or null if the entity is idle. Because the unified
  /// controller registers active inference for BOTH the primary and linked
  /// entity, this also reports runs that were started against a linked entity.

  ActiveInferenceByEntityProvider call(String entityId) =>
      ActiveInferenceByEntityProvider._(argument: entityId, from: this);

  @override
  String toString() => r'activeInferenceByEntityProvider';
}

/// Resolves the active inference for an entity regardless of response type.
///
/// Scans every [AiResponseType]'s [ActiveInferenceController] and returns the
/// first in-flight run, or null if the entity is idle. Because the unified
/// controller registers active inference for BOTH the primary and linked
/// entity, this also reports runs that were started against a linked entity.

abstract class _$ActiveInferenceByEntity
    extends $Notifier<ActiveInferenceData?> {
  late final _$args = ref.$arg as String;
  String get entityId => _$args;

  ActiveInferenceData? build(String entityId);
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ActiveInferenceData?, ActiveInferenceData?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ActiveInferenceData?, ActiveInferenceData?>,
              ActiveInferenceData?,
              Object?,
              Object?
            >;
    element.handleCreate(ref, () => build(_$args));
  }
}
