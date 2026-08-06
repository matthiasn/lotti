/// Decoded-thumbnail store for the knowledge-graph explorer.
///
/// `KnowledgeGraphView` derives its state once in `initState`, so its host
/// remounts it (via a scenario-keyed `ValueKey`) whenever fresh graph data
/// arrives — walking to a linked task, a sync refresh, any DB notification.
/// Without a cache that outlives those remounts, every decoded `ui.Image`
/// dies with the old state and the canvas flashes imageless while the new
/// state re-decodes the same files. The page owns one [GraphImageCache]
/// across remounts so already-decoded thumbnails are available synchronously
/// on the remounted view's very first frame.
library;

import 'dart:ui' as ui;

class _CacheEntry {
  const _CacheEntry(this.image, this.extent);

  final ui.Image image;

  /// Longest-side pixel extent the image was decoded at — lets callers skip
  /// re-decoding a path whose cached thumbnail already meets their target.
  final int extent;
}

/// Owns decoded graph thumbnails keyed by source-file path.
///
/// The cache is the images' owner: callers must never dispose an image that is
/// still stored here. [put] hands back a displaced image instead of disposing
/// it, so the caller can defer disposal until no painter references it.
class GraphImageCache {
  final Map<String, _CacheEntry> _entries = {};
  bool _disposed = false;

  /// The decoded thumbnail for [path], or null when none is cached.
  ui.Image? imageOf(String path) => _entries[path]?.image;

  /// The extent [path]'s thumbnail was decoded at (0 when absent).
  int decodedExtentOf(String path) => _entries[path]?.extent ?? 0;

  /// Immutable path → image view of the cache, suitable for handing straight
  /// to the painter. Each call returns a fresh map so identity-based
  /// `shouldRepaint` checks see cache updates.
  Map<String, ui.Image> snapshot() => Map.unmodifiable(<String, ui.Image>{
    for (final MapEntry(:key, :value) in _entries.entries) key: value.image,
  });

  /// Stores [image] as the thumbnail for [path], decoded at [extent].
  ///
  /// Returns the image it displaces once it is safe to dispose — i.e. when a
  /// different image was stored for [path] and no other entry still references
  /// that object. The caller disposes it after swapping its painter snapshot,
  /// so an in-flight frame never paints a disposed image.
  ui.Image? put(String path, ui.Image image, {required int extent}) {
    assert(!_disposed, 'GraphImageCache used after dispose');
    final previous = _entries[path]?.image;
    _entries[path] = _CacheEntry(image, extent);
    if (previous == null || identical(previous, image)) return null;
    return _isReferenced(previous) ? null : previous;
  }

  /// Drops entries whose path is not in [keep] and disposes their images
  /// (unless a kept entry still references the same object).
  void retainOnly(Set<String> keep) {
    assert(!_disposed, 'GraphImageCache used after dispose');
    final removed = <ui.Image>[];
    _entries.removeWhere((path, entry) {
      if (keep.contains(path)) return false;
      removed.add(entry.image);
      return true;
    });
    _disposeUnique(removed, retainedInEntries: true);
  }

  /// Disposes every cached image. The cache must not be used afterwards.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final images = [for (final entry in _entries.values) entry.image];
    _entries.clear();
    _disposeUnique(images, retainedInEntries: false);
  }

  bool _isReferenced(ui.Image image) =>
      _entries.values.any((entry) => identical(entry.image, image));

  /// Disposes [images], skipping duplicates of already-disposed objects and —
  /// when [retainedInEntries] — objects a live entry still references (a test
  /// image loader may register one image under several paths).
  void _disposeUnique(
    List<ui.Image> images, {
    required bool retainedInEntries,
  }) {
    final disposed = <ui.Image>[];
    for (final image in images) {
      final skip =
          (retainedInEntries && _isReferenced(image)) ||
          disposed.any((candidate) => identical(candidate, image));
      if (skip) continue;
      image.dispose();
      disposed.add(image);
    }
  }
}
