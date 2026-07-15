import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/keyboard/domain/app_shortcut_binding.dart';

void main() {
  group('AppShortcutBinding', () {
    test('primary key resolves Command on macOS and Control elsewhere', () {
      const binding = AppShortcutBinding.primaryKey(LogicalKeyboardKey.keyK);

      final mac = binding.resolve(TargetPlatform.macOS)! as SingleActivator;
      final windows =
          binding.resolve(TargetPlatform.windows)! as SingleActivator;
      final linux = binding.resolve(TargetPlatform.linux)! as SingleActivator;

      expect(
        (mac.meta, mac.control, mac.trigger),
        (true, false, LogicalKeyboardKey.keyK),
      );
      expect(
        (windows.meta, windows.control, windows.trigger),
        (false, true, LogicalKeyboardKey.keyK),
      );
      expect(
        (linux.meta, linux.control, linux.trigger),
        (false, true, LogicalKeyboardKey.keyK),
      );
    });

    test('primary character remains layout-aware and accepts Shift', () {
      const binding = AppShortcutBinding.primaryCharacter('?');

      final mac = binding.resolve(TargetPlatform.macOS)! as CharacterActivator;
      final windows =
          binding.resolve(TargetPlatform.windows)! as CharacterActivator;

      expect((mac.character, mac.meta, mac.control), ('?', true, false));
      expect(
        (windows.character, windows.meta, windows.control),
        ('?', false, true),
      );
    });

    test('does not expose desktop shortcuts on mobile targets', () {
      const binding = AppShortcutBinding.allKey(LogicalKeyboardKey.f1);

      expect(binding.resolve(TargetPlatform.android), isNull);
      expect(binding.resolve(TargetPlatform.iOS), isNull);
      expect(binding.resolve(TargetPlatform.fuchsia), isNull);
    });
  });
}
