import 'package:lotti/features/character/model/bone.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/model/rig_spec.dart';

/// Thrown when a rig JSON document is malformed. The message names the offending
/// field so the (eventual) AI rigging step and the human-correction UI can give
/// precise feedback.
class RigFormatException implements Exception {
  RigFormatException(this.message);

  final String message;

  @override
  String toString() => 'RigFormatException: $message';
}

/// The schema version this codec reads and writes.
const int kRigFormatVersion = 1;

/// Serializes/deserializes a [RigSpec] to/from a plain JSON map.
///
/// This is the declarative rig format from the implementation plan: the on-disk
/// contract between the (offline, eventually AI-assisted) rigging step and the
/// on-device player. It is deliberately decoupled from the Dart types so the
/// model can evolve without breaking stored rigs.
///
/// The `drawable.kind` field is a discriminator. Phase 1 ships the primitive
/// shapes (`capsule`/`ellipse`/`roundedRect`/`triangle`); `path` and `raster`
/// (real SVG/atlas art) are reserved for Phase 2 and round-trip-rejected for now
/// with a clear error rather than silently dropped.
class RigCodec {
  const RigCodec();

  // ---- encode -------------------------------------------------------------

  Map<String, dynamic> toJson(RigSpec rig) => {
    'version': kRigFormatVersion,
    'name': rig.name,
    'bones': rig.bones.map(_boneToJson).toList(),
    if (rig.face != null) 'face': _faceToJson(rig.face!),
  };

  Map<String, dynamic> _boneToJson(Bone b) => {
    'id': b.id,
    if (b.parent != null) 'parent': b.parent,
    'pivot': [b.pivotX, b.pivotY],
    'z': b.z,
    if (b.restRotation != 0) 'restRotation': b.restRotation,
    if (b.restScaleX != 1 || b.restScaleY != 1)
      'restScale': [b.restScaleX, b.restScaleY],
    if (b.drawable != null) 'drawable': _drawableToJson(b.drawable!),
  };

  Map<String, dynamic> _drawableToJson(BoneDrawable d) => {
    'kind': d.kind.name,
    'size': [d.width, d.height],
    if (d.dx != 0 || d.dy != 0) 'offset': [d.dx, d.dy],
    if (d.cornerRadius != 0) 'cornerRadius': d.cornerRadius,
    'color': _colorToHex(d.color),
    if (d.outlineColor != null) 'outlineColor': _colorToHex(d.outlineColor!),
    if (d.outlineWidth != 0) 'outlineWidth': d.outlineWidth,
  };

  Map<String, dynamic> _faceToJson(FaceRig f) => {
    'anchor': f.anchorBoneId,
    'eye': {
      'offset': [f.eyeOffsetX, f.eyeOffsetY],
      'radius': [f.eyeRadiusX, f.eyeRadiusY],
      'pupilRadius': f.pupilRadius,
      'color': _colorToHex(f.eyeColor),
      'pupilColor': _colorToHex(f.pupilColor),
    },
    'brow': {
      'offsetY': f.browOffsetY,
      'width': f.browWidth,
      'color': _colorToHex(f.browColor),
    },
    'mouth': {
      'offsetY': f.mouthOffsetY,
      'size': [f.mouthWidth, f.mouthHeight],
      'color': _colorToHex(f.mouthColor),
    },
    'muzzle': {
      'size': [f.muzzleWidth, f.muzzleHeight],
      'color': _colorToHex(f.muzzleColor),
    },
    'nose': {
      'size': [f.noseWidth, f.noseHeight],
      'color': _colorToHex(f.noseColor),
    },
    'whisker': {
      'color': _colorToHex(f.whiskerColor),
      'length': f.whiskerLength,
    },
  };

  // ---- decode -------------------------------------------------------------

