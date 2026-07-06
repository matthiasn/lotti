import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/file_watcher_mixin.dart';
import 'package:lotti/utils/image_utils.dart';

/// Bucket size (physical pixels) for quantizing the decode target.
///
/// Dragging a desktop pane divider changes the layout constraints every
/// frame; deriving the [ResizeImage] dimensions directly from them would
/// mint a new image-cache key per pixel and force an async re-decode on
/// each frame. Rounding up to the next bucket keeps the cache key stable
/// across a whole band of widths so the decoded bitmap is reused while
/// the pane is being resized.
@visibleForTesting
const int coverArtDecodeBucket = 256;

/// Upper bound (physical pixels) for a decode axis, matching the clamp the
/// widget has always applied to keep [ResizeImage] inputs sane.
@visibleForTesting
const int coverArtMaxDecodeExtent = 10000;

/// Maps a layout extent to a quantized decode extent in physical pixels.
///
/// Returns `null` when [maxExtent] is unbounded or not positive (e.g. a
/// SliverAppBar collapse can briefly drive a constraint to 0), or when
/// [devicePixelRatio] is not a positive finite number — `ceil()` on a
/// NaN/infinite product would throw. In either case the caller skips
/// capping that axis. Otherwise the physical size is rounded up to the
/// next multiple of [coverArtDecodeBucket] and capped at
/// [coverArtMaxDecodeExtent].
@visibleForTesting
int? coverArtCacheExtent(double maxExtent, double devicePixelRatio) {
  if (!maxExtent.isFinite ||
      maxExtent <= 0 ||
      !devicePixelRatio.isFinite ||
      devicePixelRatio <= 0) {
    return null;
  }
  final physical = (maxExtent * devicePixelRatio).ceil();
  final buckets = (physical + coverArtDecodeBucket - 1) ~/ coverArtDecodeBucket;
  return math.min(buckets * coverArtDecodeBucket, coverArtMaxDecodeExtent);
}

/// Background widget for displaying task cover art in SliverAppBar.
class CoverArtBackground extends ConsumerStatefulWidget {
  const CoverArtBackground({
    required this.imageId,
    super.key,
  });

  final String imageId;

  @override
  ConsumerState<CoverArtBackground> createState() => _CoverArtBackgroundState();
}

class _CoverArtBackgroundState extends ConsumerState<CoverArtBackground>
    with FileWatcherMixin {
  String? _lastDecodePath;
  int? _lastDecodeExtent;
  ImageProvider? _lastImageProvider;

  /// Evicts the previously built decode variant once a new one supersedes
  /// it (different file or bucket), so a pane drag doesn't accumulate one
  /// cached bitmap per bucket crossed. Invoked from a post-frame callback
  /// so the cache mutation stays out of the build/layout phase. The
  /// on-screen frame is unaffected: with gaplessPlayback the Image widget
  /// holds it independently of the cache.
  void _rememberDecodeVariant({
    required String path,
    required int? cacheExtent,
    required ImageProvider provider,
  }) {
    final previous = _lastImageProvider;
    if (previous != null &&
        (path != _lastDecodePath || cacheExtent != _lastDecodeExtent)) {
      // ImageProvider.evict resolves the provider's cache key first — a
      // ResizeImage is cached under its ResizeImageKey, so passing the
      // provider itself to imageCache.evict would never match an entry.
      unawaited(previous.evict());
    }
    _lastDecodePath = path;
    _lastDecodeExtent = cacheExtent;
    _lastImageProvider = provider;
  }

  @override
  void didUpdateWidget(CoverArtBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageId != widget.imageId) {
      resetFileWatcher();
    }
  }

  @override
  void dispose() {
    disposeFileWatcher();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = entryControllerProvider(widget.imageId);
    final entry = ref.watch(provider).value?.entry;

    if (entry is! JournalImage) {
      return const SizedBox.shrink();
    }

    final path = getFullImagePath(entry);
    setupFileWatcher(path);

    if (!fileExists) {
      return const SizedBox.shrink();
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
            // Quantized decode targets keep the ResizeImage cache key stable
            // while a pane divider is dragged. The cap is derived from the
            // width alone so the key is also invariant under SliverAppBar
            // collapse, where maxHeight shrinks every scrolled frame; the
            // height axis only steps in when the width is unbounded or
            // collapsed to zero. Applying the same cap to both axes with
            // ResizeImagePolicy.fit bounds either dimension for extreme
            // aspect ratios while preserving the source aspect ratio.
            final cacheExtent =
                coverArtCacheExtent(constraints.maxWidth, devicePixelRatio) ??
                coverArtCacheExtent(constraints.maxHeight, devicePixelRatio);
            final fileImage = FileImage(File(path));
            ImageProvider imageProvider = fileImage;
            if (cacheExtent != null) {
              imageProvider = ResizeImage(
                fileImage,
                width: cacheExtent,
                height: cacheExtent,
                policy: ResizeImagePolicy.fit,
              );
            }
            // Defer the variant bookkeeping (and any eviction it triggers)
            // to after the frame — build and layout must stay free of
            // image-cache side effects.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              _rememberDecodeVariant(
                path: path,
                cacheExtent: cacheExtent,
                provider: imageProvider,
              );
            });
            return Image(
              image: imageProvider,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              // Keep showing the previously decoded frame while a new decode
              // (bucket boundary crossed mid-resize) resolves — without this
              // the cover art blanks out on every provider change.
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) {
                // Evict through the provider: the cache is keyed by
                // obtainKey's result (a ResizeImageKey for ResizeImage),
                // so imageCache.evict(imageProvider) would never match.
                unawaited(imageProvider.evict());
                return const SizedBox.shrink();
              },
            );
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                Color(0x99000000),
                Colors.transparent,
              ],
            ),
          ),
          child: SizedBox.expand(),
        ),
      ],
    );
  }
}
