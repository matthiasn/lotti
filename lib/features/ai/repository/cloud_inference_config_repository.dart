import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/cloud_inference_config.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'cloud_inference_config_repository.g.dart';

class CloudInferenceConfigRepository {
  CloudInferenceConfigRepository(this.docDir);

  final Directory docDir;

  Future<CloudInferenceConfig> getConfig() async {
    final jsonFile = File(join(docDir.path, 'cloud_inference_config.json'));
    final jsonString = await jsonFile.readAsString();

    return CloudInferenceConfig.fromJson(
      jsonDecode(jsonString) as Map<String, dynamic>,
    );
  }
}

@riverpod
CloudInferenceConfigRepository cloudInferenceConfigRepository(Ref ref) {
  return CloudInferenceConfigRepository(getDocumentsDirectory());
}
