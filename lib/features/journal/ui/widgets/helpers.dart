import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

class EntryTextWidget extends StatelessWidget {
  const EntryTextWidget(
    this.text, {
    super.key,
    this.maxLines = 5,
    this.padding = const EdgeInsets.symmetric(vertical: 8),
  });

  final String text;
  final int maxLines;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        text,
        maxLines: maxLines,
        softWrap: true,
        style: monoTabularStyle(
          fontSize: fontSizeMedium,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}
