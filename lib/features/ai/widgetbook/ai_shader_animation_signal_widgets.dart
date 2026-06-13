part of 'ai_shader_animations_widgetbook.dart';

class _SignalMetric {
  const _SignalMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _SignalReadoutPanel extends StatelessWidget {
  const _SignalReadoutPanel({required this.metrics});

  final List<_SignalMetric> metrics;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final labelStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.lowEmphasis,
    );
    final valueStyle = tokens.typography.styles.body.bodySmall.copyWith(
      color: tokens.colors.text.mediumEmphasis,
      fontFeatures: numericBadgeFontFeatures,
    );
    final rows = <TableRow>[];

    for (var index = 0; index < metrics.length; index += 2) {
      final left = metrics[index];
      final right = index + 1 < metrics.length ? metrics[index + 1] : null;
      rows.add(
        TableRow(
          children: [
            _SignalMetricCell(
              text: left.label,
              style: labelStyle,
              endPadding: spacing.step2,
              bottomPadding: spacing.step2,
            ),
            _SignalMetricCell(
              text: left.value,
              style: valueStyle,
              endPadding: spacing.step6,
              bottomPadding: spacing.step2,
            ),
            _SignalMetricCell(
              text: right?.label,
              style: labelStyle,
              endPadding: spacing.step2,
              bottomPadding: spacing.step2,
            ),
            _SignalMetricCell(
              text: right?.value,
              style: valueStyle,
              bottomPadding: spacing.step2,
            ),
          ],
        ),
      );
    }

    return Table(
      columnWidths: const {
        0: IntrinsicColumnWidth(),
        1: FlexColumnWidth(),
        2: IntrinsicColumnWidth(),
        3: FlexColumnWidth(),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: rows,
    );
  }
}

class _SignalMetricCell extends StatelessWidget {
  const _SignalMetricCell({
    required this.text,
    required this.style,
    this.endPadding,
    this.bottomPadding,
  });

  final String? text;
  final TextStyle style;
  final double? endPadding;
  final double? bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.only(
        end: endPadding ?? 0,
        bottom: bottomPadding ?? 0,
      ),
      child: Text(
        text ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: style,
      ),
    );
  }
}

class _RoutePreview extends StatelessWidget {
  const _RoutePreview({
    required this.label,
    required this.width,
    required this.child,
  });

  final String label;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          Center(child: child),
        ],
      ),
    );
  }
}

class _WidgetbookCanvas extends StatelessWidget {
  const _WidgetbookCanvas({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return DecoratedBox(
      decoration: BoxDecoration(color: tokens.colors.background.level01),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.sectionGap),
        child: child,
      ),
    );
  }
}