  RigSpec fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    if (version is! int) {
      throw RigFormatException('missing or non-integer "version"');
    }
    if (version != kRigFormatVersion) {
      throw RigFormatException(
        'unsupported rig version $version (expected $kRigFormatVersion)',
      );
    }
    final name = _string(json, 'name');
    final bonesJson = json['bones'];
    if (bonesJson is! List || bonesJson.isEmpty) {
      throw RigFormatException('"bones" must be a non-empty list');
    }
    final bones = bonesJson.map(_boneFromJson).toList();
    _validateHierarchy(bones);
    final faceJson = json['face'];
    final face = faceJson == null
        ? null
        : _faceFromJson(_map(faceJson, 'face'));
    if (face != null && !bones.any((b) => b.id == face.anchorBoneId)) {
      throw RigFormatException(
        'face.anchor "${face.anchorBoneId}" references a missing bone',
      );
    }
    return RigSpec(name: name, bones: bones, face: face);
  }

  /// Rejects duplicate ids, missing parents, and parent cycles with precise
  /// messages — before the [RigSpec] constructor (which assumes a valid tree).
  void _validateHierarchy(List<Bone> bones) {
    final byId = <String, Bone>{};
    for (final b in bones) {
      if (byId.containsKey(b.id)) {
        throw RigFormatException('duplicate bone id "${b.id}"');
      }
      byId[b.id] = b;
    }
    for (final b in bones) {
      final seen = <String>{};
      var cur = b;
      while (cur.parent != null) {
        if (!seen.add(cur.id)) {
          throw RigFormatException('parent cycle involving bone "${b.id}"');
        }
        final parent = byId[cur.parent];
        if (parent == null) {
          throw RigFormatException(
            'bone "${cur.id}" references missing parent "${cur.parent}"',
          );
        }
        cur = parent;
      }
    }
  }

  Bone _boneFromJson(dynamic raw) {
    final m = _map(raw, 'bone');
    final pivot = _pair(m, 'pivot');
    final scale = m.containsKey('restScale') ? _pair(m, 'restScale') : null;
    return Bone(
      id: _string(m, 'id'),
      parent: _optionalString(m, 'parent'),
      pivotX: pivot.$1,
      pivotY: pivot.$2,
      z: _int(m, 'z'),
      restRotation: _doubleOr(m, 'restRotation', 0),
      restScaleX: scale?.$1 ?? 1,
      restScaleY: scale?.$2 ?? 1,
      drawable: m.containsKey('drawable')
          ? _drawableFromJson(_map(m['drawable'], 'drawable'))
          : null,
    );
  }

  BoneDrawable _drawableFromJson(Map<String, dynamic> m) {
    final kindName = _string(m, 'kind');
    BoneShapeKind? kind;
    for (final k in BoneShapeKind.values) {
      if (k.name == kindName) {
        kind = k;
        break;
      }
    }
    if (kind == null) {
      throw RigFormatException(
        'unsupported drawable kind "$kindName" '
        '(Phase 1 supports ${BoneShapeKind.values.map((k) => k.name).join(", ")})',
      );
    }
    final size = _pair(m, 'size');
    final offset = m.containsKey('offset') ? _pair(m, 'offset') : null;
    return BoneDrawable(
      kind: kind,
      width: size.$1,
      height: size.$2,
      dx: offset?.$1 ?? 0,
      dy: offset?.$2 ?? 0,
      cornerRadius: _doubleOr(m, 'cornerRadius', 0),
      color: _colorFromHex(_string(m, 'color')),
      outlineColor: m.containsKey('outlineColor')
          ? _colorFromHex(_string(m, 'outlineColor'))
          : null,
      outlineWidth: _doubleOr(m, 'outlineWidth', 0),
    );
  }

  FaceRig _faceFromJson(Map<String, dynamic> m) {
    final eye = _map(m['eye'], 'face.eye');
    final brow = _map(m['brow'], 'face.brow');
    final mouth = _map(m['mouth'], 'face.mouth');
    final muzzle = _map(m['muzzle'], 'face.muzzle');
    final nose = _map(m['nose'], 'face.nose');
    final whisker = _map(m['whisker'], 'face.whisker');
    final eyeOffset = _pair(eye, 'offset');
    final eyeRadius = _pair(eye, 'radius');
    final mouthSize = _pair(mouth, 'size');
    final muzzleSize = _pair(muzzle, 'size');
    final noseSize = _pair(nose, 'size');
    return FaceRig(
      anchorBoneId: _string(m, 'anchor'),
      eyeOffsetX: eyeOffset.$1,
      eyeOffsetY: eyeOffset.$2,
      eyeRadiusX: eyeRadius.$1,
      eyeRadiusY: eyeRadius.$2,
      pupilRadius: _double(eye, 'pupilRadius'),
      browOffsetY: _double(brow, 'offsetY'),
      browWidth: _double(brow, 'width'),
      mouthOffsetY: _double(mouth, 'offsetY'),
      mouthWidth: mouthSize.$1,
      mouthHeight: mouthSize.$2,
      eyeColor: _colorFromHex(_string(eye, 'color')),
      pupilColor: _colorFromHex(_string(eye, 'pupilColor')),
      browColor: _colorFromHex(_string(brow, 'color')),
      mouthColor: _colorFromHex(_string(mouth, 'color')),
      muzzleWidth: muzzleSize.$1,
      muzzleHeight: muzzleSize.$2,
      muzzleColor: _colorFromHex(_string(muzzle, 'color')),
      noseWidth: noseSize.$1,
      noseHeight: noseSize.$2,
      noseColor: _colorFromHex(_string(nose, 'color')),
      whiskerColor: _colorFromHex(_string(whisker, 'color')),
      whiskerLength: _double(whisker, 'length'),
    );
  }

  // ---- helpers ------------------------------------------------------------

  Map<String, dynamic> _map(dynamic v, String field) {
    if (v is! Map<String, dynamic>) {
      throw RigFormatException('"$field" must be an object');
    }
    return v;
  }

  String _string(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is! String || v.isEmpty) {
      throw RigFormatException('"$key" must be a non-empty string');
    }
    return v;
  }

  /// Like [_string] but tolerates an absent key (returns null). A present value
  /// is still validated, so a malformed `parent` (e.g. a number) fails with a
  /// [RigFormatException] rather than an opaque `TypeError`.
  String? _optionalString(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v == null) return null;
    if (v is! String || v.isEmpty) {
      throw RigFormatException(
        '"$key" must be a non-empty string when present',
      );
    }
    return v;
  }

  int _int(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is! int) throw RigFormatException('"$key" must be an integer');
    return v;
  }

  double _double(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is! num) throw RigFormatException('"$key" must be a number');
    return v.toDouble();
  }

  double _doubleOr(Map<String, dynamic> m, String key, double fallback) {
    if (!m.containsKey(key)) return fallback;
    return _double(m, key);
  }

  (double, double) _pair(Map<String, dynamic> m, String key) {
    final v = m[key];
    if (v is! List || v.length != 2 || v[0] is! num || v[1] is! num) {
      throw RigFormatException('"$key" must be a [number, number] pair');
    }
    return ((v[0] as num).toDouble(), (v[1] as num).toDouble());
  }

  String _colorToHex(int argb) =>
      // `toUnsigned(32)` (not `& 0xFFFFFFFF`) so alpha >= 0x80 round-trips on
      // Dart Web, where bitwise ops are 32-bit signed and would yield a negative
      // value (and a "-rrggbb" string) for those colours.
      '#${argb.toUnsigned(32).toRadixString(16).padLeft(8, '0').toUpperCase()}';

  int _colorFromHex(String hex) {
    var s = hex.trim();
    if (s.startsWith('#')) s = s.substring(1);
    if (s.length == 6) s = 'FF$s'; // assume opaque
    if (s.length != 8) {
      throw RigFormatException('color "$hex" must be #RRGGBB or #AARRGGBB');
    }
    final value = int.tryParse(s, radix: 16);
    if (value == null) throw RigFormatException('color "$hex" is not hex');
    return value;
  }
}
