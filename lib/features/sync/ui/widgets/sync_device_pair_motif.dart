import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// What the two machines are doing to each other right now.
enum SyncDevicePairMotifState {
  /// Nothing configured yet: hollow dots between the devices.
  idle,

  /// A pairing in flight: the dots stream toward the other machine.
  connecting,

  /// Trust established: the gap closes into one solid accent line.
  linked,
}

/// The journey's recurring figure: a phone and a laptop with the space
/// between them, which fills as the machines meet — hollow dots before
/// anything is configured, streaming accent dots while connecting, and a
/// solid line once the devices trust each other.
///
/// One drawing shared by the entry state, the connecting step and the
/// verified celebration, so the flow keeps a single visual thread instead of
/// three unrelated illustrations.
class SyncDevicePairMotif extends StatefulWidget {
  const SyncDevicePairMotif({required this.state, super.key});

  final SyncDevicePairMotifState state;

  @override
  State<SyncDevicePairMotif> createState() => _SyncDevicePairMotifState();
}

class _SyncDevicePairMotifState extends State<SyncDevicePairMotif>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(SyncDevicePairMotif oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final animate =
        widget.state == SyncDevicePairMotifState.connecting &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!animate && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final deviceInk = widget.state == SyncDevicePairMotifState.linked
        ? tokens.colors.text.highEmphasis
        : tokens.colors.text.mediumEmphasis;

    final between = switch (widget.state) {
      SyncDevicePairMotifState.linked => DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.interactive.enabled,
          borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        ),
        child: SizedBox(
          width: tokens.spacing.step10,
          height: tokens.spacing.step1 * 2,
        ),
      ),
      SyncDevicePairMotifState.idle => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) SizedBox(width: tokens.spacing.step3),
            _Dot(color: tokens.colors.decorative.level02),
          ],
        ],
      ),
      SyncDevicePairMotifState.connecting => AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 4; i++) ...[
                if (i > 0) SizedBox(width: tokens.spacing.step3),
                _Dot(
                  color: tokens.colors.interactive.enabled.withValues(
                    alpha: _dotAlpha(i),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    };

    return Row(
      key: const Key('sync_device_pair_motif'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          LottiIcons.phone,
          size: IconSizes.xxl,
          color: deviceInk,
        ),
        SizedBox(width: tokens.spacing.step4),
        between,
        SizedBox(width: tokens.spacing.step4),
        Icon(
          LottiIcons.laptop,
          size: IconSizes.xxxl,
          color: deviceInk,
        ),
      ],
    );
  }

  /// A travelling brightness wave: each dot pulses on its own phase so the
  /// stream reads as motion toward the other device. Steady mid-strength when
  /// the controller is parked (reduced motion).
  double _dotAlpha(int index) {
    if (!_pulse.isAnimating) return 0.6;
    final phase = (_pulse.value - index * 0.15) % 1.0;
    return 0.35 + 0.65 * (0.5 + 0.5 * math.cos(2 * math.pi * phase));
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final side = tokens.spacing.step1 * 3;

    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: SizedBox(width: side, height: side),
    );
  }
}
