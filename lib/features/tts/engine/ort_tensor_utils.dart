// Tensor helpers for the Supertonic ONNX pipeline.
//
// Ported from Supertone's open-source Supertonic Flutter example (MIT). The
// flatten/cast helpers are pure and unit-tested; the `*Tensor` builders are
// thin wrappers over `OrtValue.fromList` and run only with the native runtime.

import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

/// Recursively flattens an arbitrarily-nested numeric structure into a flat
/// `List<T>`. For `T == double`, numeric leaves are coerced with `toDouble()`.
List<T> flattenList<T>(dynamic value) {
  if (value is List) {
    return value.expand<T>(flattenList<T>).toList();
  }
  if (T == double && value is num) {
    return <T>[value.toDouble() as T];
  }
  return <T>[value as T];
}

/// Coerces an ONNX output (possibly nested, possibly scalar `num`) into a flat
/// `List<T>`. Mirrors the upstream `_safeCast`.
List<T> safeCast<T>(dynamic raw) {
  if (raw is List<T>) return raw;
  if (raw is List) {
    if (raw.isNotEmpty && raw.first is List) {
      return flattenList<T>(raw);
    }
    if (T == double) {
      return raw
          .map<T>(
            (e) => (e is num ? e.toDouble() : double.parse(e.toString())) as T,
          )
          .toList();
    }
    return raw.cast<T>();
  }
  throw ArgumentError('Cannot convert $raw to List<$T>');
}

// The *Tensor builders are thin wrappers over the static OrtValue.fromList,
// which performs a native (method-channel) allocation and so cannot run in a
// unit test. The pure flatten/cast helpers above carry the testable logic;
// callers inject these builders to mock them (see SupertonicTtsSession).
// coverage:ignore-start
/// Float32 tensor from an arbitrarily-nested double array.
Future<OrtValue> floatTensor(dynamic array, List<int> dims) =>
    OrtValue.fromList(Float32List.fromList(flattenList<double>(array)), dims);

/// Float32 tensor from a flat scalar list (e.g. per-batch step counters).
Future<OrtValue> scalarTensor(List<double> array, List<int> dims) =>
    OrtValue.fromList(Float32List.fromList(array), dims);

/// Int64 tensor from a 2-D int array (token ids).
Future<OrtValue> intTensor(List<List<int>> array, List<int> dims) =>
    OrtValue.fromList(
      Int64List.fromList(array.expand((row) => row).toList()),
      dims,
    );
// coverage:ignore-end
