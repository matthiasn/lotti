import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet_state.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Footer-bar button slot widths from the Figma "Apply filter" footer
/// frame. Treated as minimums so long localized labels can grow past
/// the spec — the visual match holds for English / German / French.
/// Slot height is shared with the button itself via
/// `DesignSystemFilterMetrics.actionMinHeight` so the painted pill,
/// hit area, and slot all agree.
const double _kClearButtonMinWidth = 115;
const double _kSaveButtonMinWidth = 115;
const double _kApplyButtonMinWidth = 159;
const double _kFooterButtonMinHeight =
    DesignSystemFilterMetrics.actionMinHeight;

/// Backdrop blur strength for the glass footer. Sits at the top of the
/// codebase's existing glass-surface range (10–20) since this surface is
/// wider and farther from the content than card-sized blurs.
const double _kFooterBlurSigma = 20;

/// Sticky action bar for the filter sheet — Clear All + Apply buttons.
///
/// Designed to be used as the `stickyActionBar` in a Wolt modal page.
class DesignSystemTaskFilterActionBar extends StatefulWidget {
  const DesignSystemTaskFilterActionBar({
    required this.state,
    required this.onChanged,
    this.onApplyPressed,
    this.onClearAllPressed,
    this.onSavePressed,
    this.canSave = false,
    this.initialSaveName,
    super.key,
  });

  final DesignSystemTaskFilterState state;
  final ValueChanged<DesignSystemTaskFilterState> onChanged;
  final ValueChanged<DesignSystemTaskFilterState>? onApplyPressed;
  final ValueChanged<DesignSystemTaskFilterState>? onClearAllPressed;

  /// When supplied, a Save affordance is rendered between Clear All and
  /// Apply. Tapping it opens an inline name popup; the trimmed name is
  /// passed to this callback when the user commits.
  final ValueChanged<String>? onSavePressed;

  /// Whether the Save affordance is currently enabled.
  final bool canSave;

  /// Optional initial value for the Save name popup — typically the name
  /// of the currently active saved filter, when the user is editing it.
  final String? initialSaveName;

  /// Stable test key for the Save action button.
  @visibleForTesting
  static const Key saveButtonKey = ValueKey(
    'design-system-task-filter-save',
  );

  /// Stable test key for the Save name popup card.
  @visibleForTesting
  static const Key saveNamePopupKey = ValueKey(
    'design-system-task-filter-save-popup',
  );

  /// Stable test key for the Save name popup text field.
  @visibleForTesting
  static const Key saveNamePopupFieldKey = ValueKey(
    'design-system-task-filter-save-popup-field',
  );

  /// Stable test key for the popup commit button.
  @visibleForTesting
  static const Key saveNamePopupCommitKey = ValueKey(
    'design-system-task-filter-save-popup-commit',
  );

  @override
  State<DesignSystemTaskFilterActionBar> createState() =>
      _DesignSystemTaskFilterActionBarState();
}

