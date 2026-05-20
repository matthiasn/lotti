import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Maximum dimension for reference images sent to Gemini.
/// Images larger than this are resized to fit within this boundary.
const int kMaxReferenceDimension = 2000;

/// Maximum number of reference images allowed.
const int kMaxReferenceImages = 5;

/// Represents a processed reference image ready for API submission.
class ProcessedReferenceImage {
  const ProcessedReferenceImage({
    required this.base64Data,
    required this.mimeType,
    required this.originalId,
  });

  final String base64Data;
  final String mimeType;
  final String originalId;
}

/// Detects the MIME type of image bytes using common magic headers first and
/// the file extension as a fallback.
String detectImageMimeType(List<int> bytes, {String? filePath}) {
  if (_startsWith(bytes, const [0xFF, 0xD8, 0xFF])) {
    return 'image/jpeg';
  }
  if (_startsWith(
    bytes,
    const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
  )) {
    return 'image/png';
  }
  if (_startsWith(bytes, 'GIF87a'.codeUnits) ||
      _startsWith(bytes, 'GIF89a'.codeUnits)) {
    return 'image/gif';
  }
  if (_isWebP(bytes)) {
    return 'image/webp';
  }

  final normalizedPath = filePath?.toLowerCase();
  if (normalizedPath != null) {
    if (normalizedPath.endsWith('.png')) return 'image/png';
    if (normalizedPath.endsWith('.gif')) return 'image/gif';
    if (normalizedPath.endsWith('.webp')) return 'image/webp';
    if (normalizedPath.endsWith('.jpg') ||
        normalizedPath.endsWith('.jpeg') ||
        normalizedPath.endsWith('.jfif')) {
      return 'image/jpeg';
    }
  }

  return 'image/jpeg';
}

/// Encodes image bytes as an OpenAI-compatible data URL with the detected MIME
/// type.
String imageDataUrlFromBytes(List<int> bytes, {String? filePath}) {
  final mimeType = detectImageMimeType(bytes, filePath: filePath);
  return 'data:$mimeType;base64,${base64Encode(bytes)}';
}

/// Converts a legacy raw Base64 image string to a data URL while preserving
/// already-normalized data URLs.
String ensureImageDataUrl(
  String image, {
  String fallbackMimeType = 'image/jpeg',
}) {
  if (image.startsWith('data:')) return image;
  return 'data:$fallbackMimeType;base64,$image';
}

bool _startsWith(List<int> bytes, List<int> prefix) {
  if (bytes.length < prefix.length) return false;
  for (var i = 0; i < prefix.length; i++) {
    if (bytes[i] != prefix[i]) return false;
  }
  return true;
}

bool _isWebP(List<int> bytes) {
  return bytes.length >= 12 &&
      _startsWith(bytes, 'RIFF'.codeUnits) &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50;
}

/// Processes an image file for use as a reference image.
///
/// - Reads the file from disk
/// - Resizes if any dimension exceeds [kMaxReferenceDimension] (maintains aspect ratio)
/// - Compresses to JPEG format for consistent output
/// - Converts to Base64
/// - Returns the processed image with metadata
///
/// Note: Output is always JPEG regardless of input format for consistency.
Future<ProcessedReferenceImage?> processReferenceImage({
  required String filePath,
  required String imageId,
}) async {
  final file = File(filePath);
  if (!file.existsSync()) return null;

  ui.Codec? codec;
  ui.Image? image;

  try {
    final bytes = await file.readAsBytes();

    // Decode image to get dimensions
    codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    image = frame.image;
    final width = image.width;
    final height = image.height;

    // Calculate target dimensions that fit within kMaxReferenceDimension
    // while maintaining aspect ratio
    var targetWidth = width;
    var targetHeight = height;

    if (width > kMaxReferenceDimension || height > kMaxReferenceDimension) {
      if (width > height) {
        targetWidth = kMaxReferenceDimension;
        targetHeight = (height * kMaxReferenceDimension / width).round();
      } else {
        targetHeight = kMaxReferenceDimension;
        targetWidth = (width * kMaxReferenceDimension / height).round();
      }
    }

    // Compress and resize the image to JPEG (default format) for consistency
    final compressedBytes = await FlutterImageCompress.compressWithList(
      bytes,
      minWidth: targetWidth,
      minHeight: targetHeight,
      quality: 85,
    );

    return ProcessedReferenceImage(
      base64Data: base64Encode(compressedBytes),
      // Always JPEG since that's what FlutterImageCompress outputs
      mimeType: 'image/jpeg',
      originalId: imageId,
    );
  } catch (e) {
    developer.log(
      'Failed to process reference image $imageId: $e',
      name: 'ImageProcessingUtils',
    );
    return null;
  } finally {
    image?.dispose();
    codec?.dispose();
  }
}
