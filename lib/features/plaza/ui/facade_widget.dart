import 'package:flutter/material.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';

/// Dev-harness palette for facade signage.
///
/// The plaza is 3D scene content rendered inside the prototype harness, not
/// app chrome; like `knowledge_graph/ui/graph_style.dart` it keeps a local
/// palette instead of design-system tokens. If the prototype graduates, this
/// gets rebased onto the token pipeline.
abstract final class FacadeStyle {
  static const background = Color(0xFF14161C);
  static const backgroundDone = Color(0xFF10201A);
  static const text = Color(0xFFECEFF4);
  static const textDim = Color(0xFF8B92A1);

  static Color stateColor(PlazaTaskState state) => switch (state) {
    PlazaTaskState.open => const Color(0xFF8B92A1),
    PlazaTaskState.inProgress => const Color(0xFF5C9DFF),
    PlazaTaskState.blocked => const Color(0xFFE87C6C),
    PlazaTaskState.done => const Color(0xFF63C99A),
    PlazaTaskState.cancelled => const Color(0xFF565B66),
  };

  static String stateLabel(PlazaTaskState state) => switch (state) {
    PlazaTaskState.open => 'OPEN',
    PlazaTaskState.inProgress => 'IN PROGRESS',
    PlazaTaskState.blocked => 'BLOCKED',
    PlazaTaskState.done => 'DONE',
    PlazaTaskState.cancelled => 'CANCELLED',
  };
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _shortDate(DateTime date) => '${_months[date.month - 1]} ${date.day}';

/// The live signage on one building facade.
///
/// Content-packed, no filler: the building's height is sized to this very
/// layout (see `StreetLayout.heightFor`), so the column stacks cover art
/// (full 16:9), title, meta, open checklist items, and the state chip with
/// nothing artificial in between. A scale-down fit absorbs the estimate
/// error rather than overflowing.
///
/// On the near tier the checklist checkboxes are live — the proof that
/// interactive widgets on meshes matter (spec §11).
class FacadeWidget extends StatefulWidget {
  const FacadeWidget({
    required this.task,
    required this.interactive,
    super.key,
  });

  final PlazaTask task;

  /// Near-tier facades get live checkboxes; static captures stay passive.
  final bool interactive;

  @override
  State<FacadeWidget> createState() => _FacadeWidgetState();
}

class _FacadeWidgetState extends State<FacadeWidget> {
  final Set<int> _ticked = {};

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final state = task.state;
    final stateColor = FacadeStyle.stateColor(state);
    final quiet =
        state == PlazaTaskState.done || state == PlazaTaskState.cancelled;
    final dimText = quiet ? FacadeStyle.textDim : FacadeStyle.text;

    return Material(
      color: state == PlazaTaskState.done
          ? FacadeStyle.backgroundDone
          : FacadeStyle.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Progress reads as a filled portion of the whole facade.
          if (task.checklistItems > 0)
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: task.progress.clamp(0.0, 1.0),
                widthFactor: 1,
                child: ColoredBox(color: stateColor.withValues(alpha: 0.18)),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) => FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 10, color: Color(task.categoryColor)),
                    if (task.coverImageUrl != null)
                      // The demo covers are 16:9; a matching full-bleed
                      // frame shows the whole image, edge to edge,
                      // uncropped and undistorted.
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Opacity(
                          opacity: quiet ? 0.45 : 1,
                          child: Image.network(
                            task.coverImageUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: dimText,
                              fontSize: 44,
                              height: 1.15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (task.due != null ||
                              task.linkedTaskIds.isNotEmpty) ...[
                            Row(
                              children: [
                                if (task.due != null)
                                  Text(
                                    'due ${_shortDate(task.due!)}',
                                    style: const TextStyle(
                                      color: FacadeStyle.textDim,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                const Spacer(),
                                if (task.linkedTaskIds.isNotEmpty)
                                  Text(
                                    'links ${task.linkedTaskIds.length}',
                                    style: const TextStyle(
                                      color: FacadeStyle.textDim,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],
                          for (final (index, item)
                              in task.openChecklistItems.take(8).indexed)
                            SizedBox(
                              height: 46,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 40,
                                    child: Checkbox(
                                      value: _ticked.contains(index),
                                      activeColor: stateColor,
                                      onChanged: widget.interactive && !quiet
                                          ? (v) => setState(() {
                                              if (v ?? false) {
                                                _ticked.add(index);
                                              } else {
                                                _ticked.remove(index);
                                              }
                                            })
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: _ticked.contains(index)
                                            ? FacadeStyle.textDim
                                            : dimText,
                                        fontSize: 26,
                                        decoration: _ticked.contains(index)
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: stateColor.withValues(
                                    alpha: quiet ? 0.25 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  FacadeStyle.stateLabel(state),
                                  style: TextStyle(
                                    color: quiet ? stateColor : Colors.black,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (task.checklistItems > 0)
                                Text(
                                  '${(task.progress * task.checklistItems).round()}'
                                  '/${task.checklistItems}',
                                  style: const TextStyle(
                                    color: FacadeStyle.textDim,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
