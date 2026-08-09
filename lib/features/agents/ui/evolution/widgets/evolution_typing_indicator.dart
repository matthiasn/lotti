import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Three dots pulsing in sequence while the agent composes its turn.
///
/// Occupies the same left-aligned position as an assistant turn, so the
/// answer lands where the waiting was rather than displacing it. Replaces a
/// 16px spinner beside a literal `'...'`, which read as an unstyled loading
/// artefact rather than a participant thinking.
class EvolutionTypingIndicator extends StatefulWidget {
  const EvolutionTypingIndicator({this.announceComposing = true, super.key});

  /// Whether the dots announce themselves as *the agent composing a reply*.
  ///
  /// False where that would be a lie: the session-opening frame reuses these
  /// dots while the agent is still reading the window, and its own text
  /// already carries the status. Announcing "composing a reply" there would
  /// contradict the words on screen before any reply exists.
  final bool announceComposing;

  /// One full travel of the wave across the three dots.
  static const Duration cycle = Duration(milliseconds: 1200);

  @override
  State<EvolutionTypingIndicator> createState() =>
      _EvolutionTypingIndicatorState();
}

class _EvolutionTypingIndicatorState extends State<EvolutionTypingIndicator>
    with SingleTickerProviderStateMixin {
  static const int _dotCount = 3;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: EvolutionTypingIndicator.cycle,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respecting reduced motion is not optional for a perpetual animation:
    // left running it would pulse for as long as the agent is thinking. Read
    // here rather than in initState so toggling the OS setting mid-response
    // takes effect — a model can be composing for minutes.
    if (MediaQuery.disableAnimationsOf(context)) {
      if (_controller.isAnimating) _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final dotSize = tokens.spacing.step3;

    // The dots carry no text, so without this a screen reader hears nothing
    // between sending a message and the reply arriving — indistinguishable
    // from a stuck chat, with the composer disabled meanwhile.
    return Semantics(
      liveRegion: widget.announceComposing,
      label: widget.announceComposing
          ? context.messages.agentRitualTypingSemantics
          : null,
      child: ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.only(bottom: tokens.spacing.step5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _dotCount; i++)
                Padding(
                  padding: EdgeInsets.only(
                    right: i == _dotCount - 1 ? 0 : tokens.spacing.step2,
                  ),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      return Opacity(
                        opacity: _opacityFor(i),
                        child: Container(
                          width: dotSize,
                          height: dotSize,
                          decoration: BoxDecoration(
                            color: tokens.colors.text.mediumEmphasis,
                            shape: BoxShape.circle,
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Each dot rides the same wave, offset by a third of the cycle, so the
  /// pulse travels left to right instead of all three blinking together.
  double _opacityFor(int index) {
    const minOpacity = 0.25;
    const maxOpacity = 1.0;
    final phase = (_controller.value - index / _dotCount) % 1.0;
    // Triangle wave: rises over the first half of the phase, falls over the
    // second. Cheaper than a sine and visually indistinguishable at this size.
    final wave = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
    return minOpacity + (maxOpacity - minOpacity) * wave;
  }
}
