// ignore_for_file: avoid_dynamic_calls

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/ui/latest_ai_response_summary.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/checklists_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/header/task_info_row.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class TaskForm extends ConsumerStatefulWidget {
  const TaskForm(
    this.task, {
    super.key,
  });

  final Task task;

  @override
  ConsumerState<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<TaskForm> {
  bool _isEditing = false;
  final FocusNode _titleFocusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final entryId = widget.task.meta.id;
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    if (entryState == null) {
      return const SizedBox.shrink();
    }

    final title = widget.task.data.title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 5),
              AnimatedCrossFade(
                duration: checklistCrossFadeDuration,
                firstChild: TitleTextField(
                  initialValue: title,
                  resetToInitialValue: true,
                  onSave: (newTitle) async {
                    await notifier.save(title: newTitle);
                    setState(() {
                      _isEditing = false;
                    });
                  },
                  autofocus: true,
                  focusNode: _titleFocusNode,
                  hintText: context.messages.taskNameHint,
                  onTapOutside: (_) => setState(() {
                    _isEditing = false;
                  }),
                  onCancel: () => setState(() {
                    _isEditing = false;
                  }),
                ),
                secondChild: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          softWrap: true,
                          maxLines: 3,
                          style: context.textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.edit,
                          color: context.colorScheme.outline,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _isEditing = !_isEditing;
                          });

                          Future.delayed(
                            const Duration(milliseconds: 100),
                            _titleFocusNode.requestFocus,
                          );
                        },
                      ),
                    ],
                  ),
                ),
                crossFadeState: _isEditing || title.isEmpty
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
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
