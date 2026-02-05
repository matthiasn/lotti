// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reference_image_selection_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReferenceImageSelectionController)
final referenceImageSelectionControllerProvider =
    ReferenceImageSelectionControllerFamily._();

final class ReferenceImageSelectionControllerProvider extends $NotifierProvider<
    ReferenceImageSelectionController, ReferenceImageSelectionState> {
  ReferenceImageSelectionControllerProvider._(
      {required ReferenceImageSelectionControllerFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'referenceImageSelectionControllerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() =>
      _$referenceImageSelectionControllerHash();

  @override
  String toString() {
    return r'referenceImageSelectionControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ReferenceImageSelectionController create() =>
      ReferenceImageSelectionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReferenceImageSelectionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReferenceImageSelectionState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ReferenceImageSelectionControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$referenceImageSelectionControllerHash() =>
    r'f9604148dd3bb2f8560fb9430d25f81125424ca2';

final class ReferenceImageSelectionControllerFamily extends $Family
    with
        $ClassFamilyOverride<
            ReferenceImageSelectionController,
            ReferenceImageSelectionState,
            ReferenceImageSelectionState,
            ReferenceImageSelectionState,
            String> {
  ReferenceImageSelectionControllerFamily._()
      : super(
          retry: null,
          name: r'referenceImageSelectionControllerProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  ReferenceImageSelectionControllerProvider call({
    required String taskId,
  }) =>
      ReferenceImageSelectionControllerProvider._(argument: taskId, from: this);

  @override
  String toString() => r'referenceImageSelectionControllerProvider';
}

abstract class _$ReferenceImageSelectionController
    extends $Notifier<ReferenceImageSelectionState> {
  late final _$args = ref.$arg as String;
  String get taskId => _$args;

  ReferenceImageSelectionState build({
    required String taskId,
  });
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref
        as $Ref<ReferenceImageSelectionState, ReferenceImageSelectionState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<ReferenceImageSelectionState, ReferenceImageSelectionState>,
        ReferenceImageSelectionState,
        Object?,
        Object?>;
    element.handleCreate(
        ref,
        () => build(
              taskId: _$args,
            ));
  }
}
