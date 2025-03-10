import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/repository/ollama_repository.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ollama_image_analysis.g.dart';

@riverpod
class AiImageAnalysisController extends _$AiImageAnalysisController {
  @override
  String build({
    required String id,
  }) {
    ref.cacheFor(entryCacheDuration);
    return '';
  }

  Future<void> analyzeImage() async {
    final provider = entryControllerProvider(id: id);
    final notifier = ref.read(provider.notifier);
    final entry = ref.watch(provider).value?.entry;

    if (entry is! JournalImage) {
      return;
    }

    await notifier.save();

    state = '';

    const prompt =
        'Describe the image in detail, including its content, style, and any '
        'relevant information that can be gleaned from the image. '
        'If the image is the screenshot of a website, then focus on the '
        'the content of the website. Do not make up names. ';

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

    final completeResponse =
        '```\nDisclaimer: the remainder of this entry until the next linked entry '
        "was generated by a multimodal AI model analysing the entry's image. "
        'Therefore, it may contain inaccuracies or errors. '
        'Please double-check the information before using it. '
        'If there are similar concepts to what is discussed in the history '
        'of a task, take the information into account but always assume that '
        'the information outside of this section is more accurate. \n```'
        '\n\n$state';

    await notifier.addTextToImage(completeResponse);
  }

  Future<String> getImage(JournalImage image) async {
    final fullPath = getFullImagePath(image);
    final bytes = await File(fullPath).readAsBytes();
    final base64String = base64Encode(bytes);

    return base64String;
  }
}
