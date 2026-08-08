import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/widgets/agent_markdown_view.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/thinking_disclosure.dart';
import 'package:lotti/features/ai_chat/ui/widgets/thinking_parser.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/themes/theme.dart';

/// A single turn in the evolution conversation.
///
/// The three roles are separated by *position and containment*, not by two
/// competing fills:
///
/// - **assistant** — unbubbled prose on the page ground, full measure. The
///   agent does the long-form talking here, and a container around a
///   paragraph that already spans the column adds an edge without adding
///   meaning. It also kept the agent's own words at the lowest contrast on
///   the page, which is backwards.
/// - **user** — right-aligned, contained, and deliberately narrower than the
///   measure. Your turns are short; the indent is what makes the exchange
///   scannable at a glance.
/// - **system** — a quiet centred line. It reports on the session rather than
///   speaking in it, so it carries no container at all.
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

  /// How much of the column a user turn may occupy. Short by design — a user
  /// turn that reached the full measure would be indistinguishable from the
  /// agent's prose beside it.
  static const double userTurnWidthFactor = 0.8;

  @override
  Widget build(BuildContext context) {
    return switch (role) {
      'user' => _UserTurn(text: text, animate: animate),
      'assistant' => _AssistantTurn(text: text, animate: animate),
      'system' => _SystemNote(text: text, animate: animate),
      _ => const SizedBox.shrink(),
    };
  }
}

class _UserTurn extends StatelessWidget {
  const _UserTurn({required this.text, required this.animate});
  final String text;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    final turn = Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        alignment: Alignment.centerRight,
        widthFactor: EvolutionChatBubble.userTurnWidthFactor,
        child: Container(
          margin: EdgeInsets.only(bottom: tokens.spacing.step5),
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step5,
            vertical: tokens.spacing.step4,
          ),
          decoration: BoxDecoration(
            color: tokens.colors.background.level03,
            borderRadius: BorderRadius.circular(tokens.radii.l),
            border: Border.all(color: tokens.colors.decorative.level02),
          ),
          child: Text(
            text,
            style: tokens.typography.styles.body.bodyLarge.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ),
      ),
    );

    if (!animate) return turn;
    return _AnimatedEntry(child: turn);
  }
}

class _AssistantTurn extends StatelessWidget {
  const _AssistantTurn({required this.text, required this.animate});
  final String text;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final segments = splitThinkingSegments(text);

    final turn = Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final seg in segments)
            if (seg.isThinking)
              ThinkingDisclosure(thinking: seg.text)
            else
              AgentMarkdownView(
                seg.text,
                style: tokens.typography.styles.body.bodyLarge.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
        ],
      ),
    );

    if (!animate) return turn;
    return _AnimatedEntry(child: turn);
  }
}

class _SystemNote extends StatelessWidget {
  const _SystemNote({required this.text, required this.animate});
  final String text;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    final note = Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: tokens.typography.styles.others.caption.copyWith(
          color: tokens.colors.text.lowEmphasis,
        ),
      ),
    );

    if (!animate) return note;
    return _AnimatedEntry(child: note);
  }
}

/// Fade + slide up entry animation for chat turns.
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
