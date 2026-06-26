import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/io/rig_codec.dart';
import 'package:lotti/features/character/model/affine2d.dart';
import 'package:lotti/features/character/model/bone.dart';
import 'package:lotti/features/character/model/rig_spec.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';
import 'package:lotti/features/character/samples/cat_in_suit.dart';

void main() {
  const codec = RigCodec();
  final cat = buildCatInSuitRig();

  group('RigCodec round-trip', () {
    test('encode → decode → encode is stable for the cat rig', () {
      final json1 = codec.toJson(cat);
      final decoded = codec.fromJson(json1);
      final json2 = codec.toJson(decoded);
      expect(jsonEncode(json2), jsonEncode(json1));
    });

    test('survives an actual JSON string trip', () {
      final text = jsonEncode(codec.toJson(cat));
      final decoded = codec.fromJson(jsonDecode(text) as Map<String, dynamic>);
      expect(decoded.bones.length, cat.bones.length);
      expect(decoded.ribbons.length, cat.ribbons.length);
      expect(decoded.meshes.length, cat.meshes.length);
      expect(decoded.face, isNotNull);
      expect(decoded.bone(CatBones.head)?.drawable, isNotNull);
    });
  });

  group('RigCodec validation', () {
    Map<String, dynamic> validBone() => {
      'id': 'a',
      'pivot': [0, 0],
      'z': 0,
    };

    test('rejects a missing/incompatible version', () {
      expect(
        () => codec.fromJson({
          'name': 'x',
          'bones': [validBone()],
        }),
        throwsA(isA<RigFormatException>()),
      );
      expect(
        () => codec.fromJson(
          {
            'version': 999,
            'name': 'x',
            'bones': [validBone()],
          },
        ),
        throwsA(isA<RigFormatException>()),
      );
    });

    test('rejects an empty bone list', () {
      expect(
        () => codec.fromJson({'version': 1, 'name': 'x', 'bones': <dynamic>[]}),
        throwsA(isA<RigFormatException>()),
      );
    });

    test('rejects a missing parent reference', () {
      expect(
        () => codec.fromJson({
          'version': 1,
          'name': 'x',
          'bones': [
            {
              'id': 'child',
              'parent': 'ghost',
              'pivot': [0, 0],
              'z': 0,
            },
          ],
        }),
        throwsA(
          isA<RigFormatException>().having(
            (e) => e.message,
            'message',
            contains('missing parent'),
          ),
        ),
      );
    });

    test('rejects duplicate bone ids', () {
      expect(
        () => codec.fromJson({
          'version': 1,
          'name': 'x',
          'bones': [validBone(), validBone()],
        }),
        throwsA(isA<RigFormatException>()),
      );
    });

    test('rejects a parent cycle', () {
      expect(
        () => codec.fromJson({
          'version': 1,
          'name': 'x',
          'bones': [
            {
              'id': 'a',
              'parent': 'b',
              'pivot': [0, 0],
              'z': 0,
            },
            {
              'id': 'b',
              'parent': 'a',
              'pivot': [0, 0],
              'z': 0,
            },
          ],
        }),
        throwsA(
          isA<RigFormatException>().having(
            (e) => e.message,
            'message',
            contains('cycle'),
          ),
        ),
      );
    });

    test(
      'rejects a non-string parent with a format error (not a TypeError)',
      () {
        expect(
          () => codec.fromJson({
            'version': 1,
            'name': 'x',
            'bones': [
              {
                'id': 'a',
                'parent': 42,
                'pivot': [0, 0],
                'z': 0,
              },
            ],
          }),
          throwsA(isA<RigFormatException>()),
        );
      },
    );

    test('rejects a face anchor that names no bone', () {
      expect(
        () => codec.fromJson({
          'version': 1,
          'name': 'x',
          'bones': [validBone()],
          'face': {
            'anchor': 'ghost',
            'eye': {
              'offset': [0, 0],
              'radius': [1, 1],
              'pupilRadius': 1,
              'color': '#FFFFFFFF',
              'pupilColor': '#FF000000',
            },
            'brow': {'offsetY': 0, 'width': 1, 'color': '#FF000000'},
            'mouth': {
              'offsetY': 0,
              'size': [1, 1],
              'color': '#FF000000',
            },
            'muzzle': {
              'size': [1, 1],
              'color': '#FF000000',
            },
            'nose': {
              'size': [1, 1],
              'color': '#FF000000',
            },
            'whisker': {'color': '#FF000000', 'length': 1},
          },
        }),
        throwsA(
          isA<RigFormatException>().having(
            (e) => e.message,
            'message',
            contains('face.anchor'),
          ),
        ),
      );
    });

    test('encodes a high-alpha colour without a negative hex string', () {
      // On Dart Web `& 0xFFFFFFFF` would make alpha >= 0x80 negative; the codec
      // uses toUnsigned(32), so it must always emit an 8-digit positive hex.
      final json = codec.toJson(
        RigSpec(
          name: 'x',
          bones: const [
            Bone(
              id: 'a',
              parent: null,
              pivotX: 0,
              pivotY: 0,
              z: 0,
              drawable: BoneDrawable(
                kind: BoneShapeKind.ellipse,
                width: 4,
                height: 4,
                color: 0xFF2E3A59,
              ),
            ),
          ],
        ),
      );
      final bones = json['bones'] as List<dynamic>;
      final drawable =
          (bones.first as Map<String, dynamic>)['drawable']
              as Map<String, dynamic>;
      expect(drawable['color'], '#FF2E3A59');
    });

    test('rejects an unknown drawable kind', () {
      expect(
        () => codec.fromJson({
          'version': 1,
          'name': 'x',
          'bones': [
            {
              'id': 'a',
              'pivot': [0, 0],
              'z': 0,
              'drawable': {
                'kind': 'hexagon',
                'size': [1, 1],
                'color': '#FFFFFFFF',
              },
            },
          ],
        }),
        throwsA(isA<RigFormatException>()),
      );
    });

    test('rejects a malformed colour', () {
      expect(
        () => codec.fromJson({
          'version': 1,
          'name': 'x',
          'bones': [
            {
              'id': 'a',
              'pivot': [0, 0],
              'z': 0,
              'drawable': {
                'kind': 'ellipse',
                'size': [1, 1],
                'color': 'not-a-colour',
              },
            },
          ],
        }),
        throwsA(isA<RigFormatException>()),
      );
    });

    test('rejects a ribbon that references a missing bone', () {
      expect(
        () => codec.fromJson({
          'version': 1,
          'name': 'x',
          'bones': [validBone()],
          'ribbons': [
            {
              'id': 'bad',
              'joints': ['a', 'ghost'],
              'halfWidths': [4, 3],
              'z': 0,
              'color': '#FFFFFFFF',
            },
          ],
        }),
        throwsA(
          isA<RigFormatException>().having(
            (e) => e.message,
            'message',
            contains('missing bone'),
          ),
        ),
      );
    });

    test('rejects a ribbon with mismatched joints and widths', () {
      expect(
        () => codec.fromJson({
          'version': 1,
          'name': 'x',
          'bones': [validBone()],
          'ribbons': [
            {
              'id': 'bad',
              'joints': ['a', 'a'],
              'halfWidths': [4],
              'z': 0,
              'color': '#FFFFFFFF',
            },
          ],
        }),
        throwsA(
          isA<RigFormatException>().having(
            (e) => e.message,
            'message',
            contains('length mismatch'),
          ),
        ),
      );
    });

    test('rejects a mesh that references a missing bone', () {
      expect(
        () => codec.fromJson({
          'version': 1,
          'name': 'x',
          'bones': [validBone()],
          'meshes': [
            {
              'id': 'bad',
              'vertices': [
                [
                  {
                    'bone': 'a',
                    'point': [0, 0],
                    'weight': 1,
                  },
                ],
                [
                  {
                    'bone': 'ghost',
                    'point': [1, 0],
                    'weight': 1,
                  },
                ],
                [
                  {
                    'bone': 'a',
                    'point': [0, 1],
                    'weight': 1,
                  },
                ],
              ],
              'boundary': [0, 1, 2],
              'z': 0,
              'color': '#FFFFFFFF',
            },
          ],
        }),
        throwsA(
          isA<RigFormatException>().having(
            (e) => e.message,
            'message',
            contains('missing bone'),
          ),
        ),
      );
    });

    test('rejects mesh vertex weights that do not sum to one', () {
      expect(
        () => codec.fromJson({
          'version': 1,
          'name': 'x',
          'bones': [validBone()],
          'meshes': [
            {
              'id': 'bad',
              'vertices': [
                [
                  {
                    'bone': 'a',
                    'point': [0, 0],
                    'weight': 0.4,
                  },
                ],
                [
                  {
                    'bone': 'a',
                    'point': [1, 0],
                    'weight': 1,
                  },
                ],
                [
                  {
                    'bone': 'a',
                    'point': [0, 1],
                    'weight': 1,
                  },
                ],
              ],
              'boundary': [0, 1, 2],
              'z': 0,
              'color': '#FFFFFFFF',
            },
          ],
        }),
        throwsA(
          isA<RigFormatException>().having(
            (e) => e.message,
            'message',
            contains('sum to 1'),
          ),
        ),
      );
    });

    test('accepts 6-digit colours as opaque', () {
      final rig = codec.fromJson({
        'version': 1,
        'name': 'x',
        'bones': [
          {
            'id': 'a',
            'pivot': [0, 0],
            'z': 0,
            'drawable': {
              'kind': 'ellipse',
              'size': [4, 4],
              'color': '#2E3A59',
            },
          },
        ],
      });
      expect(rig.bone('a')?.drawable?.color, 0xFF2E3A59);
    });
  });

  testWidgets('a JSON-loaded rig renders pixel-identical to the code rig', (
    tester,
  ) async {
    Future<Uint8List> render(CharacterScene scene) async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      CharacterRenderer().paint(
        canvas,
        scene.rig,
        scene
            .frameAt(
              clip: CatClips.walk,
              timeSeconds: 0.4,
              base: Affine2D.translation(
                120,
                240,
              ).multiply(Affine2D.scale(0.7, 0.7)),
            )
            .world,
        scene.frameAt(clip: CatClips.walk, timeSeconds: 0.4).face,
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(240, 280);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes!.buffer.asUint8List();
    }

    await tester.runAsync(() async {
      final fromCode = CharacterScene(cat);
      final fromJson = CharacterScene(
        codec.fromJson(
          jsonDecode(jsonEncode(codec.toJson(cat))) as Map<String, dynamic>,
        ),
      );
      expect(await render(fromJson), equals(await render(fromCode)));
    });
  });

  testWidgets('emits a sample rig JSON for inspection', (tester) async {
    final dir = Directory(
      Platform.environment['CHARACTER_STRIP_DIR'] != null
          ? '${Platform.environment['CHARACTER_STRIP_DIR']}/../character_rigs'
          : 'build/character_rigs',
    )..createSync(recursive: true);
    final text = const JsonEncoder.withIndent('  ').convert(codec.toJson(cat));
    File('${dir.path}/cat_in_suit.json').writeAsStringSync(text);
    expect(text, contains('"name": "cat_in_suit"'));
  });
}
