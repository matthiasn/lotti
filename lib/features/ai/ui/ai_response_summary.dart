import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/ai_response_summary_modal.dart';
import 'package:lotti/widgets/cards/index.dart';
import 'package:lotti/widgets/modal/modern_modal_utils.dart';

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

  String _filterTaskSummaryResponse(String response) {
    // Remove the first H1 header (title) from task summaries
    if (aiResponse.data.type == AiResponseType.taskSummary) {
      // Match the first H1 and everything on that line, plus any empty lines after it
      final titleRegex = RegExp(r'^#\s+.+$\n*', multiLine: true);
      return response.replaceFirst(titleRegex, '').trim();
    }
    return response;
  }

  @override
  Widget build(BuildContext context) {
    final filteredResponse =
        _filterTaskSummaryResponse(aiResponse.data.response);
    final content = SelectionArea(
      child: GptMarkdown(filteredResponse),
    );

    return ModernBaseCard(
      child: GestureDetector(
        onDoubleTap: () {
          ModernModalUtils.showSinglePageModal<void>(
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
