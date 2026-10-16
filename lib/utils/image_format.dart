import 'dart:convert';

/// The image formats the app stores and decodes, each recognised by the magic
/// bytes that open the file rather than by the name it arrived under.
///
/// HEIC/HEIF is absent on purpose: the importer converts it to JPEG before
/// storing, so no stored image is one.
enum ImageFormat {
  png('png', 'image/png', [0x89, 0x50, 0x4E, 0x47]),
  jpeg('jpg', 'image/jpeg', [0xFF, 0xD8, 0xFF]),
  gif('gif', 'image/gif', [0x47, 0x49, 0x46, 0x38]),
  // RIFF....WEBP: the four bytes after the size are checked separately.
  webp('webp', 'image/webp', [0x52, 0x49, 0x46, 0x46]);

  const ImageFormat(this.extension, this.mimeType, this._signature);

  /// The file extension the app stores this format under.
  final String extension;

  /// The IANA media type, as a `data:` URI or an upload names it.
  final String mimeType;

  final List<int> _signature;

  /// The longest prefix [fromBytes] reads: WebP's `RIFF` + size + `WEBP`.
  static const _headerLength = 12;

  static const _webpTag = [0x57, 0x45, 0x42, 0x50];

  /// The format [bytes] are, by their opening magic bytes; null for anything
  /// else — an SVG, a truncated file, or bytes that are no image at all.
  static ImageFormat? fromBytes(List<int> bytes) {
    for (final format in values) {
      if (!_startsWith(bytes, format._signature)) continue;
      if (format == webp && !_startsWith(bytes, _webpTag, offset: 8)) {
        continue;
      }
      return format;
    }
    return null;
  }

  /// The format of the base64-encoded image [base64Image], read from only the
  /// characters that encode its first 12 bytes, so a
  /// multi-megabyte payload is never decoded just to be labelled. Null when
  /// that prefix is no recognised format or is not valid base64.
  static ImageFormat? fromBase64(String base64Image) {
    // Every 4 base64 characters encode 3 bytes.
    const prefixLength = _headerLength ~/ 3 * 4;
    final prefix = base64Image.length > prefixLength
        ? base64Image.substring(0, prefixLength)
        : base64Image;
    try {
      return fromBytes(base64Decode(base64.normalize(prefix)));
    } on FormatException {
      return null;
    }
  }

  static bool _startsWith(
    List<int> bytes,
    List<int> signature, {
    int offset = 0,
  }) {
    if (bytes.length < offset + signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[offset + i] != signature[i]) return false;
    }
    return true;
  }
}

/// A `data:` URI for the base64-encoded image [base64Image], labelled with the
/// format its bytes actually are.
///
/// Images reach the vision paths as the stored file's raw bytes, so a pasted
/// screenshot is a PNG. Some providers (Kimi K3 on Melious) reject a PNG
/// labelled `image/jpeg` as a malformed request, where others tolerate it.
/// Bytes of no recognised format keep the long-standing `image/jpeg` label.
String imageDataUri(String base64Image) {
  final mimeType =
      (ImageFormat.fromBase64(base64Image) ?? ImageFormat.jpeg).mimeType;
  return 'data:$mimeType;base64,$base64Image';
}
