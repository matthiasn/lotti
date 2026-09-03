import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/features/journal/ui/widgets/entry_image_widget.dart';
import 'package:lotti/features/journal/util/image_export_service.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/media/image_viewer_orientation_scope.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// A compact, scannable grid of an event's photos (uniform cover-cropped
/// squares, like a photo library). Derives its column count from the available
/// width and, when there are more photos than fit the preview, caps the grid
/// and marks the last tile with a "+N" overflow badge. Tapping any tile opens
/// the full-screen, swipeable [EventPhotoGalleryViewer] at that photo.
///
/// The chosen cover ([EventPhoto.isCover]) wears a "Cover" badge, and
/// [onSetCover] — forwarded to the viewer — is how any other photo becomes it.
class EventPhotoGrid extends StatelessWidget {
  const EventPhotoGrid({required this.photos, this.onSetCover, super.key});

  final List<EventPhoto> photos;

  /// Makes the photo with this id the event's cover and reports whether the
  /// write was stored, so the viewer can undo its optimistic state when it
  /// was not. Null leaves the gallery read-only: no action in the viewer.
  final Future<bool> Function(String id)? onSetCover;

  /// Target tile edge; the column count is derived from the available width.
  static const double _targetTile = 116;

  /// Rows shown inline before the grid caps with a "+N" overflow tile.
  static const int _previewRows = 3;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final gap = tokens.spacing.step1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / _targetTile).floor().clamp(
          3,
          6,
        );
        final tile = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final previewCount = columns * _previewRows;
        final capped = photos.length > previewCount;
        final tileCount = capped ? previewCount : photos.length;
        // The "+N" tile stands for its own photo and every hidden one; when
        // the chosen cover is among those, the tile wears the badge so a
        // photo-heavy event never reads as "nothing chosen".
        final coverBehindOverflow =
            capped && photos.skip(tileCount - 1).any((photo) => photo.isCover);

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < tileCount; i++)
              SizedBox(
                width: tile,
                height: tile,
                child: _PhotoTile(
                  photo: photos[i],
                  radius: tokens.radii.s,
                  index: i,
                  // The last visible tile carries the "+N" badge for the rest.
                  overflow: capped && i == tileCount - 1
                      ? photos.length - tileCount + 1
                      : 0,
                  showCoverBadge:
                      photos[i].isCover ||
                      (coverBehindOverflow && i == tileCount - 1),
                  onTap: () => openEventPhotoViewer(
                    context,
                    photos: photos,
                    initialIndex: i,
                    onSetCover: onSetCover,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    required this.photo,
    required this.radius,
    required this.index,
    required this.overflow,
    required this.showCoverBadge,
    required this.onTap,
  });

  final EventPhoto photo;
  final double radius;
  final int index;
  final int overflow;

  /// Whether this tile wears the "Cover" badge: its own photo is the chosen
  /// cover, or it is the "+N" tile and the chosen cover is behind it.
  final bool showCoverBadge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Matches the viewer's PhotoViewHeroAttributes tag so tapping a tile
          // animates into the full-screen viewer for that photo.
          Hero(
            tag: 'event_photo_$index',
            child: Image(
              // Downsample to the tile so a wall of full-res photos doesn't
              // blow up memory.
              image: ResizeImage(
                photo.image,
                width: 360,
                policy: ResizeImagePolicy.fit,
              ),
              fit: BoxFit.cover,
              alignment: Alignment(photo.cropX * 2 - 1, 0),
              errorBuilder: (context, error, stackTrace) =>
                  ColoredBox(color: cs.surfaceContainerHighest),
            ),
          ),
          if (overflow > 0)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.5),
              child: Center(
                child: Text(
                  '+$overflow',
                  style: context.designTokens.typography.styles.heading.heading3
                      .copyWith(color: Colors.white),
                ),
              ),
            ),
          if (showCoverBadge)
            Positioned(
              top: context.designTokens.spacing.step1,
              left: context.designTokens.spacing.step1,
              child: const _CoverBadge(),
            ),
          Material(
            color: Colors.transparent,
            child: InkWell(onTap: onTap),
          ),
        ],
      ),
    );
  }
}

/// Marks the grid tile that is the event's chosen cover, in the viewer
/// chrome's own idiom (scrim pill, white glyph and word) so the grid and the
/// full-screen "Cover" state read as one thing.
class _CoverBadge extends StatelessWidget {
  const _CoverBadge();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return ImageViewerPill(
      alpha: 0.62,
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step2,
        vertical: tokens.spacing.step1,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LottiIcons.confirmCircled,
            size: tokens.spacing.step4,
            color: Colors.white,
          ),
          SizedBox(width: tokens.spacing.step1),
          Text(
            context.messages.coverArtChipActive,
            style: tokens.typography.styles.subtitle.subtitle2.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the full-screen swipeable photo viewer at [initialIndex].
Future<void> openEventPhotoViewer(
  BuildContext context, {
  required List<EventPhoto> photos,
  required int initialIndex,
  Future<bool> Function(String id)? onSetCover,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => EventPhotoGalleryViewer(
        photos: photos,
        initialIndex: initialIndex,
        onSetCover: onSetCover,
      ),
    ),
  );
}

/// Full-screen, swipeable, zoomable viewer for an event's photos, with a page
/// indicator and a close button (mirroring the journal entry image viewer).
///
/// With [onSetCover] wired, the chrome carries a "Set cover" pill for the
/// photo in view — the place to say "this one" while looking at it — which
/// reads "Cover", inert, on the photo that already is.
class EventPhotoGalleryViewer extends StatefulWidget {
  const EventPhotoGalleryViewer({
    required this.photos,
    this.initialIndex = 0,
    this.imageExporter,
    this.onSetCover,
    super.key,
  });

