import 'package:flutter/widgets.dart';

@immutable
class ModalSheetAction<T> {
  const ModalSheetAction({
    required this.label,
    this.key,
    this.icon,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
    this.style,
  });

  final String label;

  /// Only works for Material Style
  final IconData? icon;

  /// Used for checking selection result
  final T? key;

  /// Make font weight to bold(Only works for CupertinoStyle).
  final bool isDefaultAction;

  /// Make font color to destructive/error color(red).
  final bool isDestructiveAction;

  /// Custom text style for the action
  final TextStyle? style;
}
