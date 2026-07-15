import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// Formats catalog bindings using the active locale and desktop conventions.
abstract final class ShortcutLabelFormatter {
  static String bindings(
    AppLocalizations messages,
    Iterable<AppShortcutBinding> bindings, {
    required TargetPlatform platform,
  }) {
    return bindings
        .map((binding) => binding.resolve(platform))
        .whereType<ShortcutActivator>()
        .map((activator) => activatorLabel(messages, activator, platform))
        .join(' ${messages.keyboardKeyOr} ');
  }

  static String activatorLabel(
    AppLocalizations messages,
    ShortcutActivator activator,
    TargetPlatform platform,
  ) {
    final modifiers = <String>[];
    LogicalKeyboardKey? trigger;
    String? character;

    switch (activator) {
      case final SingleActivator single:
        if (single.control) modifiers.add(_control(messages, platform));
        if (single.alt) modifiers.add(_alt(messages, platform));
        if (single.shift) modifiers.add(_shift(messages, platform));
        if (single.meta) modifiers.add(_meta(platform));
        trigger = single.trigger;
      case final CharacterActivator characterActivator:
        if (characterActivator.control) {
          modifiers.add(_control(messages, platform));
        }
        if (characterActivator.alt) modifiers.add(_alt(messages, platform));
        if (characterActivator.meta) modifiers.add(_meta(platform));
        character = characterActivator.character;
      case _:
        return activator.toString();
    }

    final key = character ?? _key(messages, trigger!);
    if (platform == TargetPlatform.macOS) {
      return '${modifiers.join()}$key';
    }
    return [...modifiers, key].join('+');
  }

  static String _control(AppLocalizations messages, TargetPlatform platform) =>
      platform == TargetPlatform.macOS ? '⌃' : messages.keyboardKeyControl;

  static String _alt(AppLocalizations messages, TargetPlatform platform) =>
      platform == TargetPlatform.macOS ? '⌥' : messages.keyboardKeyAlt;

  static String _shift(AppLocalizations messages, TargetPlatform platform) =>
      platform == TargetPlatform.macOS ? '⇧' : messages.keyboardKeyShift;

  static String _meta(TargetPlatform platform) =>
      platform == TargetPlatform.macOS ? '⌘' : 'Meta';

  static String _key(AppLocalizations messages, LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.enter) return messages.keyboardKeyEnter;
    if (key == LogicalKeyboardKey.space) return messages.keyboardKeySpace;
    if (key == LogicalKeyboardKey.escape) return messages.keyboardKeyEscape;
    if (key == LogicalKeyboardKey.delete) return messages.keyboardKeyDelete;
    if (key == LogicalKeyboardKey.home) return messages.keyboardKeyHome;
    if (key == LogicalKeyboardKey.end) return messages.keyboardKeyEnd;
    if (key == LogicalKeyboardKey.pageUp) return messages.keyboardKeyPageUp;
    if (key == LogicalKeyboardKey.pageDown) return messages.keyboardKeyPageDown;
    if (key == LogicalKeyboardKey.arrowUp) return messages.keyboardKeyArrowUp;
    if (key == LogicalKeyboardKey.arrowDown) {
      return messages.keyboardKeyArrowDown;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      return messages.keyboardKeyArrowLeft;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return messages.keyboardKeyArrowRight;
    }
    if (key == LogicalKeyboardKey.numpadAdd) return messages.keyboardKeyPlus;
    if (key == LogicalKeyboardKey.numpadSubtract) {
      return messages.keyboardKeyMinus;
    }
    return key.keyLabel.toUpperCase();
  }
}
