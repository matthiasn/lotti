import 'package:freezed_annotation/freezed_annotation.dart';

part 'cloud_inference_config.freezed.dart';
part 'cloud_inference_config.g.dart';

@freezed
class CloudInferenceConfig with _$CloudInferenceConfig {
  const factory CloudInferenceConfig({
    required String baseUrl,
    required String apiKey,
    required String geminiApiKey,
  }) = _CloudInferenceConfig;

  factory CloudInferenceConfig.fromJson(Map<String, dynamic> json) =>
      _$CloudInferenceConfigFromJson(json);
}
