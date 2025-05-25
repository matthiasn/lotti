import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/ui/settings/inference_provider_name_widget.dart';

/// A specialized widget for displaying model subtitles that shows the inference provider name
class ModelSubtitleWidget extends ConsumerWidget {
  const ModelSubtitleWidget({
    required this.model,
    super.key,
  });

  final AiConfigModel model;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InferenceProviderNameWidget(
      providerId: model.inferenceProviderId,
    );
  }
}
