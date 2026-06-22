import 'package:flutter/material.dart';

/// Looping "words become a task" hero: ghosted spoken phrases drift up and
/// fade, then a crisp checklist card assembles (title + ticked items), holds,
/// dissolves, and the loop restarts. Previews the product's core promise.
///
/// Reduced motion: the resolved card is shown statically with no animation.
class CrystallizeHero extends StatefulWidget {
  const CrystallizeHero({
    required this.accent,
    required this.cardColor,
    required this.onCardColor,
    required this.ghostColor,
    super.key,
  });

  /// Tick/checkmark + title accent colour.
  final Color accent;

  /// Fill of the resolved task card (a light surface on the dark hero panel).
  final Color cardColor;

  /// Text colour on the resolved card.
  final Color onCardColor;

  /// Faint colour of the drifting "spoken" ghost phrases.
  final Color ghostColor;

  @override
  State<CrystallizeHero> createState() => _CrystallizeHeroState();
}

class _CrystallizeHeroState extends State<CrystallizeHero>
    with SingleTickerProviderStateMixin {
  static const _loop = Duration(seconds: 6);
  static const _ghosts = [
    '"remind me to call the dentist"',
    '"and book the car service"',
  ];
  static const _items = ['Call the dentist', 'Book car service'];

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _loop);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Ramp 0→1 across [a,b].
  static double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0, 1).toDouble();

  /// Fade in over [inA,inB], hold, fade out over [outA,outB].
  static double _window(
    double t,
    double inA,
    double inB,
    double outA,
    double outB,
  ) {
    final i = _seg(t, inA, inB);
    final o = 1 - _seg(t, outA, outB);
    return i < o ? i : o;
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = reduceMotion ? 0.72 : _controller.value;
        final ghostOpacity = reduceMotion
            ? 0.0
            : _window(t, 0.02, 0.12, 0.34, 0.46);
        final cardOpacity = reduceMotion
            ? 1.0
            : _window(t, 0.46, 0.58, 0.92, 1);

        return Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Drifting spoken phrases.
              Opacity(
                opacity: ghostOpacity,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < _ghosts.length; i++)
                      Transform.translate(
                        offset: Offset(0, -18 * t - i * 4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            _ghosts[i],
                            style: TextStyle(
                              color: widget.ghostColor,
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Resolved task card.
              Opacity(
                opacity: cardOpacity,
                child: _TaskCard(
                  t: t,
                  reduceMotion: reduceMotion,
                  accent: widget.accent,
                  cardColor: widget.cardColor,
                  onCardColor: widget.onCardColor,
                  items: _items,
                  seg: _seg,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.t,
    required this.reduceMotion,
    required this.accent,
    required this.cardColor,
    required this.onCardColor,
    required this.items,
    required this.seg,
  });

  final double t;
  final bool reduceMotion;
  final Color accent;
  final Color cardColor;
  final Color onCardColor;
  final List<String> items;
  final double Function(double, double, double) seg;

  @override
  Widget build(BuildContext context) {
    final titleIn = reduceMotion ? 1.0 : seg(t, 0.5, 0.64);
    return Container(
      width: 260,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: titleIn,
            child: Text(
              'Car & health errands',
              style: TextStyle(
                color: onCardColor,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ChecklistRow(
                label: items[i],
                accent: accent,
                onCardColor: onCardColor,
                appear: reduceMotion
                    ? 1.0
                    : seg(t, 0.6 + i * 0.08, 0.74 + i * 0.08),
                tick: reduceMotion
                    ? 1.0
                    : seg(t, 0.74 + i * 0.08, 0.84 + i * 0.08),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({
    required this.label,
    required this.accent,
    required this.onCardColor,
    required this.appear,
    required this.tick,
  });

  final String label;
  final Color accent;
  final Color onCardColor;
  final double appear;
  final double tick;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: appear,
      child: Transform.translate(
        offset: Offset(8 * (1 - appear), 0),
        child: Row(
          children: [
            Transform.scale(
              scale: tick,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(Icons.check_rounded, size: 15, color: accent),
              ),
            ),
            const SizedBox(width: 10),
            Text(label, style: TextStyle(color: onCardColor, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}
