import 'package:lotti/features/design_system/theme/icon_tokens.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/ui/checklist_ticks.dart';
import 'package:lotti/features/plaza/ui/plaza_style.dart';
import 'package:material_ui/material_ui.dart';

/// The task detail raised by OPEN: a panel over the world, which keeps
/// rendering behind it. Esc or ✕ returns to the same pose.
class TaskSidePanel extends StatelessWidget {
  const TaskSidePanel({
    required this.attention,
    required this.categoryLabel,
    required this.ticks,
    required this.onClose,
    super.key,
  });

  final TaskAttention attention;
  final String categoryLabel;
  final ChecklistTicks ticks;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final task = attention.task;
    final chip = PlazaStyle.chip(attention);
    final meta = taskMetaBits(task).join(' · ');
    return Positioned(
      right: 16,
      top: 60,
      bottom: 60,
      width: 400,
      child: Material(
        color: const Color(0xFF1D2028),
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Color(0x1AFFFFFF)),
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 24,
        shadowColor: const Color(0xB3000000),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListenableBuilder(
            listenable: ticks,
            builder: (context, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        categoryLabel.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: PlazaStyle.fontText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                          color: PlazaStyle.textFaint,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: onClose,
                      tooltip: 'Close',
                      icon: const Icon(
                        LottiIcons.close,
                        color: Color(0x99FFFFFF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  task.title,
                  style: const TextStyle(
                    fontFamily: PlazaStyle.fontText,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: chip.fill,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        chip.label,
                        style: TextStyle(
                          fontFamily: PlazaStyle.fontText,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: chip.ink,
                        ),
                      ),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        style: const TextStyle(
                          fontFamily: PlazaStyle.fontMono,
                          fontSize: 13,
                          color: Color(0x99FFFFFF),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: Color(0x1AFFFFFF), height: 1),
                const SizedBox(height: 14),
                for (final (i, label) in task.openChecklistItems.indexed)
                  InkWell(
                    onTap: () => ticks.toggle(task.id, i),
                    hoverColor: const Color(0x12FFFFFF),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: ticks.isTicked(task.id, i)
                                  ? const Color(0xD9FFFFFF)
                                  : Colors.transparent,
                              border: Border.all(
                                color: const Color(0xBFFFFFFF),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: ticks.isTicked(task.id, i)
                                ? const Icon(
                                    LottiIcons.confirm,
                                    size: 13,
                                    color: PlazaStyle.panel,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontFamily: PlazaStyle.fontText,
                                fontSize: 15,
                                color: ticks.isTicked(task.id, i)
                                    ? const Color(0x73FFFFFF)
                                    : const Color(0xE6FFFFFF),
                                decoration: ticks.isTicked(task.id, i)
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Spacer(),
                const Text(
                  'The world keeps rendering behind this panel. '
                  'Esc or ✕ returns to the same pose.',
                  style: TextStyle(
                    fontFamily: PlazaStyle.fontText,
                    fontSize: 12,
                    color: Color(0x73FFFFFF),
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
