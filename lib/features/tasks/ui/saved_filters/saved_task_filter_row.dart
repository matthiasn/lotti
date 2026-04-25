import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

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

  late final TextEditingController _nameController =
      TextEditingController(text: widget.view.name);
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

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final showDeleteAffordance = _hover && !_editing;
    final showDragHandle = (_hover || widget.active) && widget.dragHandle != null;

    final background = widget.active
        ? tokens.colors.surface.selected
        : (_hover ? tokens.colors.surface.hover : Colors.transparent);
    final labelColor = widget.active
        ? tokens.colors.text.highEmphasis
        : tokens.colors.text.mediumEmphasis;
    final countColor = widget.active
        ? tokens.colors.interactive.enabled
        : tokens.colors.text.lowEmphasis;

    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _editing ? null : widget.onActivate,
        onDoubleTap: _editing ? null : _enterEditMode,
        child: Container(
          key: SavedTaskFilterRowKeys.root(widget.view.id),
          margin: const EdgeInsets.only(left: 4),
          constraints: const BoxConstraints(minHeight: 32),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(tokens.radii.m),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (widget.active)
                Positioned(
                  left: 14,
                  top: 7,
                  bottom: 7,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: tokens.colors.interactive.enabled,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              if (!widget.active && !_hover)
                Positioned(
                  left: 9,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tokens.colors.interactive.enabled
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  start: 30,
                  end: 8,
                  top: 7,
                  bottom: 7,
                ),
                child: Row(
                  children: [
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
                              style: tokens.typography.styles.body.bodyMedium
                                  .copyWith(
                                color: labelColor,
                                fontWeight: widget.active
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
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
                                padding: const EdgeInsetsDirectional.only(
                                  start: 6,
                                ),
                                child: Text(
                                  '${widget.count}',
                                  textAlign: TextAlign.end,
                                  style: tokens.typography.styles.body.bodySmall
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
                  start: 4,
                  top: 0,
                  bottom: 0,
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radii.s),
              borderSide:
                  BorderSide(color: tokens.colors.interactive.enabled),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(tokens.radii.s),
              borderSide:
                  BorderSide(color: tokens.colors.interactive.enabled),
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
