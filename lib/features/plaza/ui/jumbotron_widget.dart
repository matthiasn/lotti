import 'package:flutter/material.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';

/// The giant screen behind the plaza: the project's name over the hero's
/// cover art, the attention count, and the top headlines. Captured on a
/// slow interval; the hero cover cross-fades every few seconds.
class JumbotronWidget extends StatefulWidget {
  const JumbotronWidget({
    required this.projectLabel,
    required this.taskCount,
    required this.attentionCount,
    required this.headlines,
    required this.covers,
    required this.widthMeters,
    required this.pxPerMeter,
    this.coverSeconds = 5,
    super.key,
  });

  final String projectLabel;
  final int taskCount;
  final int attentionCount;

  /// The top anomalies, most urgent first.
  final List<TaskAttention> headlines;

  /// Cover art URLs to cycle through behind the type.
  final List<String> covers;
  final double widthMeters;
  final double pxPerMeter;
  final double coverSeconds;

  @override
  State<JumbotronWidget> createState() => _JumbotronWidgetState();
}

class _JumbotronWidgetState extends State<JumbotronWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.coverSeconds * 1000).round()),
  )..repeat();

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double m(double meters) => meters * widget.pxPerMeter;
    final w = widget.widthMeters;
    final titlePx = m(0.11 * w);
    final bodyPx = m(0.035 * w);
    final pad = m(0.04 * w);
    return AnimatedBuilder(
      animation: _clock,
      builder: (context, _) {
        final covers = widget.covers;
        final cycle = _clock.lastElapsedDuration == null
            ? 0
            : _clock.lastElapsedDuration!.inMilliseconds ~/
                  (widget.coverSeconds * 1000);
        final cover = covers.isEmpty ? null : covers[cycle % covers.length];
        return Material(
          color: PlazaStyle.panel,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (cover != null)
                Opacity(
                  opacity: 0.55,
                  child: Image.network(
                    cover,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(),
                  ),
                ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x1A07050E), Color(0xE607050E)],
                  ),
                ),
              ),
              // One message at a time, headline scale: the project card,
              // then each headline in turn.
              // Every slide is laid out at its natural size and scaled
              // down to the panel: a long headline shrinks, it never
              // overflows the screen.
              Padding(
                padding: EdgeInsets.all(pad),
                child: LayoutBuilder(
                  builder: (context, constraints) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: SizedBox(
                      width: constraints.maxWidth,
                      child: _slide(cycle, titlePx, bodyPx, m),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _slide(
    int cycle,
    double titlePx,
    double bodyPx,
    double Function(double) m,
  ) {
    final slides = widget.headlines.take(3).length + 1;
    final slide = cycle % slides;
    if (slide == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.projectLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PlazaStyle.fontText,
              fontWeight: FontWeight.w700,
              fontSize: titlePx,
              height: 1,
              letterSpacing: -titlePx * 0.03,
              color: PlazaStyle.text,
              shadows: [
                Shadow(
                  color: PlazaStyle.teal.withValues(alpha: 0.7),
                  blurRadius: titlePx * 0.5,
                ),
              ],
            ),
          ),
          SizedBox(height: m(0.35)),
          Text(
            '${widget.taskCount} tasks · '
            '${widget.attentionCount} need attention',
            style: TextStyle(
              fontFamily: PlazaStyle.fontMono,
              fontSize: bodyPx * 2,
              color: PlazaStyle.teal,
            ),
          ),
        ],
      );
    }
    final a = widget.headlines[slide - 1];
    final frame = PlazaStyle.lantern(a.lantern);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Masthead: the project stays on screen while the
        // headlines turn.
        Text(
          '${widget.projectLabel}  ·  '
          '${widget.attentionCount} need attention',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: PlazaStyle.fontMono,
            fontSize: bodyPx * 1.3,
            color: PlazaStyle.teal,
          ),
        ),
        SizedBox(height: m(0.6)),
        // One status glyph, one word: the glyph is the state's mark, so
        // no disc beside it.
        Text(
          '${PlazaStyle.glyph(a)}  ${PlazaStyle.chip(a).label}',
          style: TextStyle(
            fontFamily: PlazaStyle.fontMono,
            fontSize: bodyPx * 1.8,
            fontWeight: FontWeight.w500,
            color: frame,
            shadows: [Shadow(color: frame, blurRadius: bodyPx * 0.6)],
          ),
        ),
        SizedBox(height: m(0.3)),
        Text(
          a.task.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: PlazaStyle.fontText,
            fontWeight: FontWeight.w700,
            fontSize: titlePx * 0.72,
            height: 1.05,
            letterSpacing: -titlePx * 0.02,
            color: PlazaStyle.text,
          ),
        ),
        if (a.reason.isNotEmpty) ...[
          SizedBox(height: m(0.3)),
          Text(
            a.reason,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: PlazaStyle.fontMono,
              fontSize: bodyPx * 1.7,
              color: const Color(0xF2FFFFFF),
            ),
          ),
        ],
        SizedBox(height: m(0.25)),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'fly there ›',
            style: TextStyle(
              fontFamily: PlazaStyle.fontText,
              fontSize: bodyPx * 1.7,
              fontWeight: FontWeight.w600,
              color: PlazaStyle.teal,
            ),
          ),
        ),
      ],
    );
  }
}
