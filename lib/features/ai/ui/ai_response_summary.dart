import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/ai_response_summary_modal.dart';
import 'package:lotti/features/ai/ui/expandable_ai_response_summary.dart';
import 'package:lotti/features/ai/ui/generated_prompt_card.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class AiResponseSummary extends StatelessWidget {
  const AiResponseSummary(
    this.aiResponse, {
    required this.linkedFromId,
    required this.fadeOut,
    super.key,
  });

  final AiResponseEntry aiResponse;
  final String? linkedFromId;
  final bool fadeOut;

  @override
  Widget build(BuildContext context) {
    // Use expandable summary for task summaries
    if (aiResponse.data.type == AiResponseType.taskSummary) {
      return ExpandableAiResponseSummary(
        aiResponse,
        linkedFromId: linkedFromId,
      );
    }

    // Use specialized card for generated prompts
    if (aiResponse.data.type == AiResponseType.promptGeneration) {
      return GeneratedPromptCard(
        aiResponse,
        linkedFromId: linkedFromId,
      );
    }

    // For other response types, use the original implementation
    final content = SelectionArea(
      child: GptMarkdown(aiResponse.data.response),
    );

    return ModernBaseCard(
      child: GestureDetector(
        onDoubleTap: () {
          ModalUtils.showSinglePageModal<void>(
            context: context,
            builder: (BuildContext _) {
              return AiResponseSummaryModalContent(
                aiResponse,
                linkedFromId: linkedFromId,
              );
            },
          );
        },
        child: fadeOut
            ? ShaderMask(
                shaderCallback: (rect) {
                  return const LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    stops: [0.3, 1.0],
                    colors: [
                      Colors.black,
                      Colors.transparent,
                    ],
                  ).createShader(
                    Rect.fromLTRB(
                      0,
                      0,
                      rect.width,
                      rect.height,
                    ),
                  );
                },
                blendMode: BlendMode.dstIn,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: content,
                ),
              )
            : content,
      ),
    );
  }
}
