import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lotti/theme.dart';

class Button extends StatelessWidget {
  final String label;
  final Color primaryColor;
  final Color textColor;
  final Function() onPressed;
  final EdgeInsets padding;

  const Button(
    this.label, {
    this.primaryColor = CupertinoColors.activeBlue,
    this.textColor = CupertinoColors.white,
    this.padding = const EdgeInsets.all(4.0),
    required this.onPressed,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          primary: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        onPressed: onPressed,
        child: Text(label, style: buttonLabelStyle),
      ),
    );
  }
}
