import 'package:lotti/features/ai/model_files/pinned_model_files.dart';
import 'package:lotti/features/ai/on_device_embedding/gemma_embedder.dart';

/// The on-device embedding model: where its files come from, pinned to the
/// revision ADR 0144 measured, and the terms it is offered under.
class EmbeddingModel implements PinnedModel {
  const EmbeddingModel({
    required this.id,
    required this.name,
    required this.repository,
    required this.revision,
    required this.files,
    required this.termsUri,
  });

  /// Stored with every vector, so vectors of another model are recognised.
  @override
  final String id;

  /// The name the user sees.
  final String name;

  /// The Hugging Face repository the files come from.
  final String repository;

  @override
  final String revision;

  @override
  final List<PinnedModelFile> files;

  /// The terms of use the model's weights are distributed under.
  final Uri termsUri;

  @override
  Uri uri(PinnedModelFile file) => Uri.parse(
    'https://huggingface.co/$repository/resolve/$revision/${file.name}',
  );
}

/// EmbeddingGemma-300m, q4 (ADR 0144), under the Gemma Terms of Use.
final embeddingGemma = EmbeddingModel(
  id: 'embeddinggemma-300m-q4',
  name: 'EmbeddingGemma 300M',
  repository: 'onnx-community/embeddinggemma-300m-ONNX',
  revision: '5090578d9565bb06545b4552f76e6bc2c93e4a66',
  files: const [
    PinnedModelFile(
      GemmaEmbedder.modelFile,
      519322,
      'ad1dfee81a70f7944b9b9d1cc6e48075b832881cf33fab2f2b248be78f3f0043',
    ),
    PinnedModelFile(
      '${GemmaEmbedder.modelFile}_data',
      196725760,
      '599962c3143b040de2dd05e5975be3e9091dd067cacc6a8f7186e3203bab9e02',
    ),
    PinnedModelFile(
      GemmaEmbedder.tokenizerFile,
      20323312,
      '4dda02faaf32bc91031dc8c88457ac272b00c1016cc679757d1c441b248b9c47',
    ),
  ],
  termsUri: Uri.parse('https://ai.google.dev/gemma/terms'),
);
