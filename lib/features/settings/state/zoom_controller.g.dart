// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'zoom_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App-wide UI zoom factor, persisted across launches.
///
/// `keepAlive` so the scale survives navigation. [build] returns
/// [defaultZoomScale] synchronously, then asynchronously hydrates the last
/// persisted value from [SettingsDb] under `ZOOM_SCALE`; hydration is
/// skipped if the user already adjusted zoom before it completed (so a
/// race can't clobber a fresh interaction). Every adjustment clamps to
/// [[minZoomScale], [maxZoomScale]], rounds to two decimals, and persists.

@ProviderFor(ZoomController)
final zoomControllerProvider = ZoomControllerProvider._();

/// App-wide UI zoom factor, persisted across launches.
///
/// `keepAlive` so the scale survives navigation. [build] returns
/// [defaultZoomScale] synchronously, then asynchronously hydrates the last
/// persisted value from [SettingsDb] under `ZOOM_SCALE`; hydration is
/// skipped if the user already adjusted zoom before it completed (so a
/// race can't clobber a fresh interaction). Every adjustment clamps to
/// [[minZoomScale], [maxZoomScale]], rounds to two decimals, and persists.
final class ZoomControllerProvider
    extends $NotifierProvider<ZoomController, double> {
  /// App-wide UI zoom factor, persisted across launches.
  ///
  /// `keepAlive` so the scale survives navigation. [build] returns
  /// [defaultZoomScale] synchronously, then asynchronously hydrates the last
  /// persisted value from [SettingsDb] under `ZOOM_SCALE`; hydration is
  /// skipped if the user already adjusted zoom before it completed (so a
  /// race can't clobber a fresh interaction). Every adjustment clamps to
  /// [[minZoomScale], [maxZoomScale]], rounds to two decimals, and persists.
  ZoomControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'zoomControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$zoomControllerHash();

  @$internal
  @override
  ZoomController create() => ZoomController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$zoomControllerHash() => r'8b52f573b8a10aed0a1c6e31b1f0b45c0103ab17';

/// App-wide UI zoom factor, persisted across launches.
///
/// `keepAlive` so the scale survives navigation. [build] returns
/// [defaultZoomScale] synchronously, then asynchronously hydrates the last
/// persisted value from [SettingsDb] under `ZOOM_SCALE`; hydration is
/// skipped if the user already adjusted zoom before it completed (so a
/// race can't clobber a fresh interaction). Every adjustment clamps to
/// [[minZoomScale], [maxZoomScale]], rounds to two decimals, and persists.

abstract class _$ZoomController extends $Notifier<double> {
  double build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<double, double>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<double, double>,
              double,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
