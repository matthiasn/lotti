import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/tasks/ui/filtering/task_filter_content.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TaskFilterIcon extends ConsumerWidget {
  const TaskFilterIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTasks = ref.watch(journalPageScopeProvider);
    // Get the parent container to share with the modal
    final container = ProviderScope.containerOf(context);

    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.spacingSmall),
      child: IconButton(
        onPressed: () {
          ModalUtils.showSinglePageModal<void>(
            context: context,
            title: context.messages.tasksFilterTitle,
            builder: (_) => const TaskFilterContent(),
            modalDecorator: (child) {
              // Use UncontrolledProviderScope to share the parent container
              // with overrides for the modal-specific scope value
              return UncontrolledProviderScope(
                container: container,
                child: ProviderScope(
                  overrides: [
                    journalPageScopeProvider.overrideWithValue(showTasks),
                  ],
                  child: child,
                ),
              );
            },
          );
        },
        icon: Icon(MdiIcons.filterVariant),
      ),
    );
  }
}
