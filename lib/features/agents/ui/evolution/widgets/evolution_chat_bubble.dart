import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/thinking_disclosure.dart';
import 'package:lotti/features/ai_chat/ui/widgets/thinking_parser.dart';
import 'package:lotti/themes/gamey/animations.dart';
import 'package:lotti/themes/gamey/colors.dart';
import 'package:lotti/themes/gamey/gradients.dart';

/// A single chat bubble in the evolution conversation.
///
/// Renders differently based on [role]:
/// - **user**: Right-aligned, cyan gradient background, white text
/// - **assistant**: Left-aligned, elevated dark surface, markdown rendering
/// - **system**: Centered, muted surface, small text with icon
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
          decoration: const BoxDecoration(
            gradient: GameyGradients.ai,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
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

    final bubble = Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8, right: 24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: GameyColors.surfaceDarkElevated,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(18),
            ),
            boxShadow: [
              BoxShadow(
                color: GameyColors.aiCyan.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 2),
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
                  GptMarkdown(
                    seg.text,
                    style: const TextStyle(
                      color: Colors.white,
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
          color: GameyColors.surfaceDark.withValues(alpha: 0.6),
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
                  color: Colors.white.withValues(alpha: 0.6),
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
      duration: GameyAnimations.normal,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: GameyAnimations.smooth,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: GameyAnimations.smooth,
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
