import 'package:flutter/material.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';

/// Dev-harness palette and type for the plaza's scene content.
///
/// The plaza is 3D scene content rendered inside the prototype harness, not
/// app chrome; like `knowledge_graph/ui/graph_style.dart` it keeps a local
/// palette instead of design-system tokens. The values come from the design
/// prototype and map onto Lotti's dark semantics (`info`, `error`,
/// `warning`, `interactive` and the teal brand light); if the prototype
/// graduates, this gets rebased onto the token pipeline.
abstract final class PlazaStyle {
  /// Facade and billboard panel background.
  static const panel = Color(0xFF0A0E16);

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
  static ({Color fill, Color ink, String label}) chip(TaskAttention a) {
    if (a.task.state == PlazaTaskState.blocked) {
      return (
        fill: const Color(0xFFD65E5C),
        ink: const Color(0xFF14060A),
        label: 'BLOCKED',
      );
    }
    if (a.overdue) {
      return (
        fill: const Color(0xFFFBA336),
        ink: const Color(0xFF1C1206),
        label: 'OVERDUE',
      );
    }
    return switch (a.task.state) {
      PlazaTaskState.inProgress => (
        fill: const Color(0xFF4AB6E8),
        ink: const Color(0xFF06141C),
        label: 'IN PROGRESS',
      ),
      PlazaTaskState.done => (
        fill: const Color(0x29FFFFFF),
        ink: const Color(0xCCFFFFFF),
        label: 'DONE',
      ),
      PlazaTaskState.cancelled => (
        fill: const Color(0x29FFFFFF),
        ink: const Color(0xCCFFFFFF),
        label: 'CANCELLED',
      ),
      PlazaTaskState.open || PlazaTaskState.blocked => (
        fill: const Color(0xFFD7D7D7),
        ink: const Color(0xFF1A1A1A),
        label: 'OPEN',
      ),
    };
  }

  /// The roof lantern colour; also the billboard frame and light pool.
  static Color lantern(LanternState state) => switch (state) {
    LanternState.blocked => const Color(0xFFE4655F),
    LanternState.overdue => const Color(0xFFFBA336),
    LanternState.inProgress => const Color(0xFF4AB6E8),
    LanternState.open => const Color(0xFFD0C2A0),
    LanternState.off => const Color(0xFF3A3F48),
  };

  /// The progress light bar along the facade base.
  static Color lightBar(TaskAttention a) => a.lantern == LanternState.off
      ? const Color(0xFF7AB889)
      : lantern(a.lantern);

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
  /// attention beacon takes its task's state colour.
  static Color beaconColor(Beacon beacon, PlazaWorld world) {
    switch (beacon.kind) {
      case BeaconKind.home:
        return const Color(0xFFF2FFFA);
      case BeaconKind.attention:
        final attention = world.attention[beacon.taskId];
        return attention == null ? teal : lantern(attention.lantern);
      case BeaconKind.block:
      case BeaconKind.corner:
        return teal;
    }
  }

  /// Warm sodium-vapour lamp light.
  static const lamp = Color(0xFFFFD08A);

  /// Aircraft warning light on the spires.
  static const warning = Color(0xFFFF3B30);

  /// Category colours: the bright bar on the facade, the dim wall tint, the
  /// darker roof tint. Derived from the task's category colour so the demo
  /// world's categories tint their own blocks.
  static Color categoryBright(PlazaTask task) => Color(task.categoryColor);
  static Color categoryWall(PlazaTask task) =>
      Color.lerp(const Color(0xFF3B3F4A), Color(task.categoryColor), 0.28)!;
  static Color categoryRoof(PlazaTask task) =>
      Color.lerp(const Color(0xFF262A33), Color(task.categoryColor), 0.22)!;
}
