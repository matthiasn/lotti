import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Finds a [RichText] widget whose plain text contains [text].
Finder findRichTextContaining(String text) => find.byWidgetPredicate(
  (widget) => widget is RichText && widget.text.toPlainText().contains(text),
);
