// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pane_width_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PaneWidthController)
final paneWidthControllerProvider = PaneWidthControllerProvider._();

final class PaneWidthControllerProvider
    extends $NotifierProvider<PaneWidthController, PaneWidths> {
  PaneWidthControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'paneWidthControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$paneWidthControllerHash();

  @$internal
  @override
  PaneWidthController create() => PaneWidthController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PaneWidths value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PaneWidths>(value),
    );
  }
}

String _$paneWidthControllerHash() =>
    r'cab1608c86ffb5c3dfb40fd96bf5ab4fd1713e8c';

abstract class _$PaneWidthController extends $Notifier<PaneWidths> {
  PaneWidths build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<PaneWidths, PaneWidths>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PaneWidths, PaneWidths>,
              PaneWidths,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
