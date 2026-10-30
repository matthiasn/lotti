import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model_files/pinned_model_files.dart';
import 'package:lotti/features/ai/on_device_embedding/embedding_model.dart';
import 'package:lotti/features/ai/on_device_embedding/gemma_embedder.dart';

void main() {
  test('pins the files the embedder reads, at the measured revision', () {
    expect(
      embeddingGemma.files.map((file) => file.name),
      [
        GemmaEmbedder.modelFile,
        '${GemmaEmbedder.modelFile}_data',
        GemmaEmbedder.tokenizerFile,
      ],
    );
    expect(
      embeddingGemma.revision,
      '5090578d9565bb06545b4552f76e6bc2c93e4a66',
    );
    for (final file in embeddingGemma.files) {
      expect(
        file.sha256,
        matches(RegExp(r'^[0-9a-f]{64}$')),
        reason: file.name,
      );
    }
    expect(pinnedModelBytes(embeddingGemma), 217568394);
  });

  test('downloads each file from its pinned revision on Hugging Face', () {
    expect(
      embeddingGemma.uri(embeddingGemma.files.first).toString(),
      'https://huggingface.co/onnx-community/embeddinggemma-300m-ONNX/'
      'resolve/5090578d9565bb06545b4552f76e6bc2c93e4a66/onnx/model_q4.onnx',
    );
  });

  test('names the terms its weights are distributed under', () {
    expect(
      embeddingGemma.termsUri.toString(),
      'https://ai.google.dev/gemma/terms',
    );
  });
}
