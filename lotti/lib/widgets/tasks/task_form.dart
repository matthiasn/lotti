import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/task_utils.dart';
import 'package:lotti/widgets/form_builder/cupertino_datepicker.dart';
import 'package:lotti/widgets/journal/editor/editor_widget.dart';
import 'package:lotti/widgets/tasks/linked_duration.dart';

class TaskForm extends StatefulWidget {
  const TaskForm({
    Key? key,
    required this.formKey,
    required this.controller,
    required this.focusNode,
    required this.saveFn,
    this.task,
    this.data,
    this.focusOnTitle = false,
    this.withOpenDetails = false,
  }) : super(key: key);

  final GlobalKey<FormBuilderState> formKey;
  final quill.QuillController controller;
  final FocusNode focusNode;
  final Function saveFn;
  final TaskData? data;
  final Task? task;
  final bool focusOnTitle;
  final bool withOpenDetails;

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  bool details = false;

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 12),
          child: FormBuilder(
            key: widget.formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: <Widget>[
                FormBuilderTextField(
                  autofocus: widget.focusOnTitle,
                  initialValue: widget.data?.title ?? '',
                  decoration: InputDecoration(
                    labelText: localizations.taskNameLabel,
                    labelStyle: labelStyle,
                  ),
                  maxLines: null,
                  style: inputStyle.copyWith(
                    fontFamily: 'Oswald',
                    fontSize: 24,
                    fontWeight: FontWeight.normal,
                  ),
                  name: 'title',
                ),
                // TODO: either make use of due date or remove
                // FormBuilderCupertinoDateTimePicker(
                //   name: 'due',
                //   alwaysUse24HourFormat: true,
                //   format: DateFormat('EEEE, MMMM d, yyyy \'at\' HH:mm'),
                //   inputType: CupertinoDateTimePickerInputType.both,
                //   style: inputStyle.copyWith(
                //     fontSize: 18,
                //     fontWeight: FontWeight.w300,
                //     fontFamily: 'Oswald',
                //   ),
                //   decoration: InputDecoration(
                //     labelText: localizations.taskDueLabel,
                //     labelStyle: labelStyle,
                //   ),
                //   initialValue: widget.data?.due ?? DateTime.now(),
                //   theme: DatePickerTheme(
                //     headerColor: AppColors.headerBgColor,
                //     backgroundColor: AppColors.bodyBgColor,
                //     itemStyle: const TextStyle(
                //       color: Colors.white,
                //       fontWeight: FontWeight.bold,
                //       fontSize: 18,
                //     ),
                //     doneStyle: const TextStyle(
                //       color: Colors.white,
                //       fontSize: 16,
                //     ),
                //   ),
                // ),
                FormBuilderCupertinoDateTimePicker(
                  name: 'estimate',
                  alwaysUse24HourFormat: true,
                  format: DateFormat('HH:mm'),
                  inputType: CupertinoDateTimePickerInputType.time,
                  style: inputStyle.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w300,
                    fontFamily: 'Oswald',
                  ),
                  onChanged: (_) => widget.saveFn(),
                  decoration: InputDecoration(
                    labelText: localizations.taskEstimateLabel,
                    labelStyle: labelStyle,
                  ),
                  initialValue: DateTime.fromMillisecondsSinceEpoch(
                    widget.data?.estimate?.inMilliseconds ?? 0,
                    isUtc: true,
                  ),
                  theme: DatePickerTheme(
                    headerColor: AppColors.headerBgColor,
                    backgroundColor: AppColors.bodyBgColor,
                    itemStyle: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    doneStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
                FormBuilderChoiceChip(
                  name: 'status',
                  padding: null,
                  initialValue: widget.data?.status.map(
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
                  decoration: InputDecoration(
                    labelText: localizations.taskStatusLabel,
                    labelStyle: labelStyle.copyWith(
                      height: 1,
                      fontFamily: 'Oswald',
                    ),
                  ),
                  onChanged: (_) => widget.saveFn(),
                  selectedColor: widget.data?.status != null
                      ? taskColor(widget.data!.status)
                      : AppColors.entryBgColor,
                  runSpacing: 0,
                  spacing: 4,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Oswald',
                  ),
                  options: [
                    FormBuilderFieldOption(
                      value: 'OPEN',
                      child: Text(
                        localizations.taskStatusOpen,
                        style: taskFormFieldStyle,
                      ),
                    ),
                    FormBuilderFieldOption(
                      value: 'GROOMED',
                      child: Text(
                        localizations.taskStatusGroomed,
                        style: taskFormFieldStyle,
                      ),
                    ),
                    FormBuilderFieldOption(
                      value: 'IN PROGRESS',
                      child: Text(
                        localizations.taskStatusInProgress,
                        style: taskFormFieldStyle,
                      ),
                    ),
                    FormBuilderFieldOption(
                      value: 'BLOCKED',
                      child: Text(
                        localizations.taskStatusBlocked,
                        style: taskFormFieldStyle,
                      ),
                    ),
                    FormBuilderFieldOption(
                      value: 'ON HOLD',
                      child: Text(
                        localizations.taskStatusOnHold,
                        style: taskFormFieldStyle,
                      ),
                    ),
                    FormBuilderFieldOption(
                      value: 'DONE',
                      child: Text(
                        localizations.taskStatusDone,
                        style: taskFormFieldStyle,
                      ),
                    ),
                    FormBuilderFieldOption(
                      value: 'REJECTED',
                      child: Text(
                        localizations.taskStatusRejected,
                        style: taskFormFieldStyle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (widget.task != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4, top: 2),
            child: LinkedDuration(task: widget.task!),
          ),
        EditorWidget(
          controller: widget.controller,
          focusNode: widget.focusNode,
          saveFn: widget.saveFn,
          minHeight: 40,
          journalEntity: widget.task,
          autoFocus: false,
        ),
      ],
    );
  }
}
