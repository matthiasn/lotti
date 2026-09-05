import 'package:flutter/material.dart' as legacy;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// Flutter's tooltip finder does not recognize a modern Tooltip that excludes
/// semantics. Match both design libraries while retaining RawTooltip support.
Finder findMaterialTooltip(Pattern message, {bool skipOffstage = true}) {
  bool matches(String value) =>
      message is RegExp ? message.hasMatch(value) : value == message;

  return find.byWidgetPredicate((widget) {
    if (widget is Tooltip) {
      final value = widget.message ?? widget.richMessage?.toPlainText() ?? '';
      if ((widget.excludeFromSemantics ?? false) || value.isEmpty) {
        return matches(value);
      }
    }
    if (widget is legacy.Tooltip) {
      final value = widget.message ?? widget.richMessage?.toPlainText() ?? '';
      if ((widget.excludeFromSemantics ?? false) || value.isEmpty) {
        return matches(value);
      }
    }
    return widget is RawTooltip && matches(widget.semanticsTooltip ?? '');
  }, skipOffstage: skipOffstage);
}
