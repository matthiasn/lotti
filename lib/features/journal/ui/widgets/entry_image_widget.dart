import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/util/image_export_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/media/image_viewer_orientation_scope.dart';
import 'package:material_ui/material_ui.dart';
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
        showFullscreenImageViewer(
          context,
          file: file,
          date: journalImage.data.capturedAt,
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

/// Opens [file] in the shared full-screen, zoomable image viewer.
///
/// [heroTag] identifies the source image for the transition. Callers outside
/// [EntryImageWidget] should provide a distinct tag so another image on the
/// current route cannot be selected as the Hero source.
///
/// Passing [gallery] (which must contain [file] at [initialIndex]) turns the
/// viewer into a navigable gallery: chevron buttons on both edges and the
/// left/right arrow keys move between images, and a counter chip shows the
/// position.
void showFullscreenImageViewer(
  BuildContext context, {
  required File file,
  Object heroTag = 'entry_img',
  List<File>? gallery,
  DateTime? date,
  List<DateTime?>? galleryDates,
  int initialIndex = 0,
}) {
  Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Theme.of(
        context,
      ).colorScheme.scrim.withValues(alpha: 0.82),
      pageBuilder: (context, animation, secondaryAnimation) =>
          HeroPhotoViewRouteWrapper(
            file: file,
            heroTag: heroTag,
            gallery: gallery,
            date: date,
            galleryDates: galleryDates,
            initialIndex: initialIndex,
          ),
    ),
  );
}

// from https://github.com/bluefireteam/photo_view/blob/master/example/lib/screens/examples/hero_example.dart
class HeroPhotoViewRouteWrapper extends StatefulWidget {
  const HeroPhotoViewRouteWrapper({
    required this.file,
    super.key,
    this.backgroundDecoration,
    this.heroTag = 'entry_img',
    this.imageExporter,
    this.gallery,
    this.date,
    this.galleryDates,
    this.initialIndex = 0,
  });

  final File file;
  final BoxDecoration? backgroundDecoration;
  final Object heroTag;

  /// Saves the image to a platform-appropriate destination. Defaults to
  /// [defaultImageExporter]; injected in tests to avoid real platform channels.
  final ImageExporter? imageExporter;

  /// All images of the surrounding collection, in display order, when the
  /// viewer should allow moving between them. Null (or a single entry) keeps
  /// the single-image behavior. [file] is expected to sit at [initialIndex].
  final List<File>? gallery;

  /// Capture date for [file], falling back to the journal/file date at the
  /// call site when embedded metadata is unavailable.
  final DateTime? date;

  /// Dates corresponding to [gallery], in the same display order.
  final List<DateTime?>? galleryDates;

  /// Index of the initially shown image within [gallery]. Only the initial
  /// image participates in the Hero transition — after navigating away, a pop
  /// would otherwise fly the wrong image back to the source tile.
  final int initialIndex;

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
  double _scale = 1;
  double? _minimumScale;
  Size? _lastSize;
  bool _overlaysVisible = true;

  late final List<File> _files =
      (widget.gallery == null || widget.gallery!.isEmpty)
      ? [widget.file]
      : widget.gallery!;
  late final int _initialIndex = widget.initialIndex.clamp(
    0,
    _files.length - 1,
  );
  late int _index = _initialIndex;

  bool get _hasGallery => _files.length > 1;
  bool get _canGoPrevious => _index > 0;
  bool get _canGoNext => _index < _files.length - 1;

  File get _currentFile => _files[_index];

  DateTime? get _currentDate {
    final galleryDates = widget.galleryDates;
    if (galleryDates != null && _index < galleryDates.length) {
      return galleryDates[_index];
    }
    return _index == _initialIndex ? widget.date : null;
  }

  void _goToPrevious() => _goTo(_index - 1);

  void _goToNext() => _goTo(_index + 1);

  void _goTo(int index) {
    if (index < 0 || index >= _files.length || index == _index) return;
    setState(() {
      _index = index;
      // Re-learn the new image's contained scale so zoom % and the zoom-out
      // floor are correct for its aspect ratio.
      _minimumScale = null;
    });
    // Show each image fresh: contained, unrotated, centered.
    _scaleStateController.reset();
    _photoController.updateMultiple(
      position: Offset.zero,
      rotation: 0,
    );
  }

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

  void _toggleOverlays() {
    setState(() => _overlaysVisible = !_overlaysVisible);
  }

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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (_lastSize != size) {
      _lastSize = size;
      _minimumScale = null;
    }

    final imageProvider = FileImage(_currentFile);
    final tokens = context.designTokens;
    final padding = MediaQuery.paddingOf(context);
    final edge = isMobile ? tokens.spacing.step3 : tokens.spacing.step8;
    final minimumScale = _minimumScale ?? _scale;
    final canZoomOut = _scale > minimumScale * 1.01;

