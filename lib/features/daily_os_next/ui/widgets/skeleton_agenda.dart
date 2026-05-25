import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Placeholder agenda rendered behind the reasoning panel while the
/// real plan is being drafted.
///
/// Four card-shaped rows with a horizontally moving shimmer band — a
/// simple alpha gradient over a 200% background, 1800 ms cycle.
class SkeletonAgenda extends StatefulWidget {
  const SkeletonAgenda({this.cardCount = 4, super.key});

  final int cardCount;

  @override
  State<SkeletonAgenda> createState() => _SkeletonAgendaState();
}

class _SkeletonAgendaState extends State<SkeletonAgenda>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = Ticker(_onTick)..start();
  }

  void _onTick(Duration t) {
    setState(() => _elapsed = t);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.cardCount; i++) ...[
          _ShimmerCard(elapsedMs: _elapsed.inMilliseconds + i * 220),
          if (i < widget.cardCount - 1) SizedBox(height: tokens.spacing.step3),
        ],
      ],
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard({required this.elapsedMs});

  final int elapsedMs;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final base = tokens.colors.background.level02;
    final highlight = tokens.colors.background.level03;
    final t = (elapsedMs % 1800) / 1800.0;
    // The shimmer band slides from -0.5 to 1.5 in normalised x so it
    // visibly enters and exits the card edges.
    final stop = -0.5 + 2.0 * t;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radii.l),
        gradient: LinearGradient(
          colors: [base, highlight, base],
          stops: [
            (stop - 0.25).clamp(0.0, 1.0),
            stop.clamp(0.0, 1.0),
            (stop + 0.25).clamp(0.0, 1.0),
          ],
        ),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
    );
  }
}
