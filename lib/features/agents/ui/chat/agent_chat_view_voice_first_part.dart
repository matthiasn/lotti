part of 'agent_chat_view.dart';

/// How wide a bubble may grow: the reading width; in a conversation on a
/// narrow screen the user's words stop short of the far edge, so where a
/// message sits says who spoke, not only its fill.
double _bubbleWidth(BuildContext context, {required bool isUser}) {
  const userShare = 0.8;
  final width = MediaQuery.sizeOf(context).width;
  return isUser
      ? (width * userShare).clamp(0.0, kActionListContentMaxWidth)
      : kActionListContentMaxWidth;
}

/// Her turn while she is thinking: unboxed in a conversation, where her
/// words are unboxed too, so it never changes shape on answering.
class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble({required this.label, this.conversational = false});

  final String label;
  final bool conversational;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Semantics(
      label: label,
      child: Align(
        alignment: Alignment.centerLeft,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: conversational ? null : tokens.colors.background.level02,
            borderRadius: BorderRadius.circular(tokens.radii.l),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: conversational ? 0 : tokens.spacing.step4,
              vertical: tokens.spacing.step3,
            ),
            // Dots that pulse in turn, so the wait reads as an answer on its
            // way; the label above is what a screen reader hears.
            child: const AgentTypingIndicator(
              announceComposing: false,
              spaced: false,
            ),
          ),
        ),
      ),
    );
  }
}
