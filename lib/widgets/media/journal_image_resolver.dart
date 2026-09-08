import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/thumbhash.dart';
import 'package:lotti/widgets/media/file_watcher_mixin.dart';
import 'package:material_ui/material_ui.dart';

/// What a `JournalImage` can show *right now*.
///
/// An image entry and its file travel separately — the entry syncs in one
/// message, the bytes in another, a demo cover downloads after its task is
/// seeded, AI cover art is written after its entry exists. So at any moment
/// there are three honest answers to "draw this image": the file, the
/// ThumbHash stand-in the entry carries, or nothing. This is that answer.
@immutable
class ResolvedJournalImage {
  const ResolvedJournalImage({
    required this.path,
    required this.fileExists,
    required this.thumbHash,
  });

  /// Where the file is, or will be.
  final String path;

  /// Whether the bytes are on disk yet.
  final bool fileExists;

  /// The blurred stand-in, or null when the entry carries none (everything
  /// but the demo catalog today) or carries one that does not parse.
  final ThumbHash? thumbHash;

  /// True while there is neither a file nor a stand-in — the host decides
  /// what an honest empty looks like for its shape.
  bool get hasNothingToShow => !fileExists && thumbHash == null;

  /// A value: two resolutions of the same path in the same state are the
  /// same resolution, which is what lets a host that caches by it (a sliver
  /// delegate's `shouldRebuild`) tell "nothing changed" from "the file
  /// landed".
  @override
  bool operator ==(Object other) =>
      other is ResolvedJournalImage &&
      other.path == path &&
      other.fileExists == fileExists &&
      other.thumbHash == thumbHash;

  @override
  int get hashCode => Object.hash(path, fileExists, thumbHash);
}

/// Builds a host's picture from what [JournalImageResolver] resolved, or from
/// `null` while the id does not resolve to a `JournalImage` at all — the
/// entry has not synced yet, was deleted, or is some other entry kind.
typedef ResolvedJournalImageBuilder =
    Widget Function(BuildContext context, ResolvedJournalImage? resolved);

/// Resolves a `JournalImage` id to what can be drawn right now, and rebuilds
/// when that changes: when the entry arrives, and when its file lands on
/// disk. The filesystem watch (or, where the platform refuses one, a
/// bounded poll) is [FileWatcherMixin]'s; this widget only owns *when* to
/// watch and hands the host a [ResolvedJournalImage] to draw.
///
/// Every picture-of-an-entry surface used to carry this loop itself — the
/// task cover thumbnail, the cover background, the journal card image — and
/// each was a near-copy of the others with its own rendering wrapped around
/// the middle. Lifting the loop lets a host be *only* its rendering: a square
/// thumbnail, a circular avatar, a full-bleed background.
class JournalImageResolver extends ConsumerStatefulWidget {
  const JournalImageResolver({
    required this.imageId,
    required this.builder,
    super.key,
  });

  /// The `JournalImage` entry id.
  final String imageId;

  /// Draws the host's picture from the resolution.
  final ResolvedJournalImageBuilder builder;

  @override
  ConsumerState<JournalImageResolver> createState() =>
      _JournalImageResolverState();
}

class _JournalImageResolverState extends ConsumerState<JournalImageResolver>
    with FileWatcherMixin {
  @override
  void didUpdateWidget(JournalImageResolver oldWidget) {
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
    final entry = ref
        .watch(entryControllerProvider(widget.imageId))
        .value
        ?.entry;
    if (entry is! JournalImage) {
      return widget.builder(context, null);
    }
    final path = getFullImagePath(entry);
    setupFileWatcher(path);
    return widget.builder(
      context,
      ResolvedJournalImage(
        path: path,
        fileExists: fileExists,
        thumbHash: ThumbHash.tryParse(entry.data.thumbHash),
      ),
    );
  }
}

/// The file at [path] as an [ImageProvider] decoded no larger than [bounds]
/// logical points at [devicePixelRatio] — the decode a slot actually needs,
/// rather than the full photograph.
///
/// [ResizeImagePolicy.fit] caps both axes while keeping the source's aspect
/// ratio, so a photo is never squashed into the slot's shape; the host's
/// `BoxFit.cover` then crops it. A non-positive bound decodes at full size.
ImageProvider boundedFileImage(
  String path, {
  required Size bounds,
  required double devicePixelRatio,
}) {
  final fileImage = FileImage(File(path));
  if (bounds.width <= 0 || bounds.height <= 0) return fileImage;
  return ResizeImage(
    fileImage,
    width: (bounds.width * devicePixelRatio).round().clamp(1, 10000),
    height: (bounds.height * devicePixelRatio).round().clamp(1, 10000),
    policy: ResizeImagePolicy.fit,
  );
}

/// [boundedFileImage] for a square slot of [size] points — a thumbnail or an
/// avatar.
ImageProvider cappedFileImage(
  String path, {
  required double size,
  required double devicePixelRatio,
}) => boundedFileImage(
  path,
  bounds: Size.square(size),
  devicePixelRatio: devicePixelRatio,
);
