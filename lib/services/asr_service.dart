import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class AsrService {
  AsrService();

  static const platform = MethodChannel('lotti/transcribe');

  Future<String> transcribe({
    required String audioFilePath,
    required String modelPath,
  }) async {
    debugPrint('transcribe $audioFilePath');

    try {
      final result = await platform.invokeMethod<String>(
        'transcribe',
        {
          'audioFilePath': audioFilePath,
          'modelPath': modelPath,
        },
      );
      debugPrint('transcribe: $result');
    } on PlatformException catch (e) {
      debugPrint('transcribe exception: $e');
    }

    return 'Not implemented yet';
  }
}
