import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/ai/ui/unified_ai_progress_view.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class ThoughtsModalHelper {
  static Future<void> showThoughtsModal({
    required BuildContext context,
    required WidgetRef ref,
    required String? promptId,
    required String entityId,
  }) async {
    if (promptId == null) {
      return;
    }

    ref.read(
      triggerNewInferenceProvider(
        entityId: entityId,
        promptId: promptId,
      ),
    );

    final prompt = await ref.read(
      aiConfigByIdProvider(promptId).future,
    );

    if (context.mounted && prompt is AiConfigPrompt) {
      await ModalUtils.showSingleSliverPageModal<void>(
        context: context,
        builder: (context) => UnifiedAiProgressUtils.progressPage(
          context: context,
          prompt: prompt,
          entityId: entityId,
          onTapBack: () => Navigator.of(context).pop(),
        ),
      );
    }
  }
}
