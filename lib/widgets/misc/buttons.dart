import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_fadein/flutter_fadein.dart';

class Button extends StatelessWidget {
  const Button(
    this.label, {
    required this.onPressed,
    this.primaryColor = CupertinoColors.activeBlue,
    this.textColor = CupertinoColors.white,
    this.padding = const EdgeInsets.all(4),
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
          backgroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

class RoundedButton extends StatelessWidget {
  const RoundedButton(
    this.label, {
    required this.onPressed,
    this.primaryColor = CupertinoColors.activeBlue,
    this.textColor = CupertinoColors.white,
    this.padding = const EdgeInsets.all(4),
    super.key,
  });

  final String label;
  final Color primaryColor;
  final Color textColor;
  final void Function()? onPressed;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        side: const BorderSide(),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 20,
        ),
      ),
      child: Text(label),
    );
  }
}

class FadeInButton extends StatelessWidget {
  const FadeInButton(
    this.label, {
    required this.onPressed,
    this.primaryColor = CupertinoColors.activeBlue,
    this.textColor = CupertinoColors.white,
    this.padding = const EdgeInsets.all(4),
    this.duration = const Duration(seconds: 2),
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
