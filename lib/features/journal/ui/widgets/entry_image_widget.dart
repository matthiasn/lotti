import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/util/image_export_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:photo_view/photo_view.dart';

/// Inline image for a [JournalImage] entry in the detail view.
///
/// Decodes the file through a [ResizeImage] sized to the viewport (so large
/// photos are downsampled to the displayed resolution), tapping opens a
/// full-screen, zoomable hero view ([HeroPhotoViewRouteWrapper]). A decode
/// error evicts the exact cache key and renders nothing.
class EntryImageWidget extends ConsumerWidget {
  const EntryImageWidget(this.journalImage, {super.key});

  final JournalImage journalImage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(journalImage.meta.id);
    final notifier = ref.read(provider.notifier);
    final file = File(getFullImagePath(journalImage));
    final focusNode = notifier.focusNode;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    final maxHeight = isMobile ? 400.0 : screenWidth;
    // Hold a single ResizeImage instance so the cache eviction below targets
    // the exact key Flutter used to store the decoded bitmap. Evicting a bare
    // FileImage would miss because ResizeImageKey also includes dimensions +
    // policy.
    final imageProvider = ResizeImage(
      FileImage(file),
      width: (screenWidth * devicePixelRatio).round().clamp(1, 10000),
      height: (maxHeight * devicePixelRatio).round().clamp(1, 10000),
      policy: ResizeImagePolicy.fit,
    );

