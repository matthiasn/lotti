import 'package:flutter/services.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Title search over the project's tasks, at most six matches.
List<PlazaTask> searchPlazaTasks(List<PlazaTask> tasks, String query) {
  final q = query.trim().toLowerCase();
  return [
    for (final t in tasks)
      if (!t.deleted && t.title.toLowerCase().contains(q)) t,
  ].take(6).toList();
}

/// The `/` search sheet: type, arrow through the results, enter to fly.
class PlazaSearchSheet extends StatefulWidget {
  const PlazaSearchSheet({
    required this.tasks,
    required this.attentionOf,
    required this.weekOf,
    required this.onPick,
    required this.onClose,
    super.key,
  });

  final List<PlazaTask> tasks;
  final TaskAttention Function(PlazaTask task) attentionOf;
  final String Function(PlazaTask task) weekOf;
  final ValueChanged<PlazaTask> onPick;
  final VoidCallback onClose;

  @override
  State<PlazaSearchSheet> createState() => _PlazaSearchSheetState();
}

class _PlazaSearchSheetState extends State<PlazaSearchSheet> {
  final _controller = TextEditingController();
  late List<PlazaTask> _results = searchPlazaTasks(widget.tasks, '');
  int _selected = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PlazaSearchSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.tasks, widget.tasks)) {
      _results = searchPlazaTasks(widget.tasks, _controller.text);
      _selected = _results.isEmpty
          ? 0
          : _selected.clamp(0, _results.length - 1);
    }
  }

  void _onQuery(String q) => setState(() {
    _results = searchPlazaTasks(widget.tasks, q);
    _selected = 0;
  });

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final last = _results.length - 1;
    if (key == LogicalKeyboardKey.arrowDown) {
      if (last >= 0) setState(() => _selected = (_selected + 1).clamp(0, last));
    } else if (key == LogicalKeyboardKey.arrowUp) {
      if (last >= 0) setState(() => _selected = (_selected - 1).clamp(0, last));
    } else if (key == LogicalKeyboardKey.enter) {
      if (_selected < _results.length) widget.onPick(_results[_selected]);
    } else if (key == LogicalKeyboardKey.escape) {
      widget.onClose();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(
          top: tokens.spacing.step10,
          left: tokens.spacing.step4,
          right: tokens.spacing.step4,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kDetailContentMaxWidth),
          child: DesignSystemSectionCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Focus(
                  onKeyEvent: _onKey,
                  child: DesignSystemTextInput(
                    controller: _controller,
                    autofocus: true,
                    onChanged: _onQuery,
                    hintText: context.messages.plazaSearchHint,
                    leadingIcon: LottiIcons.search,
                    trailingIcon: LottiIcons.close,
                    onTrailingIconTap: widget.onClose,
                    trailingIconTooltip:
                        context.messages.tasksLabelsDialogClose,
                  ),
                ),
                SizedBox(height: tokens.spacing.step3),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final (i, task) in _results.indexed)
                        InkWell(
                          onTap: () => widget.onPick(task),
                          child: Container(
                            color: i == _selected
                                ? tokens.colors.surface.selected
                                : null,
                            padding: EdgeInsets.symmetric(
                              horizontal: tokens.spacing.step3,
                              vertical: tokens.spacing.step3,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  LottiIcons.map,
                                  color: PlazaStyle.taskColor(
                                    widget.attentionOf(task),
                                  ),
                                ),
                                SizedBox(width: tokens.spacing.step3),
                                Expanded(
                                  child: Text(
                                    task.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tokens
                                        .typography
                                        .styles
                                        .body
                                        .bodyMedium,
                                  ),
                                ),
                                SizedBox(width: tokens.spacing.step3),
                                Text(
                                  widget.weekOf(task),
                                  style:
                                      tokens.typography.styles.others.caption,
                                ),
                                SizedBox(width: tokens.spacing.step3),
                                Text(
                                  context.messages.plazaFlyThere,
                                  style: tokens.typography.styles.others.caption
                                      .copyWith(
                                        color:
                                            tokens.colors.interactive.enabled,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
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
