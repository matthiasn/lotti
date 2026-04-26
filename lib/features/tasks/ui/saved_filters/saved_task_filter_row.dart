import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';

/// Stable test keys for the saved-filter row internals.
@visibleForTesting
class SavedTaskFilterRowKeys {
  const SavedTaskFilterRowKeys._();

  static Key root(String id) => Key('saved-filter-row-$id');
  static Key deleteButton(String id) => Key('saved-filter-delete-$id');
  static Key renameField(String id) => Key('saved-filter-rename-$id');
  static Key dragHandle(String id) => Key('saved-filter-drag-$id');
}

/// A single saved-filter entry rendered inside the Tasks treeview.
///
/// The row owns its hover, edit, and confirm-delete state internally; mutation
/// happens through the supplied callbacks so the parent stays free of UI
/// state.
///
/// Behaviors:
/// - Active state shows a teal accent bar at the inner left edge plus a tinted
///   surface background.
/// - Hover replaces the count (when present) with a delete affordance and
///   reveals a drag-handle glyph at the row's leading edge.
/// - Double-click enters inline rename mode; Enter commits, Escape reverts.
/// - Delete is a two-tap confirm: the first click arms the action (red fill,
///   white icon), the second commits it.
class SavedTaskFilterRow extends StatefulWidget {
  const SavedTaskFilterRow({
    required this.view,
    required this.active,
    required this.onActivate,
    required this.onRename,
    required this.onDelete,
    this.count,
    this.dragHandle,
    super.key,
  });

  final SavedTaskFilter view;
  final bool active;

  /// Live match count to display on the trailing edge. When null the count is
  /// hidden — the row reserves no space for it.
  final int? count;

  /// Called when the user taps the row body (anywhere outside the trash and
  /// drag handle).
  final VoidCallback onActivate;

  /// Called when the user commits a renamed value. The handler receives the
  /// trimmed string; empty / whitespace-only values are filtered out before
  /// invocation.
  final ValueChanged<String> onRename;

  /// Called on the second click of the two-tap delete confirm.
  final VoidCallback onDelete;

  /// Optional drag affordance widget supplied by the enclosing reorderable
  /// list. Shown only on hover (or when [active]); positioned at the row's
  /// leading edge.
  final Widget? dragHandle;

  @override
  State<SavedTaskFilterRow> createState() => _SavedTaskFilterRowState();
}

class _SavedTaskFilterRowState extends State<SavedTaskFilterRow> {
  bool _hover = false;
  bool _editing = false;
  bool _confirmDelete = false;

  late final TextEditingController _nameController = TextEditingController(
    text: widget.view.name,
  );
  final FocusNode _nameFocus = FocusNode();

  @override
  void didUpdateWidget(covariant SavedTaskFilterRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.view.name != widget.view.name && !_editing) {
      _nameController.text = widget.view.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _setHover(bool value) {
    if (_hover == value) return;
    setState(() {
      _hover = value;
      if (!value) _confirmDelete = false;
    });
  }

  void _enterEditMode() {
    setState(() {
      _editing = true;
      _nameController
        ..text = widget.view.name
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.view.name.length,
        );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _nameFocus.requestFocus();
    });
  }

  void _commitRename() {
    final trimmed = _nameController.text.trim();
    setState(() => _editing = false);
    if (trimmed.isEmpty || trimmed == widget.view.name) {
      _nameController.text = widget.view.name;
      return;
    }
    widget.onRename(trimmed);
  }

  void _cancelRename() {
    setState(() {
      _editing = false;
      _nameController.text = widget.view.name;
    });
  }

  void _handleDeleteTap() {
    if (_confirmDelete) {
      widget.onDelete();
      return;
    }
    setState(() => _confirmDelete = true);
  }

