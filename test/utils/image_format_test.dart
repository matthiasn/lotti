import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/utils/image_format.dart';

/// The opening bytes of a real file of each format, followed by body bytes
/// that belong to no signature.
final _headers = <ImageFormat, List<int>>{
  ImageFormat.png: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2],
  ImageFormat.jpeg: [0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 1, 2],
  ImageFormat.gif: [0x47, 0x49, 0x46, 0x38, 0x39, 0x61, 1, 2],
  ImageFormat.webp: [
    0x52, 0x49, 0x46, 0x46, 0x24, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, 1, //
  ],
};

/// A RIFF container that is a WAVE file, not a WEBP image.
const _riffWave = [
  0x52, 0x49, 0x46, 0x46, 0x24, 0, 0, 0, 0x57, 0x41, 0x56, 0x45, 1, //
];

final Uint8List _svg = utf8.encode('<svg xmlns="http://www.w3.org/2000/svg"/>');

void main() {
  group('ImageFormat', () {
    test('names the extension and media type of each stored format', () {
      expect(
        {for (final f in ImageFormat.values) f: (f.extension, f.mimeType)},
        {
          ImageFormat.png: ('png', 'image/png'),
          ImageFormat.jpeg: ('jpg', 'image/jpeg'),
          ImageFormat.gif: ('gif', 'image/gif'),
          ImageFormat.webp: ('webp', 'image/webp'),
        },
      );
    });
  });

  group('ImageFormat.fromBytes', () {
    for (final MapEntry(key: format, value: bytes) in _headers.entries) {
      test('reads ${format.name} from its magic bytes', () {
        expect(ImageFormat.fromBytes(bytes), format);
      });
    }

    test('a RIFF container that is not WEBP is no image', () {
      expect(ImageFormat.fromBytes(_riffWave), isNull);
    });

    test('a RIFF signature too short to carry the WEBP tag is no image', () {
      expect(ImageFormat.fromBytes([0x52, 0x49, 0x46, 0x46, 0, 0]), isNull);
    });

    test('bytes of no image format are none, an SVG included', () {
      expect(ImageFormat.fromBytes(List<int>.generate(12, (i) => i)), isNull);
      expect(ImageFormat.fromBytes(_svg), isNull);
    });

    test('bytes shorter than a signature, or none at all, are no image', () {
      expect(ImageFormat.fromBytes(const [0x89, 0x50]), isNull);
      expect(ImageFormat.fromBytes(const []), isNull);
    });
  });

  group('ImageFormat.fromBase64', () {
    for (final MapEntry(key: format, value: bytes) in _headers.entries) {
      test('reads ${format.name} from a base64 payload', () {
        expect(ImageFormat.fromBase64(base64Encode(bytes)), format);
      });
    }

    test('reads the format from the prefix alone, whatever follows it', () {
      // The prefix is a valid PNG header; the tail is not even base64, which
      // proves the payload beyond the header is never decoded.
      final payload = '${base64Encode(_headers[ImageFormat.png]!)}!!!not-b64';
      expect(ImageFormat.fromBase64(payload), ImageFormat.png);
    });

    test('a payload whose prefix is not base64 has no format', () {
      expect(ImageFormat.fromBase64('not base64 at all!'), isNull);
    });

    test('a payload whose length cannot be valid base64 has no format', () {
      // Five characters: one past a whole quantum, which padding cannot fix.
      expect(ImageFormat.fromBase64('iVBOR'), isNull);
    });

    test('an empty payload has no format', () {
      expect(ImageFormat.fromBase64(''), isNull);
    });
  });

  group('imageDataUri', () {
    test('labels a PNG as image/png, not as a JPEG', () {
      final png = base64Encode(_headers[ImageFormat.png]!);
      expect(imageDataUri(png), 'data:image/png;base64,$png');
    });

    for (final MapEntry(key: format, value: bytes) in _headers.entries) {
      test('labels ${format.name} with ${format.mimeType}', () {
        final payload = base64Encode(bytes);
        expect(
          imageDataUri(payload),
          'data:${format.mimeType};base64,$payload',
        );
      });
    }

    test('keeps the image/jpeg label for bytes of no recognised format', () {
      expect(imageDataUri('abc123'), 'data:image/jpeg;base64,abc123');
      expect(
        imageDataUri(base64Encode(_svg)),
        'data:image/jpeg;base64,${base64Encode(_svg)}',
      );
    });
  });

  glados.Glados<List<int>>(
    glados.any.listWithLengthInRange(0, 64, glados.any.intInRange(0, 256)),
    glados.ExploreConfig(numRuns: 300),
  ).test(
    'reading only the base64 prefix agrees with decoding every byte',
    (bytes) {
      expect(
        ImageFormat.fromBase64(base64Encode(bytes)),
        ImageFormat.fromBytes(bytes),
      );
    },
    tags: 'glados',
  );

  glados.Glados2<ImageFormat, List<int>>(
    glados.any.choose(ImageFormat.values),
    glados.any.listWithLengthInRange(0, 64, glados.any.intInRange(0, 256)),
    glados.ExploreConfig(numRuns: 300),
  ).test(
    'any body behind a format header keeps that label and its payload',
    (format, body) {
      final payload = base64Encode([..._headers[format]!, ...body]);
      final uri = imageDataUri(payload);
      expect(uri, startsWith('data:${format.mimeType};base64,'));
      expect(uri.substring(uri.indexOf(',') + 1), payload);
    },
    tags: 'glados',
  );
}
