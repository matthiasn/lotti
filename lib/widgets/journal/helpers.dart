import 'package:flutter/material.dart';
import 'package:lotti/theme.dart';

class EntryTextWidget extends StatelessWidget {
  final String text;
  final int maxLines;
  final EdgeInsets padding;
  const EntryTextWidget(
    this.text, {
    Key? key,
    this.maxLines = 5,
    this.padding = const EdgeInsets.symmetric(vertical: 8.0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(text,
          maxLines: maxLines,
          style: TextStyle(
            fontFamily: 'ShareTechMono',
            color: AppColors.entryTextColor,
            fontWeight: FontWeight.w300,
            fontSize: 14.0,
          )),
    );
  }
}
