import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Collapsible description card wrapping [EditorWidget] for rich text editing.
class DesktopDescriptionCard extends ConsumerStatefulWidget {
  const DesktopDescriptionCard({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  ConsumerState<DesktopDescriptionCard> createState() =>
      _DesktopDescriptionCardState();
}

class _DesktopDescriptionCardState
    extends ConsumerState<DesktopDescriptionCard> {
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final entryState = ref
        .watch(
          entryControllerProvider(id: widget.taskId),
        )
        .value;
    final entry = entryState?.entry;

    if (entry is! Task) return const SizedBox.shrink();

    final hasText = entry.entryText?.plainText.trim().isNotEmpty ?? false;

    // Only show when there is text or the editor is actively being used
    if (!hasText && _collapsed) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: TaskShowcasePalette.surface(context),
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(color: TaskShowcasePalette.border(context)),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.messages.taskShowcaseTaskDescription,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: TaskShowcasePalette.highText(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _collapsed = !_collapsed),
                  child: Icon(
                    _collapsed
                        ? Icons.expand_more_rounded
                        : Icons.expand_less_rounded,
                    color: TaskShowcasePalette.mediumText(context),
                  ),
                ),
              ],
            ),
            if (!_collapsed) ...[
              SizedBox(height: tokens.spacing.step4),
              EditorWidget(
                entryId: widget.taskId,
                margin: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