    return ImageViewerOrientationScope(
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): _close,
          if (_hasGallery) ...{
            const SingleActivator(LogicalKeyboardKey.arrowLeft): _goToPrevious,
            const SingleActivator(LogicalKeyboardKey.arrowRight): _goToNext,
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                Positioned.fill(
                  child: ImageViewerTapRegion(
                    onSingleTap: _toggleOverlays,
                    child: PhotoView(
                      imageProvider: imageProvider,
                      // PhotoView defaults rotation off; do not opt in here.
                      backgroundDecoration:
                          widget.backgroundDecoration ??
                          BoxDecoration(
                            color: Theme.of(context).colorScheme.scrim,
                          ),
                      controller: _photoController,
                      scaleStateController: _scaleStateController,
                      // Only the initially opened image flies back to its
                      // source tile; after navigating, a hero pop would pair
                      // the wrong image with the tile the viewer was opened
                      // from.
                      heroAttributes: _index == _initialIndex
                          ? PhotoViewHeroAttributes(tag: widget.heroTag)
                          : null,
                      minScale: PhotoViewComputedScale.contained,
                      maxScale: PhotoViewComputedScale.covered * 4,
                      initialScale: PhotoViewComputedScale.contained,
                      strictScale: true,
                    ),
                  ),
                ),
                if (_overlaysVisible && _hasGallery) ...[
                  Positioned(
                    left: padding.left + edge,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: ImageViewerIconButton(
                        tooltip: context.messages.imageViewerPreviousTooltip,
                        icon: LottiIcons.chevronLeft,
                        onPressed: _canGoPrevious ? _goToPrevious : null,
                      ),
                    ),
                  ),
                  Positioned(
                    right: padding.right + edge,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: ImageViewerIconButton(
                        tooltip: context.messages.imageViewerNextTooltip,
                        icon: LottiIcons.chevronRight,
                        onPressed: _canGoNext ? _goToNext : null,
                      ),
                    ),
                  ),
                  Positioned(
                    left: padding.left + edge,
                    top: padding.top + tokens.spacing.step3,
                    child: _ImageViewerCounterChip(
                      index: _index,
                      total: _files.length,
                    ),
                  ),
                ],
                if (_overlaysVisible)
                  Positioned(
                    right: padding.right + edge,
                    top: padding.top + tokens.spacing.step3,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ImageViewerDownloadButton(
                          file: _currentFile,
                          imageExporter: widget.imageExporter,
                          logDomain: 'entry_image_widget',
                        ),
                        SizedBox(width: tokens.spacing.step2),
                        ImageViewerIconButton(
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).closeButtonTooltip,
                          icon: LottiIcons.close,
                          onPressed: _close,
                        ),
                      ],
                    ),
                  ),
                if (_overlaysVisible)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: padding.bottom + tokens.spacing.step4,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_currentDate != null) ...[
                            ImageViewerDateChip(date: _currentDate!),
                            SizedBox(height: tokens.spacing.step2),
                          ],
                          _ImageViewerZoomControls(
                            scale: _scale,
                            canZoomOut: canZoomOut,
                            onZoomOut: canZoomOut ? _zoomOut : null,
                            onZoomReset: _resetZoom,
                            onZoomIn: _zoomIn,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "3 / 7" position pill for gallery mode. Digits only, so it needs no
/// translation.
class _ImageViewerCounterChip extends StatelessWidget {
  const _ImageViewerCounterChip({
    required this.index,
    required this.total,
  });

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Material(
      color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step4,
          vertical: tokens.spacing.step2,
        ),
        child: Text(
          '${index + 1} / $total',
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class ImageViewerIconButton extends StatelessWidget {
  const ImageViewerIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    super.key,
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

/// The scrim pill every piece of viewer chrome sits on: a dark, rounded
/// surface over the photo with the padding the chips share, so a counter, a
/// date, a badge and a labelled action all read as one family. Tappable only
/// when [onTap] is given — an inert pill adds no ink layer, so taps on it
/// still fall through to the canvas the way they did before.
class ImageViewerPill extends StatelessWidget {
  const ImageViewerPill({
    required this.child,
    this.alpha = 0.46,
    this.onTap,
    this.padding,
    super.key,
  });

  final Widget child;

  /// Opacity of the scrim behind [child]; chrome that has to stay legible
  /// over any photo (the date, a badge) uses a darker one than a button.
  final double alpha;
  final VoidCallback? onTap;

  /// Defaults to the chrome's standard inset (`step4` × `step2`).
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final body = Padding(
      padding:
          padding ??
          EdgeInsets.symmetric(
            horizontal: tokens.spacing.step4,
            vertical: tokens.spacing.step2,
          ),
      child: child,
    );
    return Material(
      color: Theme.of(context).colorScheme.scrim.withValues(alpha: alpha),
      borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? body : InkWell(onTap: onTap, child: body),
    );
  }
}

/// A labelled pill action for the viewer chrome — [ImageViewerIconButton]
/// with a word beside the glyph, for an action a glyph alone would not carry
/// ("Set cover"). A null [onPressed] renders it inert and dimmed, so the same
/// pill can state a fact ("Cover") where there is nothing left to do.
class ImageViewerLabelButton extends StatelessWidget {
  const ImageViewerLabelButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final foreground = onPressed == null
        ? Colors.white.withValues(alpha: 0.7)
        : Colors.white;
    return ImageViewerPill(
      onTap: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: tokens.spacing.step5, color: foreground),
          SizedBox(width: tokens.spacing.step2),
          Text(
            label,
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Download control shared by the single-photo and event gallery viewers.
///
/// It owns the in-flight guard and platform-specific result feedback so both
/// viewer modes have identical permissions, progress, and error behavior.
class ImageViewerDownloadButton extends StatefulWidget {
  const ImageViewerDownloadButton({
    required this.file,
    required this.logDomain,
    this.imageExporter,
    super.key,
  });

  final File? file;
  final String logDomain;
  final ImageExporter? imageExporter;

  @override
  State<ImageViewerDownloadButton> createState() =>
      _ImageViewerDownloadButtonState();
}

class _ImageViewerDownloadButtonState extends State<ImageViewerDownloadButton> {
  bool _isDownloading = false;

  Future<void> _downloadImage() async {
    final file = widget.file;
    if (_isDownloading || file == null) return;

    setState(() => _isDownloading = true);
    try {
      final exporter = widget.imageExporter ?? defaultImageExporter();
      final result = await exporter(file);
      if (!mounted) return;
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
          break;
      }
    } on Object catch (error, stackTrace) {
      getIt<LoggingService>().captureException(
        error,
        domain: widget.logDomain,
        subDomain: 'downloadImage',
        stackTrace: stackTrace,
      );
      if (mounted) {
        _showSnackBar(context.messages.imageViewerDownloadFailed);
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ImageViewerIconButton(
      tooltip: _isDownloading
          ? context.messages.imageViewerDownloadingTooltip
          : context.messages.imageViewerDownloadTooltip,
      icon: _isDownloading ? LottiIcons.pending : LottiIcons.download,
      onPressed: _isDownloading || widget.file == null
          ? null
          : () => unawaited(_downloadImage()),
    );
  }
}

/// Locale-aware date chip shared by all full-screen image viewer modes.
class ImageViewerDateChip extends StatelessWidget {
  const ImageViewerDateChip({required this.date, super.key});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toString();
    return ImageViewerPill(
      alpha: 0.62,
      child: Text(
        DateFormat.yMMMd(locale).format(date.toLocal()),
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Passive tap recognizer for an image canvas.
///
/// A [Listener] observes pointers without joining `photo_view`'s gesture arena,
/// so scale/pan and double-tap zoom keep their native handling. Only a
/// stationary one-finger tap toggles the chrome; the callback waits through
/// [kDoubleTapTimeout] and is cancelled by a second tap.
class ImageViewerTapRegion extends StatefulWidget {
  const ImageViewerTapRegion({
    required this.onSingleTap,
    required this.child,
    super.key,
  });

  final VoidCallback onSingleTap;
  final Widget child;

  @override
  State<ImageViewerTapRegion> createState() => _ImageViewerTapRegionState();
}

class _ImageViewerTapRegionState extends State<ImageViewerTapRegion> {
  final Set<int> _activePointers = {};
  Offset? _origin;
  bool _disqualified = false;
  Timer? _pendingTap;

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointers.isEmpty) {
      _origin = event.position;
      _disqualified = false;
    }
    _activePointers.add(event.pointer);
    if (_activePointers.length > 1) _disqualified = true;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final origin = _origin;
    if (origin != null && (event.position - origin).distance > kTouchSlop) {
      _disqualified = true;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.isNotEmpty || _disqualified) return;

    final pendingTap = _pendingTap;
    if (pendingTap?.isActive ?? false) {
      pendingTap!.cancel();
      _pendingTap = null;
      return;
    }
    _pendingTap = Timer(kDoubleTapTimeout, () {
      _pendingTap = null;
      if (mounted) widget.onSingleTap();
    });
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _activePointers.remove(event.pointer);
    _disqualified = true;
  }

  @override
  void dispose() {
    _pendingTap?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: widget.child,
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
              icon: LottiIcons.remove,
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
              icon: LottiIcons.add,
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
