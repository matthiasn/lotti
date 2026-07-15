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

    test('global bindings are conflict-free on every desktop platform', () {
      final globalIds = AppCommandCatalog.definitions
          .where(
            (item) =>
                item.context == AppCommandContext.global ||
                item.context == AppCommandContext.navigation,
          )
          .map((item) => item.id);

      for (final platform in const [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        expect(
          AppCommandCatalog.conflictsFor(
            platform: platform,
            commandIds: globalIds,
          ),
          isEmpty,
          reason:
              '$platform must not dispatch one chord to two global commands',
        );
      }
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

    test('delete remains destructive and palette-visible only in context', () {
      final definition = AppCommandCatalog.definition(AppCommandId.delete);

      expect(definition.destructive, isTrue);
      expect(
        definition.paletteVisibility,
        AppCommandPaletteVisibility.activeContext,
      );
    });
  });
}
