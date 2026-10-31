import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import 'package:lotti/classes/ai/ai_config.dart';
import 'package:lotti/features/ai/repository/mistral_ocr_repository.dart';
import 'package:lotti/services/domain_logging.dart';

/// Maximum dimension for reference images sent to Gemini.
/// Images larger than this are resized to fit within this boundary.
const int kMaxReferenceDimension = 2000;

/// Maximum number of reference images allowed.
const int kMaxReferenceImages = 5;

/// Maximum number of task images accepted by coding-prompt generation.
///
/// Kept separate from [kMaxReferenceImages] because image-generation providers
/// and vision-capable reasoning models may have different practical limits.
const int kMaxCodingPromptImages = 10;

/// Represents a processed reference image ready for API submission.
class ProcessedReferenceImage {
  const ProcessedReferenceImage({
    required this.base64Data,
    required this.mimeType,
  });

  final String base64Data;
  final String mimeType;
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
///
/// A file that cannot be decoded or compressed yields `null`, and the failure
/// is reported to [domainLogger].
Future<ProcessedReferenceImage?> processReferenceImage({
  required String filePath,
  required String imageId,
  required DomainLogger domainLogger,
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

    final (targetWidth, targetHeight) = _fitWithinReferenceDimension(
      width,
      height,
    );

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
    );
  } catch (e, stackTrace) {
    domainLogger.error(
      LogDomain.ai,
      e,
      stackTrace: stackTrace,
      subDomain: 'ImageProcessingUtils',
      message: 'Failed to process reference image $imageId',
    );
    return null;
  } finally {
    image?.dispose();
    codec?.dispose();
  }
}

/// Image-analysis uploads above this many bytes are re-encoded, see
/// [downscaleImageForUpload].
const int kMaxImageUploadBytes = 5 * 1024 * 1024;

/// [bytes] made small enough to upload for image analysis: when the image is
/// wider or taller than [kMaxReferenceDimension], or larger than [maxBytes],
/// it is scaled to fit [kMaxReferenceDimension] (keeping its aspect ratio) and
/// re-encoded as JPEG, in memory. Only the upload changes; the stored file is
/// never touched.
///
/// Works on every platform: the engine decodes straight to the target size
/// and the pure-Dart `image` package encodes the JPEG off the UI isolate.
/// flutter_image_compress is not used here because it has no Linux or
/// Windows implementation, where a 50 MB photo would go out unchanged.
///
/// Images within both limits come back unchanged, byte for byte. So does an
/// image that cannot be read or re-encoded — the provider then gets the
/// original, exactly as before — with the failure reported to [domainLogger].
Future<Uint8List> downscaleImageForUpload(
  Uint8List bytes, {
  required String imageId,
  required DomainLogger domainLogger,
  int maxBytes = kMaxImageUploadBytes,
}) async {
  ui.ImmutableBuffer? buffer;
  ui.ImageDescriptor? descriptor;
  ui.Codec? codec;
  ui.Image? image;
  try {
    // Reads the header for the dimensions without decoding the pixels.
    buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    final width = descriptor.width;
    final height = descriptor.height;
    if (bytes.length <= maxBytes &&
        width <= kMaxReferenceDimension &&
        height <= kMaxReferenceDimension) {
      return bytes;
    }
    final (targetWidth, targetHeight) = _fitWithinReferenceDimension(
      width,
      height,
    );
    codec = await descriptor.instantiateCodec(
      targetWidth: targetWidth,
      targetHeight: targetHeight,
    );
    image = (await codec.getNextFrame()).image;
    // Raw RGBA by default; null only for a disposed image, and a throw here
    // falls back to the original bytes below.
    final rgba = (await image.toByteData())!;
    final pixels = rgba.buffer.asUint8List(
      rgba.offsetInBytes,
      rgba.lengthInBytes,
    );
    final (outWidth, outHeight) = (image.width, image.height);
    final downscaled = await Isolate.run(
      () => _encodeJpeg(pixels, outWidth, outHeight),
    );
    domainLogger.log(
      LogDomain.ai,
      'Downscaled image $imageId for upload: ${width}x$height, '
      '${bytes.length} bytes -> ${outWidth}x$outHeight JPEG, '
      '${downscaled.length} bytes',
      subDomain: 'ImageProcessingUtils',
    );
    return downscaled;
  } catch (e, stackTrace) {
    domainLogger.error(
      LogDomain.ai,
      e,
      stackTrace: stackTrace,
      subDomain: 'ImageProcessingUtils',
      message: 'Could not downscale image $imageId; uploading the original',
    );
    return bytes;
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor?.dispose();
    buffer?.dispose();
  }
}

/// RGBA [pixels] of [width] x [height] as a quality-85 JPEG.
Uint8List _encodeJpeg(Uint8List pixels, int width, int height) => img.encodeJpg(
  img.Image.fromBytes(
    width: width,
    height: height,
    bytes: pixels.buffer,
    bytesOffset: pixels.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  ),
  quality: 85,
);

/// [width] x [height] scaled to fit within [kMaxReferenceDimension] on its
/// longer side, keeping the aspect ratio; unchanged when it already fits.
(int, int) _fitWithinReferenceDimension(int width, int height) {
  if (width <= kMaxReferenceDimension && height <= kMaxReferenceDimension) {
    return (width, height);
  }
  return width > height
      ? (
          kMaxReferenceDimension,
          (height * kMaxReferenceDimension / width).round(),
        )
      : (
          (width * kMaxReferenceDimension / height).round(),
          kMaxReferenceDimension,
        );
}

/// Whether the image inference path actually forwards `tools` / `toolChoice`
/// for [provider] and [model].
///
/// `generateWithImages` fans out to provider-specific backends before it
/// reaches the generic OpenAI-compatible request builder, and not all of them
/// carry tool parameters:
///
/// - **Ollama** routes to a client with no tool parameters at all.
/// - **Mistral OCR models** route to the `/v1/ocr` endpoint, which is text
///   extraction rather than chat completion.
/// - Everything else — including Melious and Mistral chat models, each on its
///   own client — reaches a request that carries both.
///
/// Callers use this to decide whether to *ask* for a tool call. Asking without
/// it is worse than not asking: the prompt instructs the model to call a tool
/// it was never given, so instead of a clean prose answer the model is being
/// told to do something impossible.
bool imagePathSupportsTools({
  required AiConfigInferenceProvider? provider,
  required String model,
}) {
  final type = provider?.inferenceProviderType;
  if (type == InferenceProviderType.ollama) return false;
  if (type == InferenceProviderType.mistral &&
      MistralOcrRepository.isMistralOcrModel(model)) {
    return false;
  }
  return true;
}
