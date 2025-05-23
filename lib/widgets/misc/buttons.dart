import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

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
