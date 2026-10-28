import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/keyboard/domain/app_command.dart';
import 'package:lotti/features/keyboard/domain/app_command_catalog.dart';

void main() {
  group('AppCommandCatalog', () {
    test('contains exactly one definition for every command id', () {
      final ids = AppCommandCatalog.definitions.map((item) => item.id).toList();

      expect(ids.toSet(), AppCommandId.values.toSet());
      expect(ids, hasLength(AppCommandId.values.length));
    });

    test('navigation digits have a stable semantic mapping', () {
      final expected = <(LogicalKeyboardKey, AppCommandId)>[
        (LogicalKeyboardKey.digit1, AppCommandId.navigateTasks),
        (LogicalKeyboardKey.digit2, AppCommandId.navigateDailyOs),
        (LogicalKeyboardKey.digit3, AppCommandId.navigateProjects),
        (LogicalKeyboardKey.digit4, AppCommandId.navigateHabits),
        (LogicalKeyboardKey.digit5, AppCommandId.navigateDashboards),
        (LogicalKeyboardKey.digit6, AppCommandId.navigateJournal),
        (LogicalKeyboardKey.digit7, AppCommandId.navigateEvents),
        (LogicalKeyboardKey.digit8, AppCommandId.navigateSettings),
      ];

      final bindings = AppCommandCatalog.bindingsFor(
        platform: TargetPlatform.windows,
      );

      for (final (key, command) in expected) {
        final matching = bindings.entries.where((entry) {
          final activator = entry.key;
          return activator is SingleActivator &&
              activator.trigger == key &&
              activator.control &&
              !activator.meta;
        });
        expect(
          matching.single.value,
          command,
        );
      }
    });

    test('history is Cmd+Y on macOS and Ctrl+H elsewhere', () {
      AppCommandId? commandFor(
        TargetPlatform platform,
        LogicalKeyboardKey key, {
        required bool meta,
      }) {
        final bindings = AppCommandCatalog.bindingsFor(platform: platform);
        for (final MapEntry(key: activator, :value) in bindings.entries) {
          if (activator is SingleActivator &&
              activator.trigger == key &&
              activator.meta == meta &&
              activator.control == !meta &&
              !activator.shift &&
              !activator.alt) {
            return value;
          }
        }
        return null;
      }

      expect(
        commandFor(TargetPlatform.macOS, LogicalKeyboardKey.keyY, meta: true),
        AppCommandId.openHistory,
      );
      // Cmd+H stays the system's Hide.
      expect(
        commandFor(TargetPlatform.macOS, LogicalKeyboardKey.keyH, meta: true),
        isNull,
      );
      for (final platform in [TargetPlatform.linux, TargetPlatform.windows]) {
        expect(
          commandFor(platform, LogicalKeyboardKey.keyH, meta: false),
          AppCommandId.openHistory,
        );
        expect(
          commandFor(platform, LogicalKeyboardKey.keyY, meta: false),
          isNull,
        );
      }
    });

    test('no two commands share an activator on any desktop platform', () {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        final seen = <ShortcutActivator>[];
        for (final definition in AppCommandCatalog.definitions) {
          for (final binding in definition.bindings) {
            final activator = binding.resolve(platform);
            if (activator == null) continue;
            final clash = seen.where(
              (other) => other.toString() == activator.toString(),
            );
            expect(
              clash,
              isEmpty,
              reason: '${definition.id} on $platform reuses $activator',
            );
            seen.add(activator);
          }
        }
      }
    });

    test('only continuous commands opt into repeats', () {
      expect(
        AppCommandCatalog.definition(AppCommandId.createTask).allowRepeat,
        isFalse,
      );
      expect(
        AppCommandCatalog.definition(AppCommandId.save).allowRepeat,
        isFalse,
      );
      expect(
        AppCommandCatalog.definition(AppCommandId.zoomIn).allowRepeat,
        isTrue,
      );
      expect(
        AppCommandCatalog.definition(AppCommandId.moveDown).allowRepeat,
        isTrue,
      );
    });

    test('delete remains palette-visible only in context', () {
      final definition = AppCommandCatalog.definition(AppCommandId.delete);

      expect(
        definition.paletteVisibility,
        AppCommandPaletteVisibility.activeContext,
      );
    });
  });
}