  /// Resolves the color stored on the `CategoryDefinition` keyed by [id], or
  /// `null` when the category has been deleted or carries no color string.
  Color? _categoryColor(String id) {
    final hex = getIt<EntitiesCacheService>().getCategoryById(id)?.color;
    if (hex == null || hex.isEmpty) return null;
    return colorFromCssHex(hex);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final showDeleteAffordance = _hover && !_editing;
    // Drag handle is hidden until the row is hovered — desktop-native pattern,
    // matches macOS list affordances (no persistent grip on the active row).
    final showDragHandle = _hover && widget.dragHandle != null;

    final background = widget.active
        ? tokens.colors.surface.selected
        : (_hover ? tokens.colors.surface.hover : Colors.transparent);
    final labelColor = widget.active
        ? tokens.colors.text.mediumEmphasis
        : tokens.colors.text.lowEmphasis;
    final countColor = widget.active
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.lowEmphasis;

    // Surface each selected category's color as a small dot left of the
    // title. Capped at three dots so the leading gutter stays compact;
    // categories whose colour cannot be resolved (deleted, no colour set)
    // are skipped.
    final categoryIds = widget.view.filter.selectedCategoryIds;
    final categoryDotColors = <Color>[];
    for (final id in categoryIds) {
      if (categoryDotColors.length == 3) break;
      final c = _categoryColor(id);
      if (c != null) categoryDotColors.add(c);
    }

    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: Semantics(
        button: true,
        selected: widget.active,
        label: widget.view.name,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _editing ? null : widget.onActivate,
          onDoubleTap: _editing ? null : _enterEditMode,
          child: Container(
            key: SavedTaskFilterRowKeys.root(widget.view.id),
            margin: EdgeInsetsDirectional.only(start: tokens.spacing.step2),
            constraints: BoxConstraints(
              // step6 + step1 → 26: same row min-height as before.
              minHeight: tokens.spacing.step6 + tokens.spacing.step1,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(tokens.radii.m),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  // start: step5 + step2 + step1 → 22 (restored to the
                  // pre-refactor pill geometry the user signed off on).
                  padding: EdgeInsetsDirectional.only(
                    start:
                        tokens.spacing.step5 +
                        tokens.spacing.step2 +
                        tokens.spacing.step1,
                    end: tokens.spacing.step3,
                    top: tokens.spacing.step2,
                    bottom: tokens.spacing.step2,
                  ),
                  child: Row(
                    children: [
                      // Reserve the dot column even when absent so the
                      // label stays vertically aligned across rows. Each
                      // dot is step3 (8) with a step1 (2) gap between
                      // them; the column expands when multiple categories
                      // are selected, which is the desired behaviour
                      // (more dots = wider gutter).
                      if (categoryDotColors.isEmpty || _editing)
                        SizedBox(
                          width: tokens.spacing.step3,
                          height: tokens.spacing.step3,
                        )
                      else
                        SizedBox(
                          height: tokens.spacing.step3,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (
                                var i = 0;
                                i < categoryDotColors.length;
                                i++
                              ) ...[
                                if (i > 0)
                                  SizedBox(width: tokens.spacing.step1),
                                Container(
                                  width: tokens.spacing.step3,
                                  height: tokens.spacing.step3,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: categoryDotColors[i],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      SizedBox(width: tokens.spacing.step3),
                      Expanded(
                        child: _editing
                            ? _RenameField(
                                key: SavedTaskFilterRowKeys.renameField(
                                  widget.view.id,
                                ),
                                controller: _nameController,
                                focusNode: _nameFocus,
                                tokens: tokens,
                                semanticLabel:
                                    messages.tasksSavedFilterRenameSemantics,
                                onCommit: _commitRename,
                                onCancel: _cancelRename,
                              )
                            : Text(
                                widget.view.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tokens.typography.styles.others.caption
                                    .copyWith(color: labelColor),
                              ),
                      ),
                      if (!_editing)
                        Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            // Count is rendered when present and the row is not
                            // showing the delete affordance.
                            if (widget.count != null)
                              AnimatedOpacity(
                                opacity: showDeleteAffordance ? 0 : 1,
                                duration: const Duration(milliseconds: 120),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.only(
                                    start: tokens.spacing.step2,
                                  ),
                                  child: Text(
                                    '${widget.count}',
                                    textAlign: TextAlign.end,
                                    style: tokens
                                        .typography
                                        .styles
                                        .body
                                        .bodySmall
                                        .copyWith(
                                          color: countColor,
                                          fontWeight: FontWeight.w600,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                  ),
                                ),
                              ),
                            // Delete affordance: present when hovered. Always
                            // rendered (with opacity 0) so it can be looked up
                            // and exercised in tests; hit-testing is gated on
                            // hover so users can't tap a hidden button.
                            AnimatedOpacity(
                              opacity: showDeleteAffordance ? 1 : 0,
                              duration: const Duration(milliseconds: 120),
                              child: IgnorePointer(
                                ignoring: !showDeleteAffordance,
                                child: _DeleteButton(
                                  id: widget.view.id,
                                  confirmed: _confirmDelete,
                                  tokens: tokens,
                                  tooltip: _confirmDelete
                                      ? messages
                                            .tasksSavedFilterDeleteConfirmTooltip
                                      : messages.tasksSavedFilterDeleteTooltip,
                                  onTap: _handleDeleteTap,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (showDragHandle)
                  Positioned.directional(
                    textDirection: Directionality.of(context),
                    start: tokens.spacing.step1,
                    top: 0,
                    bottom: 0,
                    // Bound the handle to its own narrow column so it never
                    // visually creeps into the dot's space (dot starts at
                    // step5 + step2 + step1 = 22 from the row's left edge).
                    width: tokens.spacing.step5,
                    child: Center(
                      child: KeyedSubtree(
                        key: SavedTaskFilterRowKeys.dragHandle(widget.view.id),
                        child: widget.dragHandle!,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RenameField extends StatelessWidget {
  const _RenameField({
    required this.controller,
    required this.focusNode,
    required this.tokens,
    required this.semanticLabel,
    required this.onCommit,
    required this.onCancel,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final DsTokens tokens;
  final String semanticLabel;
  final VoidCallback onCommit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      textField: true,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            onCancel();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onCommit(),
          onTapOutside: (_) => onCommit(),
          style: tokens.typography.styles.body.bodyMedium.copyWith(
            color: tokens.colors.text.highEmphasis,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radii.s),
              borderSide: BorderSide(color: tokens.colors.interactive.enabled),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radii.s),
              borderSide: BorderSide(color: tokens.colors.interactive.enabled),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({
    required this.id,
    required this.confirmed,
    required this.tokens,
    required this.tooltip,
    required this.onTap,
  });

  final String id;
  final bool confirmed;
  final DsTokens tokens;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = confirmed
        ? tokens.colors.text.onInteractiveAlert
        : tokens.colors.text.lowEmphasis;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 22,
        height: 22,
        child: Material(
          color: confirmed
              ? tokens.colors.alert.error.defaultColor
              : Colors.transparent,
          borderRadius: BorderRadius.circular(tokens.radii.s),
          child: InkWell(
            key: SavedTaskFilterRowKeys.deleteButton(id),
            borderRadius: BorderRadius.circular(tokens.radii.s),
            onTap: onTap,
            child: Center(
              child: Icon(
                Icons.delete_outline,
                size: 14,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
