import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/demo/media/demo_media_asset.dart';
import 'package:lotti/features/demo/seed/demo_seed_text.dart';
import 'package:lotti/features/demo/seed/demo_world.dart';
import 'package:lotti/features/demo/seed/demo_world_ai.dart';
import 'package:lotti/utils/image_utils.dart';

export 'package:lotti/features/demo/seed/demo_world.dart';

// Compatibility shim: the ManualDemoWorld fixture was promoted to
// `lib/features/demo/seed/` so the production demo seeder and the manual
// screenshot suites share one source of truth. This file keeps the ~15 test
// consumers and the tutorial harness compiling unmodified: it re-exports the
// moved fixture, materializes the historical AI-config top-level finals
// (preserving their lazy, environment-locale-resolving semantics), and hosts
// the two helpers that genuinely depend on `flutter_test`.

/// Provider rows shared by AI settings, profile pickers, and skill flows.
final List<AiConfigInferenceProvider> manualDemoAiProviders = demoAiProviders(
  demoSeedTextFromEnvironment(),
  manualDemoNow,
);

/// Saved model rows used throughout the manual's AI examples.
final List<AiConfigModel> manualDemoAiModels = demoAiModels(
  demoSeedTextFromEnvironment(),
  manualDemoNow,
);

/// Inference profiles demonstrate cloud, local-first, and specialist routing.
final List<AiConfigInferenceProfile> manualDemoAiProfiles = demoAiProfiles(
  demoSeedTextFromEnvironment(),
  manualDemoNow,
);

/// Available actions shown over the orbital-habitat task in the AI menu.
final List<AiConfigSkill> manualDemoAiSkills = demoAiSkills(
  demoSeedTextFromEnvironment(),
  manualDemoNow,
);

typedef ManualDemoMediaProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments,
    );

/// Testable process-backed downloader for manual screenshot R2 assets.
class ManualDemoMediaDownloader {
  ManualDemoMediaDownloader({ManualDemoMediaProcessRunner? run})
    : _run = run ?? _runCurl;

  final ManualDemoMediaProcessRunner _run;
  final Map<Uri, Future<Uint8List>> _cache = {};

  static Future<ProcessResult> _runCurl(
    String executable,
    List<String> arguments,
  ) => Process.run(executable, arguments, stdoutEncoding: null);

  Future<Uint8List> call(Uri uri) => _cache.putIfAbsent(uri, () async {
    final arguments = [
      '--fail',
      '--silent',
      '--show-error',
      '--location',
      '--max-time',
      '30',
      uri.toString(),
    ];
    final result = await _run('curl', arguments);
    if (result.exitCode != 0) {
      throw ProcessException(
        'curl',
        arguments,
        result.stderr.toString(),
        result.exitCode,
      );
    }
    return Uint8List.fromList(result.stdout as List<int>);
  });
}

final _manualDemoMediaDownloader = ManualDemoMediaDownloader();

/// Downloads one R2 demo asset outside Flutter's widget-test HTTP override.
///
/// `TestWidgetsFlutterBinding` replaces Dart `HttpClient` responses with HTTP
/// 400, while manual screenshots need the real catalog pixels. The external
/// `curl` process is scoped to this test helper, and successful downloads are
/// cached for the lifetime of the test process so each object is fetched once.
Future<Uint8List> downloadManualDemoMedia(Uri uri) =>
    _manualDemoMediaDownloader(uri);

/// Materializes the manual fixture from R2 for a widget screenshot suite.
///
/// Installs the cover art by default; pass [images] to install a wider slice
/// of the catalog, e.g. `world.images` for a task detail page whose attached
/// photos must resolve too. [download] defaults to the `curl` downloader,
/// which a widget test needs because the test binding answers every Dart
/// `HttpClient` request with HTTP 400 — a device harness under
/// `flutter drive` has no such override and no `curl`, so it passes an
/// in-process downloader instead.
Future<List<File>> installManualDemoMedia(
  ManualDemoWorld world,
  Directory documentsDirectory, {
  Iterable<JournalImage>? images,
  Future<Uint8List> Function(Uri uri) download = downloadManualDemoMedia,
}) {
  final imageIds = (images ?? world.coverImages)
      .map((image) => image.meta.id)
      .toSet();
  final catalog = demoMediaAssets
      .where((asset) => imageIds.contains(asset.id))
      .toList();
  return world.installMedia(
    documentsDirectory,
    download: download,
    catalog: catalog,
  );
}

/// Re-encodes installed manual artwork as PNG bytes in place.
///
/// The headless Flutter test engine can leave resized WebP decoding pending,
/// while production widgets correctly resolve the same files on devices. PNG
/// bytes keep screenshot captures deterministic; image codecs detect the bytes
/// rather than relying on the retained `.webp` filenames.
Future<void> transcodeManualDemoMediaToPng(List<File> files) async {
  for (final file in files) {
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    final frame = await codec.getNextFrame();
    final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    await file.writeAsBytes(png!.buffer.asUint8List(), flush: true);
    frame.image.dispose();
    codec.dispose();
  }
}

/// Primes the production image-provider keys with decoded cover art.
///
/// The headless Flutter test engine can leave resized WebP decoding pending
/// indefinitely even though the raw file decodes successfully. Production
/// widgets still construct and resolve their normal providers; this helper
/// only seeds the test image cache before the first frame so screenshots paint
/// the same bitmap deterministically. Raw [FileImage] keys can also be primed
/// for production surfaces that render unresized reference images.
Future<void> primeManualDemoCoverArt(
  WidgetTester tester, {
  required Directory documentsDirectory,
  required ManualDemoWorld world,
  List<int> extents = const [48, 96, 144, 216, 1280, 2048, 3072],
  Set<String>? imageIds,
  bool includeRawFileImage = false,
}) async {
  await tester.runAsync(() async {
    final coverImages = imageIds == null
        ? world.coverImages
        : world.coverImages.where(
            (coverImage) => imageIds.contains(coverImage.meta.id),
          );
    for (final coverImage in coverImages) {
      final file = File(
        getFullImagePath(
          coverImage,
          documentsDirectory: documentsDirectory.path,
        ),
      );
      final fileImage = FileImage(file);
      final bytes = await file.readAsBytes();
      final cache = PaintingBinding.instance.imageCache;
      if (includeRawFileImage) {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final key = await fileImage.obtainKey(ImageConfiguration.empty);
        cache
          ..evict(key)
          ..putIfAbsent(
            key,
            () => OneFrameImageStreamCompleter(
              SynchronousFuture(
                ImageInfo(image: frame.image.clone()),
              ),
            ),
          );
        frame.image.dispose();
        codec.dispose();
      }
      for (final extent in extents) {
        final providers = [
          ResizeImage(
            fileImage,
            width: extent,
            height: extent,
            policy: ResizeImagePolicy.fit,
          ),
          ResizeImage(
            fileImage,
            width: extent,
            policy: ResizeImagePolicy.fit,
          ),
        ];
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: extent,
          allowUpscaling: false,
        );
        final frame = await codec.getNextFrame();
        for (final provider in providers) {
          final key = await provider.obtainKey(ImageConfiguration.empty);
          cache
            ..evict(key)
            ..putIfAbsent(
              key,
              () => OneFrameImageStreamCompleter(
                SynchronousFuture(
                  ImageInfo(image: frame.image.clone()),
                ),
              ),
            );
        }
        frame.image.dispose();
        codec.dispose();
      }
    }
  });
}
