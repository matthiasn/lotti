import 'package:flutter/widgets.dart';

@immutable
class ModalSheetAction<T> {
  const ModalSheetAction({
    required this.label,
    this.key,
    this.icon,
    this.isDestructiveAction = false,
  });

  final String label;

  /// Only works for Material Style
  final IconData? icon;

  /// Used for checking selection result
  final T? key;

  /// Make font color to destructive/error color(red).
  final bool isDestructiveAction;
}
