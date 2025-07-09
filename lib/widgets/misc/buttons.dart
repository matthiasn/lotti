import 'package:flutter/material.dart';

class RoundedButton extends StatelessWidget {
  const RoundedButton(
    this.label, {
    required this.onPressed,
    super.key,
  });

  final String label;
  final void Function()? onPressed;

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
