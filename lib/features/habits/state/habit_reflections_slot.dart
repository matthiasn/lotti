import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Builds the reflection actions a habit's completion sheet offers, one per
/// goal watching the habit. [day] answers the day being recorded at the
/// moment an action is pressed, since the user can still pick another.
typedef HabitReflectionsBuilder =
    List<Widget> Function(
      WidgetRef ref,
      BuildContext context, {
      required String habitId,
      required DateTime Function() day,
    });

/// The reflection actions, or null to offer none. The composition root wires
/// the goals feature's: goals depend on habits, so habits cannot import them.
final habitReflectionsProvider = Provider<HabitReflectionsBuilder?>(
  (ref) => null,
  name: 'habitReflectionsProvider',
);
