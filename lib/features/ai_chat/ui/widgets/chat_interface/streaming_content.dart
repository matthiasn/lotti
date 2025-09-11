import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/thinking_disclosure.dart';
import 'package:lotti/features/ai_chat/ui/widgets/thinking_parser.dart';

class StreamingContent extends StatelessWidget {
  const StreamingContent({
    required this.content,
    required this.isUser,
    required this.theme,
    super.key,
  });

  final String content;
  final bool isUser;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (content.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: isUser
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Thinking...',
            style: TextStyle(
              color: isUser
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    // Segment thinking/visible parts defensively; on parsing issues, render
    // the raw content as a single non-thinking segment.
    final segments = () {
      try {
        return splitThinkingSegments(content);
      } on Exception {
        return [ThinkingSegment(isThinking: false, text: content)];
      }
    }();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final seg in segments)
          if (seg.isThinking)
            ThinkingDisclosure(thinking: seg.text)
          else if (isUser)
            SelectionArea(
              child: DefaultTextStyle.merge(
                style: TextStyle(color: theme.colorScheme.onPrimary),
                child: GptMarkdown(seg.text),
              ),
            )
          else
            GptMarkdown(seg.text),
      ],
    );
  }
}
