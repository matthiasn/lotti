import 'package:flutter/material.dart';
import 'package:lotti/widgets/lotti_primary_button.dart';

class RoundedFilledButton extends StatelessWidget {
  const RoundedFilledButton({
    required this.onPressed,
    required this.labelText,
    this.backgroundColor = Colors.greenAccent,
    this.foregroundColor = Colors.black87,
    this.semanticsLabel,
    super.key,
  });

  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onPressed;
  final String labelText;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return LottiPrimaryButton(
      onPressed: onPressed,
      label: labelText,
      semanticsLabel: semanticsLabel,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
