import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_width_controller.dart';
import 'package:lotti/features/settings_v2/ui/settings_v2_constants.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Draggable handle that resizes the Settings tree-nav column per
/// spec §3.1.
///
/// Behavior:
/// - Horizontal drag → `SettingsTreeNavWidth.updateBy(delta)` (with
///   clamp + 300 ms-debounced persist).
/// - Double-tap / Home → reset to [defaultSettingsTreeNavWidth].
/// - Focused arrow keys → ±[settingsTreeNavWidthArrowStep]; with
///   Shift → ±[settingsTreeNavWidthShiftArrowStep].
/// - Screen readers get a slider with `onIncrease` / `onDecrease`
///   bound to the same ±8 dp step so the handle is reachable from
///   assistive tech (VoiceOver rotor, TalkBack volume-key gestures).
/// - Mouse cursor over the 6 dp hit target is
///   [SystemMouseCursors.resizeColumn]; hover fades in a 2 dp
///   `interactive.enabled @ 40 %` bar, drag solidifies to 100 %.
class SettingsTreeResizeHandle extends ConsumerStatefulWidget {
  const SettingsTreeResizeHandle({
    this.focusNode,
    super.key,
  });

  /// Optional externally-owned focus node. Tests supply one to drive
  /// keyboard behavior without adding real focus traversal.
  final FocusNode? focusNode;

  @override
  ConsumerState<SettingsTreeResizeHandle> createState() =>
      _SettingsTreeResizeHandleState();
}

class _SettingsTreeResizeHandleState
    extends ConsumerState<SettingsTreeResizeHandle> {
  bool _hovered = false;
  bool _dragging = false;
  FocusNode? _ownedFocusNode;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  @override
  void didUpdateWidget(covariant SettingsTreeResizeHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent started supplying an external focus node, dispose
    // the one we lazily created so it doesn't leak for the lifetime
    // of the widget.
    if (oldWidget.focusNode == null &&
        widget.focusNode != null &&
        _ownedFocusNode != null) {
      _ownedFocusNode!.dispose();
      _ownedFocusNode = null;
    }
  }

  @override
  void dispose() {
    _ownedFocusNode?.dispose();
    super.dispose();
  }

  void _stepBy(double delta) {
    ref.read(settingsTreeNavWidthProvider.notifier).updateBy(delta);
  }

  void _resetToDefault() {
    ref.read(settingsTreeNavWidthProvider.notifier).resetToDefault();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = tokens.colors.interactive.enabled;
    final width = ref.watch(settingsTreeNavWidthProvider);
    final barColor = _dragging
        ? accent
        : _hovered
        ? accent.withValues(
            alpha: SettingsV2Constants.resizeHandleHoverAlpha,
          )
        : Colors.transparent;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final logicalKey = event.logicalKey;
        final shift = HardwareKeyboard.instance.isShiftPressed;
        final step = shift
            ? settingsTreeNavWidthShiftArrowStep
            : settingsTreeNavWidthArrowStep;

        if (logicalKey == LogicalKeyboardKey.arrowLeft) {
          _stepBy(-step);
          return KeyEventResult.handled;
        }
        if (logicalKey == LogicalKeyboardKey.arrowRight) {
          _stepBy(step);
          return KeyEventResult.handled;
        }
        if (logicalKey == LogicalKeyboardKey.home) {
          _resetToDefault();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onDoubleTap: _resetToDefault,
          onHorizontalDragStart: (_) => setState(() => _dragging = true),
          onHorizontalDragUpdate: (details) => _stepBy(details.delta.dx),
          onHorizontalDragEnd: (_) => setState(() => _dragging = false),
          onHorizontalDragCancel: () => setState(() => _dragging = false),
          child: Semantics(
            label: context.messages.settingsV2ResizeHandleLabel,
            slider: true,
            value: '${width.round()}',
            increasedValue:
                '${(width + settingsTreeNavWidthArrowStep).clamp(minSettingsTreeNavWidth, maxSettingsTreeNavWidth).round()}',
            decreasedValue:
                '${(width - settingsTreeNavWidthArrowStep).clamp(minSettingsTreeNavWidth, maxSettingsTreeNavWidth).round()}',
            onIncrease: () => _stepBy(settingsTreeNavWidthArrowStep),
            onDecrease: () => _stepBy(-settingsTreeNavWidthArrowStep),
            child: SizedBox(
              width: SettingsV2Constants.resizeHandleHitWidth,
              child: Center(
                child: AnimatedContainer(
                  duration: SettingsV2Constants.resizeHandleFade,
                  width: SettingsV2Constants.resizeHandleBarWidth,
                  decoration: BoxDecoration(
                    color: barColor,
                    borderRadius: BorderRadius.circular(
                      SettingsV2Constants.resizeHandleBarWidth / 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
