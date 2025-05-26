import 'package:flutter/material.dart';

class StatusIndicator extends StatelessWidget {
  const StatusIndicator(
    this.statusColor, {
    required this.semanticsLabel,
    super.key,
  });

  final Color statusColor;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      child: Container(
        height: 30,
        width: 30,
        decoration: BoxDecoration(
          color: statusColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: statusColor,
              blurRadius: 5,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
