// ignore_for_file: avoid_dynamic_calls

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/categories/category_field.dart';
import 'package:lotti/widgets/date_time/duration_bottom_sheet.dart';

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

    final save = notifier.save;
    final formKey = entryState?.formKey;

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
                const SizedBox(height: 10),
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
                  //style: const TextStyle(fontSize: fontSizeLarge),
                  name: 'title',
                  onChanged: (_) => notifier.setDirty(value: true),
                ),
                inputSpacer,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 120,
                      child: TextField(
                        decoration: inputDecoration(
                          labelText: context.messages.taskEstimateLabel,
                          themeData: Theme.of(context),
                        ),
                        style: context.textTheme.titleMedium,
                        readOnly: true,
                        controller: TextEditingController(
                          text:
                              formatDuration(taskData.estimate).substring(0, 5),
                        ),
                        onTap: () async {
                          final duration = await showModalBottomSheet<Duration>(
                            context: context,
                            builder: (context) {
                              return DurationBottomSheet(taskData.estimate);
                            },
                          );
                          if (duration != null) {
                            await save(estimate: duration);
                          }
                        },
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: FormBuilderDropdown<String>(
                        name: 'status',
                        borderRadius: BorderRadius.circular(10),
                        elevation: 2,
                        onChanged: (dynamic _) => save(),
                        decoration: inputDecoration(
                          labelText: 'Status:',
                          themeData: Theme.of(context),
                        ),
                        initialValue: taskData.status.map(
                              open: (_) => 'OPEN',
                              groomed: (_) => 'GROOMED',
                              started: (_) => 'STARTED',
                              inProgress: (_) => 'IN PROGRESS',
                              blocked: (_) => 'BLOCKED',
                              onHold: (_) => 'ON HOLD',
                              done: (_) => 'DONE',
                              rejected: (_) => 'REJECTED',
                            ) ??
                            'OPEN',
                        items: [
                          DropdownMenuItem<String>(
                            value: 'OPEN',
                            child: TaskStatusLabel(
                              context.messages.taskStatusOpen,
                            ),
                          ),
                          DropdownMenuItem<String>(
                            value: 'GROOMED',
                            child: TaskStatusLabel(
                              context.messages.taskStatusGroomed,
                            ),
                          ),
                          DropdownMenuItem<String>(
                            value: 'IN PROGRESS',
                            child: TaskStatusLabel(
                              context.messages.taskStatusInProgress,
                            ),
                          ),
                          DropdownMenuItem<String>(
                            value: 'BLOCKED',
                            child: TaskStatusLabel(
                              context.messages.taskStatusBlocked,
                            ),
                          ),
                          DropdownMenuItem<String>(
                            value: 'ON HOLD',
                            child: TaskStatusLabel(
                              context.messages.taskStatusOnHold,
                            ),
                          ),
                          DropdownMenuItem<String>(
                            value: 'DONE',
                            child: TaskStatusLabel(
                              context.messages.taskStatusDone,
                            ),
                          ),
                          DropdownMenuItem<String>(
                            value: 'REJECTED',
                            child: TaskStatusLabel(
                              context.messages.taskStatusRejected,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: CategoryField(
                        categoryId: widget.task.meta.categoryId,
                        onSave: (category) {
                          notifier.updateCategoryId(category?.id);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        EditorWidget(entryId: entryId),
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