  final List<EventPhoto> photos;
  final int initialIndex;
  final ImageExporter? imageExporter;

  /// Makes the photo with this id the event's cover and reports whether it
  /// was stored; a rejected (`false`) or throwing write takes the optimistic
  /// "Cover" state back and is told to the user. Null hides the control.
  final Future<bool> Function(String id)? onSetCover;

  @override
  State<EventPhotoGalleryViewer> createState() =>
      _EventPhotoGalleryViewerState();
}

class _EventPhotoGalleryViewerState extends State<EventPhotoGalleryViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;
  bool _overlaysVisible = true;

  /// The chosen cover as this viewer knows it. Seeded from the photos and
  /// advanced optimistically on "Set cover": the viewer sits on the root
  /// navigator with a snapshot of the photos, so the page's refresh does not
  /// reach it, and the pill must still flip to "Cover" at once.
  late String? _coverId = widget.photos
      .firstWhereOrNull((photo) => photo.isCover)
      ?.id;

  EventPhoto get _currentPhoto => widget.photos[_index];

  void _toggleOverlays() {
    setState(() => _overlaysVisible = !_overlaysVisible);
  }

  /// Flips the pill first and writes second. A write the callback reports as
  /// not stored, or that throws, takes the pill back to what it said and
  /// tells the user with the shared save-failed line — so the viewer never
  /// keeps a "Cover" the store disagrees with. A thrown error is also
  /// captured the way the download button's failures are; a `false` has
  /// already been logged by whoever rejected it.
  Future<void> _setCurrentAsCover(String id) async {
    final previous = _coverId;
    setState(() => _coverId = id);
    var stored = false;
    try {
      stored = await widget.onSetCover!(id);
    } on Object catch (error, stackTrace) {
      getIt<LoggingService>().captureException(
        error,
        domain: 'event_photo_gallery',
        subDomain: 'setCover',
        stackTrace: stackTrace,
      );
    }
    if (stored || !mounted) return;
    setState(() => _coverId = previous);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.messages.saveFailedRetry)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final padding = MediaQuery.paddingOf(context);
    return ImageViewerOrientationScope(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            ImageViewerTapRegion(
              onSingleTap: _toggleOverlays,
              child: PhotoViewGallery.builder(
                pageController: _controller,
                itemCount: widget.photos.length,
                // PhotoViewGallery defaults rotation off; do not opt in here.
                onPageChanged: (i) => setState(() => _index = i),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                builder: (context, i) => PhotoViewGalleryPageOptions(
                  imageProvider: widget.photos[i].image,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  heroAttributes: PhotoViewHeroAttributes(
                    tag: 'event_photo_$i',
                  ),
                ),
              ),
            ),
            // Page indicator (e.g. "3 / 12"), at the top-left the way the
            // journal's own viewer places its counter: the action cluster on
            // the right has grown a "Set cover" pill, and a centred counter
            // would sit under it on a phone.
            if (_overlaysVisible && widget.photos.length > 1)
              Positioned(
                top: padding.top + tokens.spacing.step3,
                left: padding.left + tokens.spacing.step3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(
                      tokens.radii.badgesPills,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: tokens.spacing.step3,
                      vertical: tokens.spacing.step1,
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.photos.length}',
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            if (_overlaysVisible)
              Positioned(
                right: padding.right + tokens.spacing.step3,
                top: padding.top + tokens.spacing.step3,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onSetCover != null &&
                        _currentPhoto.id != null) ...[
                      if (_currentPhoto.id == _coverId)
                        ImageViewerLabelButton(
                          label: context.messages.coverArtChipActive,
                          icon: LottiIcons.confirmCircled,
                          onPressed: null,
                        )
                      else
                        ImageViewerLabelButton(
                          label: context.messages.coverArtChipSet,
                          icon: LottiIcons.image,
                          onPressed: () =>
                              _setCurrentAsCover(_currentPhoto.id!),
                        ),
                      SizedBox(width: tokens.spacing.step2),
                    ],
                    ImageViewerDownloadButton(
                      file: _currentPhoto.filePath == null
                          ? null
                          : File(_currentPhoto.filePath!),
                      imageExporter: widget.imageExporter,
                      logDomain: 'event_photo_gallery',
                    ),
                    SizedBox(width: tokens.spacing.step2),
                    ImageViewerIconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      icon: LottiIcons.close,
                      onPressed: () =>
                          Navigator.of(context, rootNavigator: true).pop(),
                    ),
                  ],
                ),
              ),
            if (_overlaysVisible && _currentPhoto.displayDate != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: padding.bottom + tokens.spacing.step4,
                child: Center(
                  child: ImageViewerDateChip(
                    date: _currentPhoto.displayDate!,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
