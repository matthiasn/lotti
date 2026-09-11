import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/ui/plaza_palette.dart';
import 'package:material_ui/material_ui.dart';

/// Dev-harness palette and type for the plaza's scene content.
///
/// The plaza is 3D scene content rendered inside the prototype harness, not
/// app chrome; like `knowledge_graph/ui/graph_style.dart` it keeps a local
/// palette instead of design-system tokens. The values come from the design
/// prototype and map onto Lotti's dark semantics (`info`, `error`,
/// `warning`, `interactive` and the teal brand light); if the prototype
/// graduates, this gets rebased onto the token pipeline.
///
/// Scene content only. The HUD that floats *over* the scene is chrome, and
/// its glass is a design-system token — `WorldGlass` in
/// `design_system/theme/world_chrome_tokens.dart`.
abstract final class PlazaStyle {
  /// Facade and billboard panel background.
  static const panel = Color(0xFF0A0E16);

  /// The dark track a ticker band runs in: the fixture behind the type.
  static const housing = Color(0xFF0B0D14);

  /// `--lotti-teal-light`: beacons, focus ring, OPEN, ticker text.
  static const teal = Color(0xFF5ED4B7);
  static const tealHover = Color(0xFF86DFC9);

  static const Color text = Colors.white;
  static const textMed = Color(0x9EFFFFFF);
  static const textDim = Color(0x73FFFFFF);
  static const textFaint = Color(0x8CFFFFFF);

  /// Surface wash on hover; no hue shift, no scale.
  static const hoverWash = Color(0x14FFFFFF);

  static const fontText = 'Inter';
  static const fontMono = 'Inconsolata';

  /// A per-state glyph so state reads without hue: a cross for blocked, a
  /// bang for overdue, a play mark for in progress, a ring for open, a
  /// tick for done.
  static String glyph(TaskAttention a) {
    if (a.task.state == PlazaTaskState.blocked) return '✕';
    if (a.overdue) return '!';
    return switch (a.task.state) {
      PlazaTaskState.inProgress => '▶',
      PlazaTaskState.done => '✓',
      PlazaTaskState.cancelled => '—',
      PlazaTaskState.open || PlazaTaskState.blocked => '○',
    };
  }

  /// Chip fill and ink per state. Overdue overrides the state (an overdue
  /// open task reads OVERDUE), matching the design prototype.
  static ({Color fill, Color ink}) chip(TaskAttention a) {
    if (a.task.state == PlazaTaskState.blocked) {
      return (
        fill: const Color(0xFFD65E5C),
        ink: const Color(0xFF14060A),
      );
    }
    if (a.overdue) {
      return (
        fill: const Color(0xFFFBA336),
        ink: const Color(0xFF1C1206),
      );
    }
    return switch (a.task.state) {
      PlazaTaskState.inProgress => (
        fill: const Color(0xFF4AB6E8),
        ink: const Color(0xFF06141C),
      ),
      PlazaTaskState.done => (
        fill: dsTokensDark.colors.alert.success.defaultColor,
        ink: dsTokensDark.colors.text.onInteractiveAlert,
      ),
      PlazaTaskState.cancelled => (
        fill: const Color(0x29FFFFFF),
        ink: const Color(0xCCFFFFFF),
      ),
      PlazaTaskState.open || PlazaTaskState.blocked => (
        fill: const Color(0xFFD7D7D7),
        ink: const Color(0xFF1A1A1A),
      ),
    };
  }

  /// The roof lantern colour; also the billboard frame and light pool.
  ///
  /// Signage keeps the night register in both skies — a sign is a sign at
  /// noon — so this and everything derived from it read the night palette
  /// by name. Scene geometry asks its own [PlazaPalette] instead.
  static Color lantern(LanternState state) =>
      PlazaPalette.night.lanterns.of(state);

  /// The progress light bar along the facade base.
  static Color taskColor(TaskAttention a) => PlazaPalette.night.taskColor(a);

  static Color lightBar(TaskAttention a) => taskColor(a);

  /// The neon version of a category colour: saturated and bright, for edge
  /// strips and banners. Greys stay grey (a neutral category is not
  /// invented into a hue).
  static Color neon(Color color) {
    final hsl = HSLColor.fromColor(color);
    if (hsl.saturation < 0.15) return color;
    return hsl
        .withSaturation((hsl.saturation + 0.35).clamp(0.0, 1.0))
        .withLightness(0.62)
        .toColor();
  }

  /// Beacon colour by kind: navigation stops are teal, home is white, an
  /// attention beacon takes its task's state colour — in [palette]'s
  /// register, so a daylight beacon is not a night lantern on a bright sky.
  static Color beaconColor(
    Beacon beacon,
    PlazaWorld world, {
    PlazaPalette palette = PlazaPalette.night,
  }) {
    switch (beacon.kind) {
      case BeaconKind.home:
        return const Color(0xFFF2FFFA);
      case BeaconKind.attention:
        final attention = world.attention[beacon.taskId];
        return attention == null
            ? teal
            : palette.lanterns.of(attention.lantern);
      case BeaconKind.block:
      case BeaconKind.corner:
        return teal;
    }
  }

  /// Warm sodium-vapour lamp light.
  static const lamp = Color(0xFFFFD08A);

  /// Aircraft warning light on the spires.
  static const warning = Color(0xFFFF3B30);

  /// The bright bar on the facade, in the task's own category colour.
  static Color categoryBright(PlazaTask task) => Color(task.categoryColor);
}
