import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/ai/repository/ollama_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ollama_image_analysis.g.dart';

@riverpod
class AiImageAnalysisController extends _$AiImageAnalysisController {
  final JournalDb _db = getIt<JournalDb>();

  @override
  String build({
    required String id,
  }) {
    analyzeImage();
    return '';
  }

  Future<void> analyzeImage() async {
    final entry = await _db.journalEntityById(id);

    if (entry is! JournalImage) {
      return;
    }

    state = '';

    const prompt =
        'Describe the image in detail, including its content, style, and any '
        'relevant information that can be gleaned from the image. '
        'Be as detailed as possible, and provide a comprehensive analysis '
        'of the image.';

    final buffer = StringBuffer();
    final image = await getImage(entry);

    const model = 'llama3.2-vision:latest'; // TODO: make configurable
    const temperature = 0.6;

    final stream = ref.read(ollamaRepositoryProvider).generate(
      prompt,
      model: model,
      temperature: temperature,
      images: [image],
    );

    await for (final chunk in stream) {
      buffer.write(chunk.text);
      state = buffer.toString();
    }

    final completeResponse = buffer.toString();

    print(completeResponse);
  }

  Future<String> getImage(JournalImage image) async {
    final fullPath = getFullImagePath(image);
    final bytes = await File(fullPath).readAsBytes();
    final base64String = base64Encode(bytes);

    return base64String;
  }
}
