import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/engine/voice_style_loader.dart';

import '../../../mocks/mocks.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('voice_style_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  File writeStyle(String name, Map<String, dynamic> json) =>
      File('${dir.path}/$name')..writeAsStringSync(jsonEncode(json));

  test(
    'flattens voice-style JSON depth-first and prepends the batch dim',
    () async {
      final file = writeStyle('F1.json', {
        'style_ttl': {
          'dims': [1, 2, 2],
          'data': [
            [
              [1.0, 2.0],
              [3.0, 4.0],
            ],
          ],
        },
        'style_dp': {
          'dims': [1, 1, 2],
          'data': [
            [
              [5.0, 6.0],
            ],
          ],
        },
      });

      final built = <(Float32List, List<int>)>[];
      final style = await loadVoiceStyle(
        [file.path],
        tensorBuilder: (data, shape) async {
          built.add((data as Float32List, shape));
          return MockOrtValue();
        },
      );

      expect(built, hasLength(2));
      expect(built[0].$1, [1.0, 2.0, 3.0, 4.0]); // ttl flattened
      expect(built[0].$2, [1, 2, 2]); // [bsz, dim1, dim2]
      expect(built[1].$1, [5.0, 6.0]); // dp flattened
      expect(built[1].$2, [1, 1, 2]);
      expect(style.ttlShape, [1, 2, 2]);
      expect(style.dpShape, [1, 1, 2]);
    },
  );

  test('stacks multiple files along the batch axis', () async {
    Map<String, dynamic> styleJson(double v) => {
      'style_ttl': {
        'dims': [1, 1, 1],
        'data': [
          [
            [v],
          ],
        ],
      },
      'style_dp': {
        'dims': [1, 1, 1],
        'data': [
          [
            [v + 1],
          ],
        ],
      },
    };
    final f1 = writeStyle('F1.json', styleJson(1));
    final f2 = writeStyle('F2.json', styleJson(10));

    final built = <(Float32List, List<int>)>[];
    await loadVoiceStyle(
      [f1.path, f2.path],
      tensorBuilder: (data, shape) async {
        built.add((data as Float32List, shape));
        return MockOrtValue();
      },
    );

    expect(built[0].$1, [1.0, 10.0]); // ttl batched across files
    expect(built[0].$2, [2, 1, 1]); // bsz = 2
    expect(built[1].$1, [2.0, 11.0]); // dp = v + 1
  });

  test('coerces string-encoded data values to doubles', () async {
    final file = writeStyle('F1.json', {
      'style_ttl': {
        'dims': [1, 1, 1],
        'data': [
          [
            ['1.5'],
          ],
        ],
      },
      'style_dp': {
        'dims': [1, 1, 1],
        'data': [
          [
            [2],
          ],
        ],
      },
    });

    final built = <Float32List>[];
    await loadVoiceStyle(
      [file.path],
      tensorBuilder: (data, shape) async {
        built.add(data as Float32List);
        return MockOrtValue();
      },
    );

    expect(built[0], [1.5]); // parsed from the string "1.5"
  });
}
