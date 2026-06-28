import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/celebration/celebration_params.dart';
import 'package:lotti/features/design_system/components/celebration/completion_celebration.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// A large, in-context preview for the celebration playground: a stack of fake
/// list rows with one **live** row in the middle, flanked by inert neighbours
/// above and below. Tapping the live row checks it off and fires a real burst
/// of [params] over its checkbox — so you see how the effect reads inside a list
/// (how the particles spread around the surrounding rows) rather than over a
/// lone dot.
///
/// The burst uses [params] directly (a single variant), so it reflects the
/// slider values live as you drag them.
class CelebrationPreviewHero extends StatefulWidget {
  const CelebrationPreviewHero({
    required this.params,
    this.neighbours = 2,
    this.replayTick = 0,
    this.framed = true,
    super.key,
  });

  /// The variant + tuned look the live row fires.
  final CelebrationParams params;

  /// How many inert rows to show above and below the live one (for context).
  final int neighbours;

  /// Whether to draw the surrounding card (surface + border). Set false when the
  /// hero already sits inside a framing panel (the playground editor card), so
  /// the rows sit on that surface instead of a nested same-colour card.
  final bool framed;

  /// A monotonically increasing counter; whenever it changes the hero replays
  /// the burst. The playground bumps it on each slider release so tuning a knob
  /// previews the result without a manual tap.
  final int replayTick;

  @override
  State<CelebrationPreviewHero> createState() => _CelebrationPreviewHeroState();
}

class _CelebrationPreviewHeroState extends State<CelebrationPreviewHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop;

  /// The live row's checkbox key — the burst anchors to this so the particles
  /// emit from the thing being "completed".
  final GlobalKey _anchorKey = GlobalKey();

  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void didUpdateWidget(CelebrationPreviewHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new replayTick means a slider was released — re-fire the burst so the
    // tuned change is previewed in place.
    if (widget.replayTick != oldWidget.replayTick) {
      _fire();
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  void _fire() {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    // Every tap re-fires the burst (auto-rearm) so the tune→preview loop never
    // hits a dead tap; the row stays checked as the "completed" anchor.
    setState(() => _checked = true);
    if (reduceMotion) return; // honour reduce-motion: no pop, no particle burst
    _pop.forward(from: 0);
    final anchor = _anchorKey.currentContext;
    if (anchor != null) {
      spawnCompletionBurst(
        anchor,
        params: widget.params,
        duration: const Duration(milliseconds: 1100),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    // Realistic sample rows (not skeleton bars) so the preview reads as an
    // actual checklist, with the live row as a concrete item you complete.
    final samples = [
      messages.settingsCelebrationsPreviewSample1,
      messages.settingsCelebrationsPreviewSample2,
      messages.settingsCelebrationsPreviewSample3,
    ];
    String sampleAt(int i) => samples[i % samples.length];

    final rows = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Neighbours stay unchecked so the only teal on screen marks the live
        // row, not inert context rows (avoids a salience inversion).
        for (var i = 0; i < widget.neighbours; i++)
          _PreviewRow(title: sampleAt(i), checked: false, dimmed: true),
        _PreviewRow(
          title: sampleAt(widget.neighbours),
          anchorKey: _anchorKey,
          checked: _checked,
          pop: _pop,
          onTap: _fire,
        ),
        for (var i = 0; i < widget.neighbours; i++)
          _PreviewRow(
            title: sampleAt(widget.neighbours + 1 + i),
            checked: false,
            dimmed: true,
          ),
      ],
    );

    final padded = Padding(
      padding: EdgeInsets.symmetric(vertical: tokens.spacing.step3),
      child: rows,
    );

    if (!widget.framed) return padded;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.surface.enabled,
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: tokens.colors.decorative.level02),
      ),
      child: padded,
    );
  }
}

/// One sample list row: a circular checkbox and a real task [title]. The live
/// row ([onTap] non-null) is fully opaque and tappable; neighbours are [dimmed]
/// and inert, present only to give the burst a surrounding context.
class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.checked,
    required this.title,
    this.dimmed = false,
    this.anchorKey,
    this.pop,
    this.onTap,
  });

  final bool checked;
  final String title;
  final bool dimmed;
  final GlobalKey? anchorKey;
  final Animation<double>? pop;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;

    Widget checkbox = Container(
      key: anchorKey,
      width: tokens.spacing.step5,
      height: tokens.spacing.step5,
      decoration: BoxDecoration(
        color: checked ? accent : Colors.transparent,
        // A rounded SQUARE (not a circle) so the rows read as a checklist to
        // complete, not a radio "pick one of these" group.
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        border: Border.all(
          color: checked ? accent : tokens.colors.decorative.level02,
          width: 1.5,
        ),
      ),
      child: checked
          ? Icon(
              Icons.check_rounded,
              size: tokens.spacing.step4,
              color: tokens.colors.surface.enabled,
            )
          : null,
    );
    if (pop != null) {
      checkbox = AnimatedBuilder(
        animation: pop!,
        builder: (context, child) => Transform.scale(
          scale: 1 + 0.18 * math.sin(pop!.value * math.pi),
          child: child,
        ),
        child: checkbox,
      );
    }

    final row = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step3,
      ),
      child: Row(
        children: [
          checkbox,
          SizedBox(width: tokens.spacing.step3),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                // A completed item reads struck-through and faded; an open item
                // stays high-emphasis so the live row is the focal content.
                color: checked
                    ? tokens.colors.text.lowEmphasis
                    : tokens.colors.text.highEmphasis,
                decoration: checked ? TextDecoration.lineThrough : null,
                decorationColor: tokens.colors.text.lowEmphasis,
              ),
            ),
          ),
          // A play glyph sits right next to the live row's title (not flung to
          // the far edge) so the two read as one "tap to preview" affordance,
          // not a selected radio option.
          if (onTap != null) ...[
            SizedBox(width: tokens.spacing.step2),
            Icon(
              Icons.play_arrow_rounded,
              size: tokens.spacing.step5,
              color: accent,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return Opacity(opacity: dimmed ? 0.45 : 1, child: row);
    }
    // The live row reads as "the highlighted row" the hint points at via a
    // brighter surface (a non-hue cue) plus a faint accent wash + border. The
    // highlight is drawn as the row's own background — no extra outer padding —
    // so its checkbox stays column-aligned with the inert neighbours above and
    // below.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        child: Ink(
          decoration: BoxDecoration(
            // A registering accent tint (the old 0.06 wash was invisible) plus
            // the border so the live row reads as highlighted, not just outlined.
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(tokens.radii.s),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: row,
        ),
      ),
    );
  }
}
