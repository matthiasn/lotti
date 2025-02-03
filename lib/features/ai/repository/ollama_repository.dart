import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ollama/ollama.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ollama_repository.g.dart';

class OllamaRepository {
  OllamaRepository({
    Ollama? ollama,
  }) : _ollama = ollama ?? Ollama();
  final Ollama _ollama;

  Stream<CompletionChunk> generate(
    String prompt, {
    required String model,
    required double temperature,
    String? system,
    List<String>? images,
  }) {
    return _ollama.generate(
      prompt,
      model: model,
      system: system,
      options: ModelOptions(
        temperature: temperature,
      ),
      images: images,
    );
  }
}

@riverpod
OllamaRepository ollamaRepository(Ref ref) {
  return OllamaRepository();
}
