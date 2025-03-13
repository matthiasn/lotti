// ignore_for_file: avoid_dynamic_calls

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/categories/ui/widgets/category_field.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_widget.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/tasks/ui/checklists/checklists_widget.dart';
import 'package:lotti/features/tasks/ui/time_recording_icon.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/date_time/duration_bottom_sheet.dart';
import 'package:showcaseview/showcaseview.dart';

final showNextButtonProvider = StateProvider<bool>((ref) => true);
final showNextEstimateButtonProvider = StateProvider<bool>((ref) => false);
final showNextStatusButtonProvider = StateProvider<bool>((ref) => false);

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
  final _formBtnKey = GlobalKey();
  final _estimateKey = GlobalKey();
  final _taskStatusKey = GlobalKey();
  final _taskCategoryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ShowCaseWidget.of(context)
            .startShowCase([_formBtnKey, _estimateKey, _taskStatusKey]);
      }
    });
  }

  void _nextStep(GlobalKey nextKey) {
    Future.delayed(const Duration(milliseconds: 500), () {
      // ignore: use_build_context_synchronously
      ShowCaseWidget.of(context).startShowCase([nextKey]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final entryId = widget.task.meta.id;
    final taskData = widget.task.data;
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).value;

    final save = notifier.save;
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
                const SizedBox(height: 10),
                Showcase(
                  key: _formBtnKey,
                  description: 'Enter a task title!',
                  disposeOnTap: true,
                  onTargetClick: () {},
                  child: Column(
                    children: [
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
                        onChanged: (value) => notifier.setDirty(
                          value: true,
                        ),
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Consumer(
                        builder: (context, ref, child) {
                          final showNextButton =
                              ref.watch(showNextButtonProvider);
                          return Visibility(
                            visible: showNextButton,
                            child: GestureDetector(
                              onTap: () {
                                ref
                                    .read(showNextButtonProvider.notifier)
                                    .state = false;
                                ref
                                    .read(
                                      showNextEstimateButtonProvider.notifier,
                                    )
                                    .state = true;
                                _nextStep(_estimateKey);
                              },
                              child: const Icon(
                                Icons.check_circle,
                                size: 20,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                inputSpacer,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Showcase(
                        key: _estimateKey,
                        description: 'Set the estimated time for your task!',
                        disposeOnTap: true,
                        onTargetClick: () {},
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                decoration: inputDecoration(
                                  labelText: context.messages.taskEstimateLabel,
                                  themeData: Theme.of(context),
                                ),
                                style: context.textTheme.titleMedium,
                                readOnly: true,
                                controller: TextEditingController(
                                  text: formatDuration(taskData.estimate)
                                      .substring(0, 5),
                                ),
                                onTap: () async {
                                  final duration =
                                      await showModalBottomSheet<Duration>(
                                    context: context,
                                    builder: (context) {
                                      return DurationBottomSheet(
                                        taskData.estimate,
                                      );
                                    },
                                  );
                                  if (duration != null) {
                                    await save(estimate: duration);
                                  }
                                },
                              ),
                            ),
                            Consumer(
                              builder: (context, ref, child) {
                                final showNextEstimate =
                                    ref.watch(showNextEstimateButtonProvider);
                                return showNextEstimate
                                    ? GestureDetector(
                                        onTap: () {
                                          ref
                                              .read(
                                                showNextEstimateButtonProvider
                                                    .notifier,
                                              )
                                              .state = false;
                                          ref
                                              .read(
                                                showNextStatusButtonProvider
                                                    .notifier,
                                              )
                                              .state = true;

                                          _nextStep(_taskStatusKey);
                                        },
                                        child: const Icon(
                                          Icons.check_circle,
                                          size: 20,
                                        ),
                                      )
                                    : const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    TimeRecordingIcon(
                      taskId: entryId,
                      padding: const EdgeInsets.only(left: 10),
                    ),
                    const Spacer(),
                    Showcase(
                      key: _taskStatusKey,
                      description: 'Set your task current status!',
                      disposeOnTap: true,
                      onTargetClick: () {},
                      child: Row(
                        children: [
                          SizedBox(
                            width: 180,
                            child: FormBuilderDropdown<String>(
                              name: 'status',
                              borderRadius: BorderRadius.circular(10),
                              elevation: 2,
                              onChanged: notifier.updateTaskStatus,
                              decoration: inputDecoration(
                                labelText: 'Status:',
                                themeData: Theme.of(context),
                              ),
                              key: Key(
                                  'task_status_dropdown_${taskData.status}',),
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
                          Consumer(
                            builder: (context, ref, child) {
                              final showNextStatus =
                                  ref.watch(showNextStatusButtonProvider);
                              return showNextStatus
                                  ? GestureDetector(
                                      onTap: () {
                                        ref
                                            .read(
                                              showNextStatusButtonProvider
                                                  .notifier,
                                            )
                                            .state = false;
                                        _nextStep(_taskCategoryKey);
                                      },
                                      child: const Icon(
                                        Icons.check_circle,
                                        size: 20,
                                      ),
                                    )
                                  : const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Showcase(
                  key: _taskCategoryKey,
                  description: 'Select/Add a category for your task!',
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: CategoryField(
                          categoryId: widget.task.categoryId,
                          onSave: (category) {
                            notifier.updateCategoryId(category?.id);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
        EditorWidget(entryId: entryId),
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
