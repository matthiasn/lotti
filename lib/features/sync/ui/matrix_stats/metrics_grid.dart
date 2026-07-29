import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

class MetricsGrid extends StatelessWidget {
  const MetricsGrid({
    required this.entries,
    required this.labelFor,
    super.key,
  });

  final List<MapEntry<String, int>> entries;
  final String Function(String key) labelFor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // One gap value drives both the Wrap and the width arithmetic; they must
    // agree or the last column overflows its row.
    final gap = tokens.spacing.step3;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width < 380
            ? 2
            : width < 560
            ? 3
            : 4;
        final tileWidth = (width - (crossAxisCount - 1) * gap) / crossAxisCount;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final e in entries)
              SizedBox(
                key: Key('metric:${e.key}'),
                width: tileWidth,
                child: MetricTile(
                  label: labelFor(e.key),
                  toneKey: e.key,
                  value: e.value,
                ),
              ),
          ],
        );
      },
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    required this.label,
    required this.value,
    required this.toneKey,
    super.key,
  });

  final String label;
  final int value;
  final String toneKey;

  /// The hue this tile's fill is tinted with — the whole point of the tile,
  /// since the tint is what separates the three outcomes at a glance.
  ///
  /// Bound to the token tree rather than `colorScheme`, which resolved to the
  /// same three colours only because the app theme *is* `DesignSystemTheme`.
  /// Reading them by their token names says which ramp each one belongs to.
  Color _tone(DsTokens tokens) {
    // Conflicts are the one outcome that needs the user's attention; a drop
    // is informational, everything else is routine throughput.
    if (toneKey == 'conflictsCreated') {
      return tokens.colors.alert.error.defaultColor;
    }
    if (toneKey.startsWith('droppedByType')) {
      return tokens.colors.alert.info.defaultColor;
    }
    return tokens.colors.interactive.enabled;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final tone = _tone(tokens);
    final cardColor = tone.withValues(alpha: SurfaceAlphas.tint);

    // Deliberately NOT a DesignSystemSectionCard: that component fixes its
    // fill to `background.level02`, which would erase the tone tint carrying
    // this tile's categorisation (see `SurfaceAlphas.tint`).
    return Container(
      padding: EdgeInsets.all(tokens.spacing.step4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(tokens.radii.m),
        border: Border.all(color: tokens.colors.decorative.level02),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          Text(
            value.toString(),
            // No weight override: `subtitle1` already carries semiBold.
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
