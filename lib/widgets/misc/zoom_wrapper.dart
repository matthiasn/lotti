import 'package:flutter/material.dart';

/// Applies a [TextScaler] to the subtree based on the given [scale].
///
/// When [scale] equals 1.0 the child is returned unchanged.
class ZoomWrapper extends StatelessWidget {
  const ZoomWrapper({
    required this.scale,
    required this.child,
    super.key,
  });

  final double scale;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (scale == 1.0) return child;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(scale),
      ),
      child: child,
    );
  }
}
