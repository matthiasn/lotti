// ignore_for_file: avoid_dynamic_calls

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/latest_ai_response_summary.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/checklists_widget.dart';
import 'package:lotti/features/tasks/ui/header/task_info_row.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class TaskForm extends ConsumerStatefulWidget {
  const TaskForm(
    this.task, {
    super.key,
    this.focusOnTitle = false,
  });

  final Task task;
  final bool focusOnTitle;

  @override
  ConsumerState<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<TaskForm> {
  @override
  Widget build(BuildContext context) {
    final entryId = widget.task.meta.id;
    final taskData = widget.task.data;
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    final formKey = entryState?.formKey;

    if (entryState == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FormBuilder(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 5),
                FormBuilderTextField(
                  autofocus: widget.focusOnTitle,
                  focusNode: notifier.taskTitleFocusNode,
                  initialValue: taskData.title,
                  decoration: inputDecoration(
                    labelText: taskData.title.isEmpty
                        ? context.messages.taskNameLabel
                        : '',
                    themeData: Theme.of(context),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  keyboardAppearance: Theme.of(context).brightness,
                  maxLines: null,
                  style: Theme.of(context).textTheme.titleLarge,
                  name: 'title',
                  onChanged: (_) => notifier.setDirty(
                    value: true,
                    requestFocus: false,
                  ),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: TaskInfoRow(taskId: widget.task.id),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
        EditorWidget(entryId: entryId),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: LatestAiResponseSummary(
            id: entryId,
            aiResponseType: taskSummary,
          ),
        ),
        const SizedBox(height: 10),
        ChecklistsWidget(entryId: entryId, task: widget.task),
        const SizedBox(height: 20),
      ],
    );
  }
}

class TaskStatusLabel extends StatelessWidget {
  const TaskStatusLabel(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(title, softWrap: false),
    );
  }
}
