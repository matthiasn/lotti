import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/gamey/animations.dart';
import 'package:lotti/themes/gamey/colors.dart';
import 'package:lotti/themes/gamey/gradients.dart';

/// Bottom-anchored text input bar for the evolution chat.
///
/// Features a rounded text field with an animated send button that pulses
/// while the assistant is processing a response.
class EvolutionMessageInput extends StatefulWidget {
  const EvolutionMessageInput({
    required this.onSend,
    this.isWaiting = false,
    this.enabled = true,
    super.key,
  });

  final ValueChanged<String> onSend;
  final bool isWaiting;
  final bool enabled;

  @override
  State<EvolutionMessageInput> createState() => _EvolutionMessageInputState();
}

class _EvolutionMessageInputState extends State<EvolutionMessageInput>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _pulseController = AnimationController(
      vsync: this,
      duration: GameyAnimations.pulse,
    );
    _pulseAnimation = Tween<double>(
      begin: GameyAnimations.pulseScaleMin,
      end: GameyAnimations.pulseScaleMax,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: GameyAnimations.symmetrical,
      ),
    );
    if (widget.isWaiting) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(EvolutionMessageInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isWaiting && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isWaiting && _pulseController.isAnimating) {
      _pulseController
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.isWaiting || !widget.enabled) return;
    widget.onSend(text);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final canSend = _controller.text.trim().isNotEmpty &&
        !widget.isWaiting &&
        widget.enabled;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: GameyColors.surfaceDarkElevated.withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(
              color: GameyColors.aiCyan.withValues(alpha: 0.15),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: widget.enabled && !widget.isWaiting,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSend(),
                onChanged: (_) => setState(() {}),
                maxLines: 4,
                minLines: 1,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: context.messages.agentEvolutionChatPlaceholder,
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                  filled: true,
                  fillColor: GameyColors.surfaceDark,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                      color: GameyColors.aiCyan,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                final scale = widget.isWaiting ? _pulseAnimation.value : 1.0;
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: _SendButton(
                onPressed: canSend ? _handleSend : null,
                isWaiting: widget.isWaiting,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.onPressed,
    required this.isWaiting,
  });

  final VoidCallback? onPressed;
  final bool isWaiting;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: onPressed != null || isWaiting ? GameyGradients.ai : null,
        color: onPressed == null && !isWaiting ? GameyColors.surfaceDark : null,
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          isWaiting ? Icons.hourglass_top_rounded : Icons.send_rounded,
          size: 20,
          color: onPressed != null || isWaiting
              ? Colors.white
              : Colors.white.withValues(alpha: 0.3),
        ),
        padding: EdgeInsets.zero,
      ),
    );
  }
}
