import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:path/path.dart' as p;

/// Fetches one remote seed-media object as bytes.
typedef DemoSeedUrlFetcher = Future<Uint8List> Function(Uri uri);

/// Reports how many seed-media objects have been installed.
typedef DemoSeedMediaProgressCallback =
    void Function({required int completed, required int total});

/// Immutable provenance for one image installed into a seeded demo world.
///
/// [sourceUrl] is optional so small or offline-only fixtures can remain
/// bundled. [assetPath] is an optional fallback for the production demo when
/// the remote object cannot be reached. Every source is checksum pinned.
class DemoSeedMediaSource {
  const DemoSeedMediaSource({
    required this.fileName,
    required this.sha256,
    this.sourceUrl,
    this.assetPath,
  }) : assert(
         sourceUrl != null || assetPath != null,
         'Seed media needs a remote URL or bundled asset path.',
       );

  final String fileName;
  final String sha256;
  final String? sourceUrl;
  final String? assetPath;
}

/// Installs checksum-pinned media before its [JournalImage] rows are written.
class DemoSeedMediaInstaller {
  DemoSeedMediaInstaller({
    this.bundle,
    DemoSeedUrlFetcher? fetchUrl,
    http.Client Function()? httpClientFactory,
    Directory? cacheRoot,
  }) : _fetchUrl =
           fetchUrl ??
           ((uri) => _defaultFetchUrl(
             uri,
             (httpClientFactory ?? http.Client.new)(),
           )),
       _cacheRoot =
           cacheRoot ??
           Directory(
             '${Directory.systemTemp.path}/lotti-demo-seed-media-cache',
           );

  final AssetBundle? bundle;
  final DemoSeedUrlFetcher _fetchUrl;
  final Directory _cacheRoot;

  Future<List<File>> install({
    required Directory documentsDirectory,
    required List<JournalImage> images,
    required Map<String, DemoSeedMediaSource> sources,
    bool allowAssetFallback = true,
    DemoSeedMediaProgressCallback? onProgress,
  }) async {
    final total = images.length;
    onProgress?.call(completed: 0, total: total);
    final installed = <File>[];
    for (final image in images) {
      final source = sources[image.meta.id];
      if (source == null) {
        throw StateError('Missing seed media source for ${image.meta.id}');
      }
      if (source.fileName != image.data.imageFile) {
        throw StateError(
          'Seed media filename ${source.fileName} does not match '
          '${image.data.imageFile} for ${image.meta.id}',
        );
      }
      final bytes = await _loadBytes(
        source,
        allowAssetFallback: allowAssetFallback,
      );
      final target = File(
        getFullImagePath(
          image,
          documentsDirectory: documentsDirectory.path,
        ),
      );
      await target.parent.create(recursive: true);
      await target.writeAsBytes(bytes, flush: true);
      installed.add(target);
      onProgress?.call(completed: installed.length, total: total);
    }
    return installed;
  }

  Future<Uint8List> _loadBytes(
    DemoSeedMediaSource source, {
    required bool allowAssetFallback,
  }) async {
    final sourceUrl = source.sourceUrl;
    if (sourceUrl != null) {
      try {
        return await _remoteBytes(source, Uri.parse(sourceUrl));
      } on _DemoSeedMediaIntegrityException {
        rethrow;
      } catch (error) {
        if (!allowAssetFallback || source.assetPath == null) {
          throw StateError(
            'Could not download required demo seed media $sourceUrl: $error',
          );
        }
      }
    }

    final assetPath = source.assetPath;
    final assetBundle = bundle;
    if (assetPath == null || assetBundle == null) {
      throw StateError(
        'No available seed media source for ${source.fileName}',
      );
    }
    final data = await assetBundle.load(assetPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    _verify(bytes, source);
    return bytes;
  }

  Future<Uint8List> _remoteBytes(
    DemoSeedMediaSource source,
    Uri uri,
  ) async {
    final cached = File(p.join(_cacheRoot.path, source.sha256));
    if (cached.existsSync()) {
      final bytes = await cached.readAsBytes();
      try {
        _verify(bytes, source);
        return bytes;
      } on _DemoSeedMediaIntegrityException {
        await cached.delete();
      }
    }

    final bytes = await _fetchUrl(uri);
    _verify(bytes, source);
    await _cacheRoot.create(recursive: true);
    await cached.writeAsBytes(bytes, flush: true);
    return bytes;
  }

  static void _verify(Uint8List bytes, DemoSeedMediaSource source) {
    final actual = sha256.convert(bytes).toString();
    if (actual != source.sha256) {
      throw _DemoSeedMediaIntegrityException(
        'Checksum mismatch for ${source.fileName}: '
        'expected ${source.sha256}, got $actual',
      );
    }
  }

  static Future<Uint8List> _defaultFetchUrl(
    Uri uri,
    http.Client client,
  ) async {
    try {
      final response = await client.get(uri);
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Seed media returned HTTP ${response.statusCode}',
          uri: uri,
        );
      }
      return response.bodyBytes;
    } finally {
      client.close();
    }
  }
}

class _DemoSeedMediaIntegrityException implements Exception {
  const _DemoSeedMediaIntegrityException(this.message);

  final String message;

  @override
  String toString() => message;
}
