import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';

class TextSegment extends StatelessWidget {
  const TextSegment(this.text, {this.semanticsLabel, super.key});

  final String text;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(
        text,
        style: segmentItemStyle,
        semanticsLabel: semanticsLabel,
      ),
    );
  }
}
