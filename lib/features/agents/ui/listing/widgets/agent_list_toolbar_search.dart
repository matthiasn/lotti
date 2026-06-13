import 'package:flutter/material.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_data.dart';
import 'package:lotti/features/agents/ui/listing/agent_list_filter_state.dart';
import 'package:lotti/features/agents/ui/listing/widgets/agent_list_toolbar_popover.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class SearchField extends StatefulWidget {
  const SearchField({
    required this.value,
    required this.onChanged,
    required this.placeholder,
    super.key,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final String placeholder;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode()
      ..addListener(() {
        if (_focused != _focusNode.hasFocus) {
          setState(() => _focused = _focusNode.hasFocus);
        }
      });
  }

  @override
  void didUpdateWidget(covariant SearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync external clears (e.g. "Clear all") into the field.
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.collapsed(
        offset: _controller.text.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    final messages = context.messages;
    final borderColor = _focused
        ? colors.interactive.enabled
        : colors.decorative.level01;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        color: colors.surface.enabled,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(tokens.radii.s),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: colors.interactive.enabled.withValues(alpha: 0.25),
                  blurRadius: 6,
                ),
              ]
            : null,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step4,
        vertical: tokens.spacing.step1,
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 13, color: colors.text.lowEmphasis),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              // Guard no-op keystrokes: the controller fires `onChanged`
              // for every keystroke even when the resulting text matches
              // the value the parent already holds (e.g. didUpdateWidget
              // syncs reset the field). Skipping those avoids a full
              // filter/sort/group rebuild for nothing.
              onChanged: (v) {
                if (v == widget.value) return;
                widget.onChanged(v);
              },
              cursorColor: colors.interactive.enabled,
              style: tokens.typography.styles.others.caption.copyWith(
                color: colors.text.highEmphasis,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                // Suppress all of the field's own decoration so the outer
                // container is the only thing that paints a border / focus
                // ring. Without these explicit overrides Material draws a
                // default underline in the focused state.
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                hintText: widget.placeholder,
                hintStyle: tokens.typography.styles.others.caption.copyWith(
                  color: colors.text.lowEmphasis,
                ),
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              iconSize: 12,
              icon: const Icon(Icons.close),
              color: colors.text.mediumEmphasis,
              tooltip: messages.agentInstancesSearchClear,
              onPressed: () {
                _controller.clear();
                widget.onChanged('');
              },
            ),
        ],
      ),
    );
  }
}

// ── Popovers ────────────────────────────────────────────────────────────────

/// Anchored single-select popover used by Group by / Sort. Returns the
/// selected option id (string) or null if dismissed.
Future<T?> showSingleSelectPopover<T>({
  required BuildContext context,
  required T current,
  required List<(T, String)> options,
  required double width,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null) return null;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return null;
  final position = box.localToGlobal(Offset.zero, ancestor: overlay);
  final size = box.size;
  final tokens = context.designTokens;

  return showMenu<T>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(
        position.dx,
        position.dy + size.height + 6,
        width,
        0,
      ),
      Offset.zero & overlay.size,
    ),
    color: tokens.colors.background.level02,
    elevation: 8,
    constraints: BoxConstraints.tightFor(width: width),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(color: tokens.colors.decorative.level01),
    ),
    items: [
      for (final (value, label) in options)
        PopupMenuItem<T>(
          value: value,
          padding: EdgeInsets.zero,
          height: 32,
          child: PopRow(label: label, selected: value == current),
        ),
    ],
  );
}

/// Anchored multi-select popover used by Filters. One section per
/// [AgentListFilterAxis] supplied; per-section "Clear" link wipes that
/// axis's selections.
Future<void> showFiltersPopover({
  required BuildContext context,
  required AgentListFilterState state,
  required ValueChanged<AgentListFilterState> onChanged,
  required List<AgentListFilterAxis> axes,
}) async {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null) return;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (overlay == null) return;
  final position = box.localToGlobal(Offset.zero, ancestor: overlay);
  final size = box.size;
  final tokens = context.designTokens;

  await showDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (dialogContext) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(dialogContext).pop(),
            ),
          ),
          Positioned(
            left: position.dx,
            top: position.dy + size.height + 6,
            width: 240,
            child: FiltersPopoverPanel(
              tokens: tokens,
              state: state,
              onChanged: onChanged,
              axes: axes,
            ),
          ),
        ],
      );
    },
  );
}
