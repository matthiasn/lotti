import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AsrService {
  AsrService();

  static const platform = MethodChannel('lotti/transcribe');
  String model = 'tiny';

  Future<void> transcribe({required JournalAudio entry}) async {
    final audioFilePath = await AudioUtils.getFullAudioPath(entry);

    final start = DateTime.now();
    final docDir = await getApplicationDocumentsDirectory();
    final modelFile = 'ggml-$model.bin';
    final modelPath = p.join(docDir.path, 'whisper', modelFile);

    final wavPath = audioFilePath.replaceAll('.aac', '.wav');
    final session = await FFmpegKit.execute(
      '-i $audioFilePath -y -ar 16000 -ac 1 -c:a pcm_s16le $wavPath',
    );
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      try {
        final language = await platform.invokeMethod<String>(
          'detectLanguage',
          {
            'audioFilePath': wavPath,
            'modelPath': modelPath,
          },
        );

        getIt<LoggingDb>().captureEvent(
          language,
          domain: 'ASR',
          subDomain: 'detectLanguage',
        );

        final result = await platform.invokeMethod<String>(
          'transcribe',
          {
            'audioFilePath': wavPath,
            'modelPath': modelPath,
          },
        );
        final finish = DateTime.now();

        if (result != null) {
          final transcript = AudioTranscript(
            created: DateTime.now(),
            library: 'whisper-1.4.0',
            model: model,
            detectedLanguage: language ?? 'en',
            transcript: result.trim(),
            processingTime: finish.difference(start),
          );

          await getIt<PersistenceLogic>().addAudioTranscript(
            journalEntityId: entry.meta.id,
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
