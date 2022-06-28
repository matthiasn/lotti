import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fadein/flutter_fadein.dart';
import 'package:lotti/theme/theme.dart';

class Button extends StatelessWidget {
  const Button(
    this.label, {
    this.primaryColor = CupertinoColors.activeBlue,
    this.textColor = CupertinoColors.white,
    this.padding = const EdgeInsets.all(4),
    required this.onPressed,
    super.key,
  });

  final String label;
  final Color primaryColor;
  final Color textColor;
  final void Function() onPressed;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(16),
          primary: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed,
        child: Text(label, style: buttonLabelStyle),
      ),
    );
  }
}

class FadeInButton extends StatelessWidget {
  const FadeInButton(
    this.label, {
    this.primaryColor = CupertinoColors.activeBlue,
    this.textColor = CupertinoColors.white,
    this.padding = const EdgeInsets.all(4),
    this.duration = const Duration(seconds: 2),
    required this.onPressed,
    super.key,
  });

  final String label;
  final Color primaryColor;
  final Color textColor;
  final void Function() onPressed;
  final EdgeInsets padding;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return FadeIn(
      duration: const Duration(seconds: 2),
      child: Button(
        label,
        onPressed: onPressed,
        primaryColor: primaryColor,
        textColor: textColor,
        padding: padding,
      ),
    );
  }
}
