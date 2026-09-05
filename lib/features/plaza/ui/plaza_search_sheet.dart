import 'package:flutter/services.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';
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
  final _focus = FocusNode();
  late List<PlazaTask> _results = searchPlazaTasks(widget.tasks, '');
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _focus.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
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
    return Align(
      alignment: const Alignment(0, -0.75),
      child: Container(
        width: 540,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: const Color(0xFF1D2028),
          border: Border.all(color: const Color(0x1FFFFFFF)),
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0xB3000000),
              blurRadius: 64,
              offset: Offset(0, 24),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x14FFFFFF))),
              ),
              child: Row(
                children: [
                  const Text(
                    '/',
                    style: TextStyle(
                      fontFamily: PlazaStyle.fontMono,
                      fontSize: 16,
                      color: PlazaStyle.teal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Focus(
                      onKeyEvent: _onKey,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        onChanged: _onQuery,
                        style: const TextStyle(
                          fontFamily: PlazaStyle.fontText,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Search tasks, enter to fly',
                          hintStyle: TextStyle(color: Color(0x73FFFFFF)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    'esc to close',
                    style: TextStyle(
                      fontFamily: PlazaStyle.fontText,
                      fontSize: 11,
                      color: Color(0x73FFFFFF),
                    ),
                  ),
                ],
              ),
            ),
            for (final (i, task) in _results.indexed)
              InkWell(
                onTap: () => widget.onPick(task),
                hoverColor: PlazaStyle.teal.withValues(alpha: 0.16),
                child: Container(
                  color: i == _selected
                      ? PlazaStyle.teal.withValues(alpha: 0.16)
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: PlazaStyle.lantern(
                            widget.attentionOf(task).lantern,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: PlazaStyle.fontText,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.weekOf(task),
                        style: const TextStyle(
                          fontFamily: PlazaStyle.fontMono,
                          fontSize: 12,
                          color: Color(0x80FFFFFF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        '↵ fly',
                        style: TextStyle(
                          fontFamily: PlazaStyle.fontText,
                          fontSize: 11,
                          color: PlazaStyle.teal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
