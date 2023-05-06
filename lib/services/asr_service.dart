import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AsrService {
  AsrService();

  static const platform = MethodChannel('lotti/transcribe');

  Future<String> transcribe({
    required String audioFilePath,
    String? modelPath,
  }) async {
    final docDir = await getApplicationDocumentsDirectory();
    final defaultModelPath = p.join(docDir.path, 'whisper', 'ggml-small.bin');

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
            'modelPath': modelPath ?? defaultModelPath,
          },
        );
        debugPrint('transcribe: $result');

        getIt<LoggingDb>().captureEvent(
          'transcribe $result',
          domain: 'ASR',
        );
        return '$result';
      } on PlatformException catch (e) {
        debugPrint('transcribe exception: $e');
      }
    } else if (ReturnCode.isCancel(returnCode)) {
      debugPrint('FFmpegKit cancelled');
    } else {
      debugPrint('FFmpegKit errored');
    }

    return 'Not implemented yet';
  }
}
