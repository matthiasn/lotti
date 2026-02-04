import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Maximum dimension for reference images sent to Gemini.
/// Images larger than this are resized to fit within this boundary.
const int kMaxReferenceDimension = 2000;

/// Maximum number of reference images allowed.
const int kMaxReferenceImages = 3;

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

  final bytes = await file.readAsBytes();

  // Decode image to get dimensions
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final width = image.width;
  final height = image.height;
  image.dispose();

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
}
