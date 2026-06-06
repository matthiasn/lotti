import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Full-screen vignette that plays after the user finishes the
/// hold-to-confirm gesture. ~3.4 s total, three fading caption
/// states, lock → check icon transition.
///
/// Mirrors `prototype/screens/commit.jsx → LockInScene`. Calls
/// [onComplete] when the sequence finishes so the host page can
/// route back to the Day view in committed state.
class LockInScene extends StatefulWidget {
  const LockInScene({
    required this.onComplete,
    this.totalDuration = const Duration(milliseconds: 3400),
    super.key,
  });

  final VoidCallback onComplete;
  final Duration totalDuration;

  @override
  State<LockInScene> createState() => _LockInSceneState();
}

class _LockInSceneState extends State<LockInScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: widget.totalDuration)
          ..addStatusListener(_onStatusChanged)
          ..forward();
  }

  void _onStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeStatusListener(_onStatusChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final messages = context.messages;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        // Caption schedule from the prototype:
        // 0.00–0.18 → "Locking in…"
        // 0.18–0.50 → "Today is yours."
        // 0.50–1.00 → "Today is yours." + sub-line
        final caption = t < 0.18
            ? messages.dailyOsNextCommitLockingIn
            : messages.dailyOsNextCommitTodayIsYours;
        final showSubline = t >= 0.5;

        return IgnorePointer(
          child: ColoredBox(
            color: tokens.colors.background.level01.withValues(alpha: 0.92),
            child: Stack(
              children: [
                // Radial teal vignette over the whole frame.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        radius: 0.9,
                        colors: [
                          teal.withValues(alpha: 0.28 * t.clamp(0.0, 1.0)),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LockOrb(progress: t, color: teal),
                      SizedBox(height: tokens.spacing.step6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Text(
                          caption,
                          key: ValueKey(caption),
                          // Calm display moment — 26/600 per the
                          // handoff's LockInScene caption spec.
                          style: calmDisplayStyle(tokens),
                        ),
                      ),
                      if (showSubline) ...[
                        SizedBox(height: tokens.spacing.step3),
                        Opacity(
                          opacity: ((t - 0.5) * 2).clamp(0.0, 1.0),
                          child: Text(
                            messages.dailyOsNextCommitShepherdSubline,
                            style: tokens.typography.styles.body.bodyMedium
                                .copyWith(
                                  color: tokens.colors.text.mediumEmphasis,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LockOrb extends StatelessWidget {
  const _LockOrb({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    const size = 160.0;
    // Cross-fade from soft alpha → solid teal at the ~25% mark.
    final fillAlpha = (progress * 4).clamp(0.0, 1.0);
    final showCheck = progress >= 0.25;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.16 + 0.84 * fillAlpha),
            color.withValues(alpha: 0.10),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.5 * fillAlpha),
            blurRadius: 120,
            spreadRadius: 16,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          showCheck ? Icons.check_rounded : Icons.lock_outline_rounded,
          size: 56,
          color: tokens.colors.text.onInteractiveAlert,
        ),
      ),
    );
  }
}