class _DesignSystemTaskFilterActionBarState
    extends State<DesignSystemTaskFilterActionBar> {
  final MenuController _saveMenu = MenuController();

  void _openSavePopup() {
    if (!widget.canSave) return;
    if (_saveMenu.isOpen) {
      _saveMenu.close();
    } else {
      _saveMenu.open();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final palette = DesignSystemFilterPalette.fromTokens(tokens);
    final spacing = tokens.spacing;
    final messages = context.messages;
    final showSaveButton = widget.onSavePressed != null;

    // Figma "Apply filter" footer (node 3341:53641): hairline divider,
    // backdrop blur, top→bottom white gradient overlay; right-aligned
    // buttons with minimum slot widths from the frame (Clear all 115×56,
    // Save 115×56, Apply filter 159×56) but allowed to grow for long
    // localized labels. Padding/spacing come from spacing tokens.

    // Slot widths (Figma min) used when the row has room. On narrow
    // viewports — modal width < demand — the LayoutBuilder below drops
    // these to 0 so buttons shrink to their natural size instead of
    // overflowing.
    final slots = <({double minWidth, Widget child})>[
      (
        minWidth: _kClearButtonMinWidth,
        child: DesignSystemFilterActionButton(
          key: const ValueKey('design-system-task-filter-clear'),
          label: widget.state.clearAllLabel,
          palette: palette,
          highlighted: false,
          textStyle: tokens.typography.styles.subtitle.subtitle1,
          onTap: () {
            final clearedState = widget.state.clearAll();
            widget.onChanged(clearedState);
            widget.onClearAllPressed?.call(clearedState);
          },
        ),
      ),
      if (showSaveButton)
        (
          minWidth: _kSaveButtonMinWidth,
          child: MenuAnchor(
            controller: _saveMenu,
            alignmentOffset: const Offset(0, -8),
            menuChildren: [
              _SaveNamePopup(
                key: DesignSystemTaskFilterActionBar.saveNamePopupKey,
                initialValue: widget.initialSaveName ?? '',
                activeFilterCount: widget.state.appliedCount,
                tokens: tokens,
                messages: messages,
                onCancel: _saveMenu.close,
                onCommit: (name) {
                  _saveMenu.close();
                  widget.onSavePressed?.call(name);
                },
              ),
            ],
            builder: (ctx, controller, child) {
              return DesignSystemFilterActionButton(
                key: DesignSystemTaskFilterActionBar.saveButtonKey,
                label: messages.tasksSavedFiltersSaveButtonLabel,
                palette: palette,
                highlighted: false,
                textStyle: tokens.typography.styles.subtitle.subtitle1,
                onTap: _openSavePopup,
              );
            },
          ),
        ),
      (
        minWidth: _kApplyButtonMinWidth,
        child: DesignSystemFilterActionButton(
          key: const ValueKey('design-system-task-filter-apply'),
          label: widget.state.applyLabel,
          palette: palette,
          highlighted: true,
          counter: widget.state.appliedCount,
          textStyle: tokens.typography.styles.subtitle.subtitle1,
          onTap: () => widget.onApplyPressed?.call(widget.state),
        ),
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top-edge hairline divider (decorative/01 @ 12% alpha).
        Container(
          height: 1,
          color: tokens.colors.decorative.level01.withValues(alpha: 0.12),
        ),
        ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(
              sigmaX: _kFooterBlurSigma,
              sigmaY: _kFooterBlurSigma,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    palette.glassFooterOverlayStart,
                    palette.glassFooterOverlayEnd,
                  ],
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.step6, // 24
                  spacing.step5, // 16
                  spacing.step6, // 24
                  spacing.step6, // 24
                ),
                // LayoutBuilder so the slot minimums (Figma's 115/115/159)
                // are honored when the row has room, but dropped to 0
                // when the modal is narrower than the demand. Keeps the
                // footer at one row on every viewport without overflow.
                child: LayoutBuilder(
                  builder: (ctx, constraints) {
                    final demand =
                        slots.fold<double>(
                          0,
                          (sum, s) => sum + s.minWidth,
                        ) +
                        spacing.step4 * (slots.length - 1);
                    final fits = constraints.maxWidth >= demand;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (var i = 0; i < slots.length; i++) ...[
                          if (i > 0) SizedBox(width: spacing.step4), // 12
                          _FooterButtonSlot(
                            minWidth: fits ? slots[i].minWidth : 0,
                            child: slots[i].child,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Wraps a footer-bar button in the slot's minimum width / height so the
/// row of buttons matches the Figma frame. The button itself can grow if
/// its label is wider than the minimum — keeps long localized labels
/// from clipping.
class _FooterButtonSlot extends StatelessWidget {
  const _FooterButtonSlot({
    required this.minWidth,
    required this.child,
  });

  final double minWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: minWidth,
        minHeight: _kFooterButtonMinHeight,
      ),
      child: child,
    );
  }
}

class _SaveNamePopup extends StatefulWidget {
  const _SaveNamePopup({
    required this.initialValue,
    required this.activeFilterCount,
    required this.tokens,
    required this.messages,
    required this.onCancel,
    required this.onCommit,
    super.key,
  });

  final String initialValue;
  final int activeFilterCount;
  final DsTokens tokens;
  final AppLocalizations messages;
  final VoidCallback onCancel;
  final ValueChanged<String> onCommit;

  @override
  State<_SaveNamePopup> createState() => _SaveNamePopupState();
}

class _SaveNamePopupState extends State<_SaveNamePopup> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );
  final FocusNode _focusNode = FocusNode();
  late bool _canCommit = _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleTextChanged)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    final next = _controller.text.trim().isNotEmpty;
    if (next != _canCommit) {
      setState(() => _canCommit = next);
    }
  }

  void _commit() {
    if (!_canCommit) return;
    widget.onCommit(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final messages = widget.messages;
    return Container(
      width: 270,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.colors.decorative.level01),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            messages.tasksSavedFiltersSavePopupTitle,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Focus(
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                widget.onCancel();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: TextField(
              key: DesignSystemTaskFilterActionBar.saveNamePopupFieldKey,
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _commit(),
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: messages.tasksSavedFiltersSavePopupHint,
                hintStyle: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: tokens.colors.interactive.enabled,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: tokens.colors.interactive.enabled,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            messages.tasksSavedFiltersSavePopupHelper(
              widget.activeFilterCount,
            ),
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.colors.text.mediumEmphasis,
                    side: BorderSide(
                      color: tokens.colors.decorative.level01,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(messages.tasksSavedFiltersSavePopupCancel),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: FilledButton(
                  key: DesignSystemTaskFilterActionBar.saveNamePopupCommitKey,
                  onPressed: _canCommit ? _commit : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.colors.interactive.enabled,
                    foregroundColor: tokens.colors.text.onInteractiveAlert,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: Text(messages.tasksSavedFiltersSavePopupSave),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
