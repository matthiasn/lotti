import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AsrService {
  AsrService();

  static const platform = MethodChannel('lotti/transcribe');

  Future<void> transcribe({
    required String entryId,
    required String audioFilePath,
    String? model,
  }) async {
    final docDir = await getApplicationDocumentsDirectory();
    const defaultModel = 'ggml-small.bin';
    final modelPath = p.join(docDir.path, 'whisper', model ?? defaultModel);

    final wavPath = audioFilePath.replaceAll('.aac', '.wav');
    final session = await FFmpegKit.execute(
      '-i $audioFilePath -y -ar 16000 -ac 1 -c:a pcm_s16le $wavPath',
    );
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      try {
        final result = await platform.invokeMethod<String>(
          'transcribe',
          {
            'audioFilePath': wavPath,
            'modelPath': modelPath,
          },
        );

        if (result != null) {
          final transcript = AudioTranscript(
            created: DateTime.now(),
            library: 'whisper-1.4.0',
            model: model ?? defaultModel,
            detectedLanguage: 'en',
            transcript: result,
          );
          debugPrint('transcribe: $transcript');
          await getIt<PersistenceLogic>().addAudioTranscript(
            journalEntityId: entryId,
            transcript: transcript,
          );
        }
      } on PlatformException catch (e) {
        debugPrint('transcribe exception: $e');
      }
    } else if (ReturnCode.isCancel(returnCode)) {
      debugPrint('FFmpegKit cancelled');
    } else {
      debugPrint('FFmpegKit errored');
    }
  }
}
