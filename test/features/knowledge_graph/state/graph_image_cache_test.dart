import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/knowledge_graph/state/graph_image_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A real decoded image (the cache's ownership semantics are about actual
  /// `ui.Image` disposal, so fakes would prove nothing).
  ui.Image makeImage([int extent = 4]) {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      ui.Rect.fromLTWH(0, 0, extent.toDouble(), extent.toDouble()),
      ui.Paint()..color = const ui.Color(0xFF3366CC),
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(extent, extent);
    picture.dispose();
    return image;
  }

  group('GraphImageCache', () {
    test('stores thumbnails by path and reports their decode extent', () {
      final cache = GraphImageCache();
      final image = makeImage();

      expect(cache.put('/a.png', image, extent: 112), isNull);

      expect(cache.imageOf('/a.png'), same(image));
      expect(cache.decodedExtentOf('/a.png'), 112);
      expect(cache.imageOf('/missing.png'), isNull);
      expect(cache.decodedExtentOf('/missing.png'), 0);

      cache.dispose();
      expect(image.debugDisposed, isTrue);
    });

    test(
      'snapshot is unmodifiable and a fresh map per call, so identity-based '
      'shouldRepaint sees cache updates',
      () {
        final cache = GraphImageCache();
        final image = makeImage();
        cache.put('/a.png', image, extent: 112);

        final first = cache.snapshot();
        final second = cache.snapshot();
        expect(first, {'/a.png': image});
        expect(identical(first, second), isFalse);
        expect(
          () => first['/b.png'] = image,
          throwsUnsupportedError,
        );

        cache.dispose();
      },
    );

    test(
      'put hands back a displaced image for deferred disposal instead of '
      'disposing it',
      () {
        final cache = GraphImageCache();
        final small = makeImage();
        final large = makeImage(8);

        cache.put('/a.png', small, extent: 112);
        final displaced = cache.put('/a.png', large, extent: 224);

        expect(displaced, same(small));
        // Ownership passed to the caller: still paintable until the caller
        // has swapped its painter snapshot and disposes it.
        expect(small.debugDisposed, isFalse);
        expect(cache.imageOf('/a.png'), same(large));
        expect(cache.decodedExtentOf('/a.png'), 224);

        displaced!.dispose();
        cache.dispose();
        expect(large.debugDisposed, isTrue);
      },
    );

    test('re-putting the identical image displaces nothing', () {
      final cache = GraphImageCache();
      final image = makeImage();

      cache.put('/a.png', image, extent: 112);
      expect(cache.put('/a.png', image, extent: 224), isNull);
      expect(cache.decodedExtentOf('/a.png'), 224);

      cache.dispose();
      expect(image.debugDisposed, isTrue);
    });

    test(
      'put withholds a displaced image that another path still references',
      () {
        final cache = GraphImageCache();
        final shared = makeImage();
        final replacementA = makeImage(8);
        final replacementB = makeImage(8);

        // Test image loaders may register one image under several paths.
        cache
          ..put('/a.png', shared, extent: 112)
          ..put('/b.png', shared, extent: 112);

        // Still referenced by /b.png — must not be handed out for disposal.
        expect(cache.put('/a.png', replacementA, extent: 112), isNull);
        expect(shared.debugDisposed, isFalse);

        // Last reference gone — now it is the caller's to dispose.
        expect(
          cache.put('/b.png', replacementB, extent: 112),
          same(shared),
        );

        shared.dispose();
        cache.dispose();
      },
    );

    test('retainOnly disposes dropped thumbnails and keeps retained ones', () {
      final cache = GraphImageCache();
      final kept = makeImage();
      final dropped = makeImage();
      cache
        ..put('/kept.png', kept, extent: 112)
        ..put('/dropped.png', dropped, extent: 112)
        ..retainOnly({'/kept.png'});

      expect(dropped.debugDisposed, isTrue);
      expect(kept.debugDisposed, isFalse);
      expect(cache.imageOf('/kept.png'), same(kept));
      expect(cache.imageOf('/dropped.png'), isNull);

      cache.dispose();
      expect(kept.debugDisposed, isTrue);
    });

    test(
      'retainOnly keeps a shared image alive while any path retains it and '
      'disposes it exactly once when the last path goes',
      () {
        final cache = GraphImageCache();
        final shared = makeImage();
        cache
          ..put('/a.png', shared, extent: 112)
          ..put('/b.png', shared, extent: 112)
          ..retainOnly({'/a.png'});

        expect(shared.debugDisposed, isFalse);
        expect(cache.imageOf('/a.png'), same(shared));

        // A double-dispose would throw; surviving this call proves "once".
        cache.retainOnly(const {});
        expect(shared.debugDisposed, isTrue);

        cache.dispose();
      },
    );

    test('dispose disposes shared entries once and is idempotent', () {
      final cache = GraphImageCache();
      final shared = makeImage();
      final single = makeImage();
      cache
        ..put('/a.png', shared, extent: 112)
        ..put('/b.png', shared, extent: 112)
        ..put('/c.png', single, extent: 112)
        ..dispose();

      expect(shared.debugDisposed, isTrue);
      expect(single.debugDisposed, isTrue);

      // Second dispose must not attempt to re-dispose anything.
      cache.dispose();
    });

    // Property: over any op sequence, honoring the ownership contract
    // (dispose what `put` hands back) never disposes a stored image and
    // never leaks one — after cache.dispose every created image is disposed
    // exactly once. Ops decode as: value % 4 -> path index, value ~/ 4 % 2 ->
    // put vs retainOnly (retain keeps the paths whose bit is set in value).
    glados.Glados(
      glados.any.nonEmptyList(glados.any.intInRange(0, 64)),
      glados.ExploreConfig(numRuns: 48),
    ).test('ownership invariant holds for any put/retainOnly sequence', (
      ops,
    ) {
      const paths = ['/p0.png', '/p1.png', '/p2.png', '/p3.png'];
      final cache = GraphImageCache();
      final created = <ui.Image>[];

      for (final op in ops) {
        if ((op ~/ 4).isEven) {
          final image = makeImage();
          created.add(image);
          final displaced = cache.put(paths[op % 4], image, extent: 112);
          displaced?.dispose();
        } else {
          cache.retainOnly({
            for (var bit = 0; bit < paths.length; bit++)
              if ((op >> bit).isOdd) paths[bit],
          });
        }
        // No stored image may ever be handed out or disposed.
        for (final path in paths) {
          expect(cache.imageOf(path)?.debugDisposed ?? false, isFalse);
        }
      }

      cache.dispose();
      for (final image in created) {
        // Disposed exactly once: a second dispose here would throw.
        expect(image.debugDisposed, isTrue);
      }
    }, tags: 'glados');
  });
}
