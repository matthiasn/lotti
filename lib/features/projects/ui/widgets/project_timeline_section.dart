import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked.dart';
import 'package:lotti/features/projects/ui/widgets/showcase/showcase_palette.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The project's own timeline: what is linked straight to the project —
/// notes the companion filed under it, anything the user linked — newest
/// first, shown as a task shows its entries. The project's tasks are left
/// out: they have their panel above, and each keeps its own entries. With
/// nothing linked the section is not there at all.
class ProjectTimelineSection extends ConsumerWidget {
  const ProjectTimelineSection({required this.project, super.key});

  final ProjectEntry project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hasNonTaskLinkedEntriesProvider(project.meta.id))) {
      return const SizedBox.shrink();
    }
    final tokens = context.designTokens;
    return Padding(
      // A section's step below the tasks, its own gap carried with it.
      padding: EdgeInsets.only(top: tokens.spacing.step6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            // On the tasks panel's heading edge.
            padding: EdgeInsets.only(
              left: tokens.spacing.step5,
              right: tokens.spacing.step5,
              bottom: tokens.spacing.step3,
            ),
            child: Semantics(
              header: true,
              child: Text(
                context.messages.projectTimelineTitle,
                style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                  color: ShowcasePalette.highText(context),
                ),
              ),
            ),
          ),
          LinkedEntriesWidget(project, hideTaskEntries: true),
        ],
      ),
    );
  }
}
