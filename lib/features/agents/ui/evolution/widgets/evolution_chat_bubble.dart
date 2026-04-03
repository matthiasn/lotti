import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/thinking_disclosure.dart';
import 'package:lotti/features/ai_chat/ui/widgets/thinking_parser.dart';
import 'package:lotti/themes/theme.dart';

/// A single chat bubble in the evolution conversation.
///
/// Renders differently based on [role]:
/// - **user**: Right-aligned filled bubble
/// - **assistant**: Left-aligned surface bubble with markdown rendering
/// - **system**: Centered muted info pill
class EvolutionChatBubble extends StatelessWidget {
  const EvolutionChatBubble({
    required this.text,
    required this.role,
    this.animate = true,
    super.key,
  });

  final String text;

  /// One of 'user', 'assistant', or 'system'.
  final String role;

  /// Whether to animate the bubble on first appearance.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    return switch (role) {
      'user' => _UserBubble(text: text, animate: animate),
      'assistant' => _AssistantBubble(text: text, animate: animate),
      'system' => _SystemBubble(text: text, animate: animate),
      _ => const SizedBox.shrink(),
    };
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text, required this.animate});
  final String text;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final bubble = Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: context.colorScheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: context.colorScheme.onPrimary,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      ),
    );

    if (!animate) return bubble;
    return _AnimatedEntry(child: bubble);
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.text, required this.animate});
  final String text;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final segments = splitThinkingSegments(text);
    final hasVisibleContent = segments.any((seg) => !seg.isThinking);
    final bubblePadding = hasVisibleContent
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    final bubble = Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8, right: 24),
          padding: bubblePadding,
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHigh,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: context.colorScheme.shadow.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final seg in segments)
                if (seg.isThinking)
                  ThinkingDisclosure(thinking: seg.text)
                else
                  AgentMarkdownView(
                    seg.text,
                    style: TextStyle(
                      color: context.colorScheme.onSurface,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );

    if (!animate) return bubble;
    return _AnimatedEntry(child: bubble);
  }
}

class _SystemBubble extends StatelessWidget {
  const _SystemBubble({required this.text, required this.animate});
  final String text;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final bubble = Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.85,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  color: context.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );

    if (!animate) return bubble;
    return _AnimatedEntry(child: bubble);
  }
}

/// Fade + slide up entry animation for chat bubbles.
class _AnimatedEntry extends StatefulWidget {
  const _AnimatedEntry({required this.child});
  final Widget child;

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: AppTheme.animationDuration),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: AppTheme.animationCurve,
    );
    _slideAnimation =
        Tween<Offset>(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: AppTheme.animationCurve,
          ),
        );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}
