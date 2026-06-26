import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show MethodChannel;
import 'package:flutter_image_compress/flutter_image_compress.dart'
    as image_compress;
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

final _fakeJpegBytes = Uint8List.fromList([
  0xFF,
  0xD8,
  0xFF,
  0xE0,
  0x00,
  0x10,
  0x4A,
  0x46,
  0x49,
  0x46,
  0x00,
  0x01,
  0x01,
  0x00,
  0x00,
  0x01,
  0x00,
  0x01,
  0x00,
  0x00,
  0xFF,
  0xD9,
]);

final _fakePngBytes = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

Uint8List _fakeBytesForFormat(image_compress.CompressFormat format) {
  return switch (format) {
    image_compress.CompressFormat.png => Uint8List.fromList(_fakePngBytes),
    _ => Uint8List.fromList(_fakeJpegBytes),
  };
}

class FakeImageCompressPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements image_compress.FlutterImageCompressPlatform {
  @override
  Future<Uint8List> compressWithList(
    Uint8List image, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    int inSampleSize = 1,
    bool autoCorrectionAngle = true,
    image_compress.CompressFormat format = image_compress.CompressFormat.jpeg,
    bool keepExif = false,
  }) async {
    return _fakeBytesForFormat(format);
  }

  @override
  Future<Uint8List?> compressWithFile(
    String path, {
    int minWidth = 1920,
    int minHeight = 1080,
    int inSampleSize = 1,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    image_compress.CompressFormat format = image_compress.CompressFormat.jpeg,
    bool keepExif = false,
    int numberOfRetries = 5,
  }) async {
    await _validateSourcePath(path);
    return _fakeBytesForFormat(format);
  }

  @override
  Future<image_compress.XFile?> compressAndGetFile(
    String path,
    String targetPath, {
    int minWidth = 1920,
    int minHeight = 1080,
    int inSampleSize = 1,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    image_compress.CompressFormat format = image_compress.CompressFormat.jpeg,
    bool keepExif = false,
    int numberOfRetries = 5,
  }) async {
    await _validateSourcePath(path);
    final targetFile = File(targetPath);
    await targetFile.create(recursive: true);
    await targetFile.writeAsBytes(_fakeBytesForFormat(format));
    return image_compress.XFile(targetFile.path);
  }

  @override
  Future<Uint8List?> compressAssetImage(
    String assetName, {
    int minWidth = 1920,
    int minHeight = 1080,
    int quality = 95,
    int rotate = 0,
    bool autoCorrectionAngle = true,
    image_compress.CompressFormat format = image_compress.CompressFormat.jpeg,
    bool keepExif = false,
  }) async => _fakeBytesForFormat(format);

  @override
  image_compress.FlutterImageCompressValidator get validator =>
      image_compress.FlutterImageCompressValidator(
        const MethodChannel('flutter_image_compress'),
      );

  @override
  void ignoreCheckSupportPlatform(bool value) {}

  @override
  Future<void> showNativeLog(bool value) async {}
}

Future<void> _validateSourcePath(String path) async {
  final sourceFile = File(path);
  if (!sourceFile.existsSync()) {
    throw FileSystemException('Source image does not exist', path);
  }
  await sourceFile.length();
}

image_compress.FlutterImageCompressPlatform installFakeImageCompressPlatform() {
  final originalPlatform = image_compress.FlutterImageCompressPlatform.instance;
  image_compress.FlutterImageCompressPlatform.instance =
      FakeImageCompressPlatform();
  return originalPlatform;
}

void restoreImageCompressPlatform(
  image_compress.FlutterImageCompressPlatform platform,
) {
  image_compress.FlutterImageCompressPlatform.instance = platform;
}

Future<T> withFakeImageCompressPlatform<T>(
  Future<T> Function() body,
) async {
  final originalPlatform = installFakeImageCompressPlatform();
  try {
    return await body();
  } finally {
    restoreImageCompressPlatform(originalPlatform);
  }
}
