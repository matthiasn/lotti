import 'package:flutter/foundation.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/ui/cover_image.dart';
import 'package:lotti/features/plaza/ui/plaza_copy.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The giant screen behind the plaza: the project's name over the hero's
/// cover art, the attention count, and the top headlines. Captured on a
/// slow interval; the hero cover turns every few seconds on the harness
/// [clock], so nothing here ticks on its own.
class JumbotronWidget extends StatelessWidget {
  const JumbotronWidget({
    required this.projectLabel,
    required this.taskCount,
    required this.attentionCount,
    required this.headlines,
    required this.covers,
    required this.widthMeters,
    required this.pxPerMeter,
    required this.clock,
    this.pinProjectCard,
    this.isCategory = false,
    super.key,
  });

  /// While this reads true the screen holds the project card instead of
  /// turning through the headlines: what a tour stop or a fly-to lands on.
  final ValueListenable<bool>? pinProjectCard;

  final String projectLabel;
  final int taskCount;
  final int attentionCount;
  final bool isCategory;

  /// The top anomalies, most urgent first.
  final List<TaskAttention> headlines;

  /// Cover art URLs to cycle through behind the type.
  final List<String> covers;
  final double widthMeters;
  final double pxPerMeter;

  /// How long each cover holds before the next.
  static const coverSeconds = 5.0;

  /// Elapsed seconds, advanced by the harness once per painted frame.
  final ValueListenable<double> clock;

  @override
  Widget build(BuildContext context) {
    double m(double meters) => meters * pxPerMeter;
    final w = widthMeters;
    final titlePx = m(0.11 * w);
    final bodyPx = m(0.035 * w);
    final pad = m(0.04 * w);
    final pin = pinProjectCard;
    return AnimatedBuilder(
      animation: pin == null ? clock : Listenable.merge([clock, pin]),
      builder: (context, _) {
        final cycle = (clock.value / coverSeconds).floor();
        final pinned = pin?.value ?? false;
        final cover = covers.isEmpty ? null : covers[cycle % covers.length];
        return Material(
          color: PlazaStyle.panel,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (cover != null)
                Opacity(
                  opacity: 0.55,
                  child: CoverImage(url: cover),
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
                      child: _slide(
                        pinned ? 0 : cycle,
                        titlePx,
                        bodyPx,
                        m,
                        PlazaCopy(context.messages),
                      ),
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
    PlazaCopy copy,
  ) {
    final slides = headlines.take(3).length + 1;
    final slide = cycle % slides;
    if (slide == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            projectLabel,
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
            '${isCategory ? copy.messages.projectCountSummary(taskCount) : copy.messages.plazaTaskCount(taskCount)} · ${copy.messages.plazaNeedsAttention(attentionCount)}',
            style: TextStyle(
              fontFamily: PlazaStyle.fontMono,
              fontSize: bodyPx * 2,
              color: PlazaStyle.teal,
            ),
          ),
        ],
      );
    }
    final a = headlines[slide - 1];
    final frame = PlazaStyle.taskColor(a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Masthead: the project stays on screen while the
        // headlines turn.
        Text(
          '$projectLabel  ·  '
          '${copy.messages.plazaNeedsAttention(attentionCount)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: PlazaStyle.fontMono,
            fontSize: bodyPx * 1.3,
            color: PlazaStyle.teal,
          ),
        ),
        SizedBox(height: m(0.6)),
        // One status glyph, one word, in the display voice: the state's
        // mark, heavy, like the facade's marquee band.
        Text(
          '${PlazaStyle.glyph(a)} ${copy.state(a).toUpperCase()}',
          style: TextStyle(
            fontFamily: PlazaStyle.fontText,
            fontSize: bodyPx * 1.8,
            fontWeight: FontWeight.w800,
            letterSpacing: bodyPx * 0.12,
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
        if (copy.reason(a).isNotEmpty) ...[
          SizedBox(height: m(0.3)),
          Text(
            copy.reason(a),
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
            copy.messages.plazaFlyThere,
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
