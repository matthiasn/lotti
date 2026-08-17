import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/painting.dart';

/// The full text one chart tooltip renders, base text and children joined.
///
/// The shared tooltip builders put every line in `children` (a date header,
/// then a quiet label and a bold value per series) and leave the base `text`
/// empty, because each line carries its own style. A test reading `.text`
/// alone therefore sees nothing at all — which is how an assertion about a
/// tooltip's contents can pass while the tooltip says something else entirely.
String lineTooltipText(LineTooltipItem item) =>
    _joined(item.text, item.children);

/// [lineTooltipText] for the bar-chart tooltip item.
String barTooltipText(BarTooltipItem item) => _joined(item.text, item.children);

String _joined(String text, List<TextSpan>? children) =>
    text +
    [for (final child in children ?? const <TextSpan>[]) child.toPlainText()]
        .join();
