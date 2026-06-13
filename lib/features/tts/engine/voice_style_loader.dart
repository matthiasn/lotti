// Voice-style loading for the Supertonic ONNX pipeline.
//
// Ported from Supertone's open-source Supertonic Flutter example (MIT). A voice
// style is two tensors (`style_ttl`, `style_dp`) baked into a JSON file shipped
// per voice. Paths starting with `assets/` load from the bundle; others from
// the filesystem.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// Loaded voice style: the two conditioning tensors + their shapes.
class VoiceStyle {
  VoiceStyle(this.ttl, this.dp, this.ttlShape, this.dpShape);

  final OrtValue ttl;
  final OrtValue dp;
  final List<int> ttlShape;
  final List<int> dpShape;
}

Future<String> _readJson(String path) => path.startsWith('assets/')
    ? rootBundle.loadString(path)
    : File(path).readAsString();

/// Loads one or more voice-style JSON files into a batched [VoiceStyle].
Future<VoiceStyle> loadVoiceStyle(List<String> paths) async {
  final bsz = paths.length;

  final firstJson =
      jsonDecode(await _readJson(paths[0])) as Map<String, dynamic>;
  final ttlDims = List<int>.from(
    (firstJson['style_ttl'] as Map)['dims'] as List,
  );
  final dpDims = List<int>.from((firstJson['style_dp'] as Map)['dims'] as List);

  final ttlStride = ttlDims[1] * ttlDims[2];
  final dpStride = dpDims[1] * dpDims[2];
  final ttlFlat = Float32List(bsz * ttlStride);
  final dpFlat = Float32List(bsz * dpStride);

  for (var i = 0; i < bsz; i++) {
    final json = jsonDecode(await _readJson(paths[i])) as Map<String, dynamic>;
    ttlFlat.setRange(
      i * ttlStride,
      (i + 1) * ttlStride,
      _flattenToDouble((json['style_ttl'] as Map)['data']),
    );
    dpFlat.setRange(
      i * dpStride,
      (i + 1) * dpStride,
      _flattenToDouble((json['style_dp'] as Map)['data']),
    );
  }

  final ttlShape = [bsz, ttlDims[1], ttlDims[2]];
  final dpShape = [bsz, dpDims[1], dpDims[2]];
  return VoiceStyle(
    await OrtValue.fromList(ttlFlat, ttlShape),
    await OrtValue.fromList(dpFlat, dpShape),
    ttlShape,
    dpShape,
  );
}

List<double> _flattenToDouble(dynamic list) {
  if (list is List) return list.expand(_flattenToDouble).toList();
  if (list is num) return [list.toDouble()];
  return [double.parse(list.toString())];
}
