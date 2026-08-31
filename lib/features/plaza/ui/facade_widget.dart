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

/// The live signage on one building facade.
///
/// Designed to read at distance: state as color and light, progress as a
/// filled portion of the facade, title auto-scaled. The checkbox on the
/// near tier exists to prove interactive widgets on meshes work (spec §11).
class FacadeWidget extends StatefulWidget {
  const FacadeWidget({
    required this.task,
    required this.interactive,
    super.key,
  });

  final PlazaTask task;

  /// Near-tier facades get a live checkbox; mid-tier captures stay passive.
  final bool interactive;

  @override
  State<FacadeWidget> createState() => _FacadeWidgetState();
}

class _FacadeWidgetState extends State<FacadeWidget> {
  bool _demoTicked = false;

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final state = task.state;
    final stateColor = FacadeStyle.stateColor(state);
    final quiet =
        state == PlazaTaskState.done || state == PlazaTaskState.cancelled;

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
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 10, color: Color(task.categoryColor)),
                const SizedBox(height: 20),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      task.title,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: quiet ? FacadeStyle.textDim : FacadeStyle.text,
                        fontSize: 44,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: stateColor.withValues(alpha: quiet ? 0.25 : 1),
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
                if (widget.interactive && !quiet) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Transform.scale(
                        scale: 1.6,
                        child: Checkbox(
                          value: _demoTicked,
                          activeColor: stateColor,
                          onChanged: (v) =>
                              setState(() => _demoTicked = v ?? false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Tick me from the street',
                          style: TextStyle(
                            color: FacadeStyle.textDim,
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
