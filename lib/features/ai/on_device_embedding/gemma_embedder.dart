import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:lotti/features/ai/on_device_embedding/gemma_tokenizer.dart';

/// Builds an int64 tensor of [shape] from [data].
typedef Int64TensorBuilder =
    Future<OrtValue> Function(Int64List data, List<int> shape);

/// EmbeddingGemma-300m (ADR 0144) on the bundled ONNX Runtime: text in, a
/// unit-length 768-dimensional vector out.
///
/// Queries and documents are embedded with the prompts the model was trained
/// on, so a query is embedded with [embedQuery] and the text it should find
/// with [embedDocument]. Input past [maxTokens] is cut from the end, as the
/// evaluation measured it.
class GemmaEmbedder {
  GemmaEmbedder(
    this._tokenizer,
    this._session, {
    Int64TensorBuilder int64Tensor = _int64Tensor,
  }) : _buildInt64 = int64Tensor;

  /// The width of every vector.
  static const int dimensions = 768;

  /// The most tokens one embedding reads, `<bos>` and `<eos>` included.
  static const int maxTokens = 512;

  /// The model, relative to its directory: the q4 weights ADR 0144 chose,
  /// whose `.onnx_data` file sits beside it.
  static const String modelFile = 'onnx/model_q4.onnx';

  /// The tokenizer, relative to the model's directory.
  static const String tokenizerFile = 'tokenizer.json';

  static const String _queryPrompt = 'task: search result | query: ';
  static const String _documentPrompt = 'title: none | text: ';

  final GemmaTokenizer _tokenizer;
  final OrtSession _session;
  final Int64TensorBuilder _buildInt64;

  /// Loads the model and its tokenizer from [modelDirectory].
  ///
  /// The tokenizer's 20 MB JSON is read and decoded in a background isolate.
  /// The session runs on half the cores, at most four, so background
  /// indexing leaves the device room.
  static Future<GemmaEmbedder> load(
    String modelDirectory, {
    OnnxRuntime? runtime,
    Int64TensorBuilder int64Tensor = _int64Tensor,
  }) async {
    final tokenizerPath = '$modelDirectory/$tokenizerFile';
    final tokenizer = await Isolate.run(
      () => GemmaTokenizer.fromTokenizerJson(
        jsonDecode(File(tokenizerPath).readAsStringSync())
            as Map<String, dynamic>,
      ),
    );
    final session = await (runtime ?? OnnxRuntime()).createSession(
      '$modelDirectory/$modelFile',
      options: OrtSessionOptions(
        intraOpNumThreads: (Platform.numberOfProcessors ~/ 2).clamp(1, 4),
        interOpNumThreads: 1,
      ),
    );
    return GemmaEmbedder(tokenizer, session, int64Tensor: int64Tensor);
  }

  /// The vector a search for [query] is compared with.
  Future<Float32List> embedQuery(String query) => _embed(_queryPrompt + query);

  /// The vector that represents [text] in the index.
  Future<Float32List> embedDocument(String text) =>
      _embed(_documentPrompt + text);

  /// Releases the native session.
  Future<void> dispose() => _session.close();

  Future<Float32List> _embed(String input) async {
    final ids = _tokenizer.encode(input, maxLength: maxTokens);
    final shape = [1, ids.length];
    final tensors = <OrtValue>[];
    try {
      tensors
        ..add(await _buildInt64(Int64List.fromList(ids), shape))
        ..add(
          await _buildInt64(
            Int64List(ids.length)..fillRange(0, ids.length, 1),
            shape,
          ),
        );
      final outputs = await _session.run({
        'input_ids': tensors[0],
        'attention_mask': tensors[1],
      });
      tensors.addAll(outputs.values);
      final pooled = outputs['sentence_embedding'];
      if (pooled == null) {
        throw StateError('the model gave no sentence_embedding');
      }
      final values = await pooled.asFlattenedList();
      if (values.length != dimensions) {
        throw StateError(
          'expected $dimensions dimensions, got ${values.length}',
        );
      }
      return _unitLength(values);
    } finally {
      for (final tensor in tensors) {
        await tensor.dispose();
      }
    }
  }

  static Float32List _unitLength(List<dynamic> values) {
    final vector = Float32List(values.length);
    var squares = 0.0;
    for (var i = 0; i < values.length; i++) {
      // Read back as stored, so a value past float32's range counts as the
      // infinity it became.
      vector[i] = (values[i] as num).toDouble();
      final value = vector[i];
      if (!value.isFinite) {
        throw StateError('the model gave a non-finite value');
      }
      squares += value * value;
    }
    // Finite float32 values cannot overflow a double's sum of squares, so the
    // length is finite; only zero is left to refuse.
    final norm = sqrt(squares);
    if (norm == 0) throw StateError('the model gave a zero vector');
    for (var i = 0; i < vector.length; i++) {
      vector[i] /= norm;
    }
    return vector;
  }

  // A native (method-channel) allocation, so it cannot run in a unit test;
  // tests inject a builder instead.
  // coverage:ignore-start
  static Future<OrtValue> _int64Tensor(Int64List data, List<int> shape) =>
      OrtValue.fromList(data, shape);
  // coverage:ignore-end
}