    return GestureDetector(
      onTap: () {
        focusNode.unfocus();
        Navigator.of(context, rootNavigator: true).push(
          PageRouteBuilder<void>(
            opaque: false,
            barrierColor: Theme.of(
              context,
            ).colorScheme.scrim.withValues(alpha: 0.82),
            pageBuilder: (context, animation, secondaryAnimation) =>
                HeroPhotoViewRouteWrapper(
                  file: file,
                ),
          ),
        );
      },
      child: ColoredBox(
        color: Colors.black,
        child: Hero(
          tag: 'entry_img',
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Image(
              image: imageProvider,
              width: screenWidth,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                imageCache.evict(imageProvider);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }
}

// from https://github.com/bluefireteam/photo_view/blob/master/example/lib/screens/examples/hero_example.dart
class HeroPhotoViewRouteWrapper extends StatefulWidget {
  const HeroPhotoViewRouteWrapper({
    required this.file,
    super.key,
    this.backgroundDecoration,
    this.imageExporter,
  });

  final File file;
  final BoxDecoration? backgroundDecoration;

  /// Saves the image to a platform-appropriate destination. Defaults to
  /// [defaultImageExporter]; injected in tests to avoid real platform channels.
  final ImageExporter? imageExporter;

  @override
  State<HeroPhotoViewRouteWrapper> createState() =>
      _HeroPhotoViewRouteWrapperState();
}

class _HeroPhotoViewRouteWrapperState extends State<HeroPhotoViewRouteWrapper> {
  static const double _zoomFactor = 1.25;
  static const double _maxZoomScale = 8;

  late final PhotoViewController _photoController;
  late final PhotoViewScaleStateController _scaleStateController;
  late final StreamSubscription<PhotoViewControllerValue> _photoSubscription;
  late final ImageExporter _exporter =
      widget.imageExporter ?? defaultImageExporter();

  double _scale = 1;
  double? _minimumScale;
  Size? _lastSize;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _photoController = PhotoViewController();
    _photoSubscription = _photoController.outputStateStream.listen(
      _handlePhotoViewValue,
    );
    _scaleStateController = PhotoViewScaleStateController();
  }

  @override
  void dispose() {
    unawaited(_photoSubscription.cancel());
    _photoController.dispose();
    _scaleStateController.dispose();
    super.dispose();
  }

  void _handlePhotoViewValue(PhotoViewControllerValue value) {
    final nextScale = value.scale;
    if (nextScale == null || !mounted) {
      return;
    }

    setState(() {
      _scale = nextScale;
      _minimumScale ??= nextScale;
    });
  }

  void _close() => Navigator.of(context, rootNavigator: true).pop();

  void _zoomIn() {
    _setZoom(_scale * _zoomFactor);
  }

  void _zoomOut() {
    _setZoom(_scale / _zoomFactor);
  }

  void _resetZoom() {
    _scaleStateController.reset();
    _photoController.updateMultiple(
      position: Offset.zero,
      rotation: 0,
      scale: _minimumScale ?? _scale,
    );
  }

  void _setZoom(double scale) {
    final minimumScale = _minimumScale ?? _scale;
    _minimumScale ??= minimumScale;
    final nextScale = scale.clamp(minimumScale, _maxZoomScale);
    _photoController.updateMultiple(
      position: Offset.zero,
      scale: nextScale,
    );
  }

  Future<void> _downloadImage() async {
    if (_isDownloading) {
      return;
    }

    setState(() => _isDownloading = true);
    try {
      final result = await _exporter(widget.file);
      if (!mounted) {
        return;
      }
      switch (result.status) {
        case ImageExportStatus.savedToFile:
          _showSnackBar(
            context.messages.imageViewerDownloadSaved(result.savedName ?? ''),
          );
        case ImageExportStatus.savedToGallery:
          _showSnackBar(context.messages.imageViewerDownloadSavedToGallery);
        case ImageExportStatus.permissionDenied:
          _showSnackBar(context.messages.imageViewerDownloadPermissionDenied);
        case ImageExportStatus.cancelled:
          // User dismissed the save panel; no feedback needed.
          break;
      }
    } on Object catch (error, stackTrace) {
      getIt<LoggingService>().captureException(
        error,
        domain: 'entry_image_widget',
        subDomain: 'downloadImage',
        stackTrace: stackTrace,
      );
      if (!mounted) {
        return;
      }
      _showSnackBar(context.messages.imageViewerDownloadFailed);
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (_lastSize != size) {
      _lastSize = size;
      _minimumScale = null;
    }

    final imageProvider = FileImage(widget.file);
    final tokens = context.designTokens;
    final padding = MediaQuery.paddingOf(context);
    final edge = isMobile ? tokens.spacing.step3 : tokens.spacing.step8;
    final top = tokens.spacing.step5;
    final bottom = tokens.spacing.step11;
    final minimumScale = _minimumScale ?? _scale;
    final canZoomOut = _scale > minimumScale * 1.01;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(edge, top, edge, bottom),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(tokens.radii.m),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.scrim,
                          border: Border.all(
                            color: tokens.colors.decorative.level02,
                          ),
                        ),
                        child: PhotoView(
                          imageProvider: imageProvider,
                          backgroundDecoration:
                              widget.backgroundDecoration ??
                              BoxDecoration(
                                color: Theme.of(context).colorScheme.scrim,
                              ),
                          controller: _photoController,
                          scaleStateController: _scaleStateController,
                          heroAttributes: const PhotoViewHeroAttributes(
                            tag: 'entry_img',
                          ),
                          minScale: PhotoViewComputedScale.contained,
                          maxScale: PhotoViewComputedScale.covered * 4,
                          initialScale: PhotoViewComputedScale.contained,
                          strictScale: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: edge,
                top: padding.top + tokens.spacing.step3,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ImageViewerIconButton(
                      tooltip: _isDownloading
                          ? context.messages.imageViewerDownloadingTooltip
                          : context.messages.imageViewerDownloadTooltip,
                      icon: _isDownloading
                          ? Icons.hourglass_top_rounded
                          : Icons.download_rounded,
                      onPressed: _isDownloading
                          ? null
                          : () => unawaited(_downloadImage()),
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    _ImageViewerIconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      icon: Icons.close_rounded,
                      onPressed: _close,
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: padding.bottom + tokens.spacing.step4,
                child: Center(
                  child: _ImageViewerZoomControls(
                    scale: _scale,
                    canZoomOut: canZoomOut,
                    onZoomOut: canZoomOut ? _zoomOut : null,
                    onZoomReset: _resetZoom,
                    onZoomIn: _zoomIn,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageViewerIconButton extends StatelessWidget {
  const _ImageViewerIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Material(
      color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.46),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        color: Colors.white,
        disabledColor: Colors.white.withValues(alpha: 0.45),
        padding: EdgeInsets.all(tokens.spacing.step3),
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

class _ImageViewerZoomControls extends StatelessWidget {
  const _ImageViewerZoomControls({
    required this.scale,
    required this.canZoomOut,
    required this.onZoomOut,
    required this.onZoomReset,
    required this.onZoomIn,
  });

  final double scale;
  final bool canZoomOut;
  final VoidCallback? onZoomOut;
  final VoidCallback onZoomReset;
  final VoidCallback onZoomIn;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final percent = '${(scale * 100).round()}%';

    return Material(
      color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ImageViewerZoomButton(
              tooltip: context.messages.viewMenuZoomOut,
              icon: Icons.remove_rounded,
              onPressed: canZoomOut ? onZoomOut : null,
            ),
            Tooltip(
              message: context.messages.viewMenuZoomReset,
              child: InkWell(
                onTap: onZoomReset,
                borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.step4,
                    vertical: tokens.spacing.step2,
                  ),
                  child: Text(
                    percent,
                    textAlign: TextAlign.center,
                    style: tokens.typography.styles.body.bodyMedium.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            _ImageViewerZoomButton(
              tooltip: context.messages.viewMenuZoomIn,
              icon: Icons.add_rounded,
              onPressed: onZoomIn,
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageViewerZoomButton extends StatelessWidget {
  const _ImageViewerZoomButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return IconButton(
      tooltip: tooltip,
      color: Colors.white,
      disabledColor: Colors.white.withValues(alpha: 0.45),
      padding: EdgeInsets.all(tokens.spacing.step2),
      constraints: BoxConstraints.tightFor(
        width: tokens.spacing.step8,
        height: tokens.spacing.step8,
      ),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}
