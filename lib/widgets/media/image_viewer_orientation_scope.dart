import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/utils/platform.dart';

typedef PreferredOrientationsSetter =
    Future<void> Function(
      List<DeviceOrientation> orientations,
    );

/// Coordinates the mobile orientation policy for full-screen image viewers.
///
/// The app remains portrait-only by default. While at least one image viewer
/// is mounted, either landscape direction is also permitted. Reference
/// counting prevents a nested viewer from restoring portrait while its parent
/// viewer is still visible.
class AppOrientationController {
  AppOrientationController({
    PreferredOrientationsSetter? setPreferredOrientations,
    bool Function()? isMobilePlatform,
  }) : _setPreferredOrientations =
           setPreferredOrientations ?? SystemChrome.setPreferredOrientations,
       _isMobilePlatform =
           isMobilePlatform ?? _defaultIsSupportedMobilePlatform;

  static const portraitOrientations = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ];

  static const imageViewerOrientations = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  final PreferredOrientationsSetter _setPreferredOrientations;
  final bool Function() _isMobilePlatform;

  int _imageViewerCount = 0;

  static bool _defaultIsSupportedMobilePlatform() => isIOS || isAndroid;

  /// Establishes the portrait-only policy used outside image viewers.
  Future<void> lockToPortrait() => _apply(portraitOrientations);

  /// Allows either landscape direction while an image viewer is visible.
  Future<void> enterImageViewer() {
    _imageViewerCount += 1;
    if (_imageViewerCount != 1) {
      return Future<void>.value();
    }
    return _apply(imageViewerOrientations);
  }

  /// Restores portrait after the final visible image viewer closes.
  Future<void> leaveImageViewer() {
    if (_imageViewerCount == 0) {
      return Future<void>.value();
    }

    _imageViewerCount -= 1;
    if (_imageViewerCount != 0) {
      return Future<void>.value();
    }
    return _apply(portraitOrientations);
  }

  /// Reasserts the current policy after the app returns to the foreground.
  Future<void> reapplyPreferredOrientations() => _apply(
    _imageViewerCount > 0 ? imageViewerOrientations : portraitOrientations,
  );

  Future<void> _apply(List<DeviceOrientation> orientations) {
    if (!_isMobilePlatform()) {
      return Future<void>.value();
    }
    return _setPreferredOrientations(orientations);
  }
}

final appOrientationController = AppOrientationController();

/// Applies image-viewer orientation policy for the lifetime of [child].
class ImageViewerOrientationScope extends StatefulWidget {
  const ImageViewerOrientationScope({
    required this.child,
    this.controller,
    super.key,
  });

  final Widget child;
  final AppOrientationController? controller;

  @override
  State<ImageViewerOrientationScope> createState() =>
      _ImageViewerOrientationScopeState();
}

class _ImageViewerOrientationScopeState
    extends State<ImageViewerOrientationScope>
    with WidgetsBindingObserver {
  late AppOrientationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? appOrientationController;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_controller.enterImageViewer());
  }

  @override
  void didUpdateWidget(ImageViewerOrientationScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextController = widget.controller ?? appOrientationController;
    if (identical(nextController, _controller)) {
      return;
    }

    unawaited(_controller.leaveImageViewer());
    _controller = nextController;
    unawaited(_controller.enterImageViewer());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller.reapplyPreferredOrientations());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller.leaveImageViewer());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
