import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/events/ui/model/event_view_data.dart';
import 'package:lotti/themes/theme.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// A compact, scannable grid of an event's photos (uniform cover-cropped
/// squares, like a photo library). Derives its column count from the available
/// width and, when there are more photos than fit the preview, caps the grid
/// and marks the last tile with a "+N" overflow badge. Tapping any tile opens
/// the full-screen, swipeable [EventPhotoGalleryViewer] at that photo.
class EventPhotoGrid extends StatelessWidget {
  const EventPhotoGrid({required this.photos, super.key});

  final List<EventPhoto> photos;

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
                  onTap: () => openEventPhotoViewer(
                    context,
                    photos: photos,
                    initialIndex: i,
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
    required this.onTap,
  });

  final EventPhoto photo;
  final double radius;
  final int index;
  final int overflow;
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
          Material(
            color: Colors.transparent,
            child: InkWell(onTap: onTap),
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
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => EventPhotoGalleryViewer(
        photos: photos,
        initialIndex: initialIndex,
      ),
    ),
  );
}

/// Full-screen, swipeable, zoomable viewer for an event's photos, with a page
/// indicator and a close button (mirroring the journal entry image viewer).
class EventPhotoGalleryViewer extends StatefulWidget {
  const EventPhotoGalleryViewer({
    required this.photos,
    this.initialIndex = 0,
    super.key,
  });

  final List<EventPhoto> photos;
  final int initialIndex;

  @override
  State<EventPhotoGalleryViewer> createState() =>
      _EventPhotoGalleryViewerState();
}

class _EventPhotoGalleryViewerState extends State<EventPhotoGalleryViewer> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoViewGallery.builder(
            pageController: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (i) => setState(() => _index = i),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            builder: (context, i) => PhotoViewGalleryPageOptions(
              imageProvider: widget.photos[i].image,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
              heroAttributes: PhotoViewHeroAttributes(tag: 'event_photo_$i'),
            ),
          ),
          // Page indicator (e.g. "3 / 12").
          if (widget.photos.length > 1)
            Positioned(
              top: MediaQuery.paddingOf(context).top + tokens.spacing.step3,
              left: 0,
              right: 0,
              child: Center(
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
            ),
          Positioned(
            right: 0,
            top: MediaQuery.paddingOf(context).top,
            child: IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              padding: EdgeInsets.all(tokens.spacing.step6),
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              icon: Stack(
                children: [
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: const Icon(Icons.close_rounded, size: 30),
                  ),
                  const Icon(
                    Icons.close_rounded,
                    size: 30,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
