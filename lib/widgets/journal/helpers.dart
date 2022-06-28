import 'package:flutter/material.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme/theme.dart';

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
        style: TextStyle(
          fontFamily: 'ShareTechMono',
          color: getIt<ThemeService>().colors.entryTextColor,
          fontWeight: FontWeight.w300,
          fontSize: 14,
        ),
      ),
    );
  }
}
