// ignore_for_file: avoid_dynamic_calls

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

class TaskForm extends StatefulWidget {
  const TaskForm({
    super.key,
    required this.formKey,
    required this.controller,
    required this.focusNode,
    required this.saveFn,
    this.task,
    this.data,
    this.focusOnTitle = false,
    this.withOpenDetails = false,
  });

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
    final localizations = AppLocalizations.of(context)!;

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
                  textCapitalization: TextCapitalization.sentences,
                  keyboardAppearance: Brightness.dark,
                  maxLines: null,
                  style: inputStyle.copyWith(
                    fontFamily: 'Oswald',
                    fontSize: 24,
                    fontWeight: FontWeight.normal,
                  ),
                  name: 'title',
                ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  backgroundColor: AppColors.entryTextColor,
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
                      height: 0.6,
                      fontFamily: 'Oswald',
                    ),
                  ),
                  onChanged: (dynamic _) => widget.saveFn(),
                  selectedColor: widget.data?.status != null
                      ? taskColor(widget.data!.status)
                      : AppColors.entryBgColor,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  runSpacing: 6,
                  spacing: 4,
                  labelStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Oswald',
                  ),
                  options: [
                    FormBuilderChipOption<String>(
                      value: 'OPEN',
                      child: Text(
                        localizations.taskStatusOpen,
                        style: taskFormFieldStyle,
                      ),
                    ),
                    FormBuilderChipOption<String>(
                      value: 'GROOMED',
                      child: Text(
                        localizations.taskStatusGroomed,
                        style: taskFormFieldStyle,
                      ),
                    ),
                    FormBuilderChipOption<String>(
                      value: 'IN PROGRESS',
                      child: Text(
                        localizations.taskStatusInProgress,
                        style: taskFormFieldStyle,
                      ),
                    ),
                    FormBuilderChipOption<String>(
                      value: 'BLOCKED',
                      child: Text(
                        localizations.taskStatusBlocked,
                        style: taskFormFieldStyle,
                      ),
                    ),
                    FormBuilderChipOption<String>(
                      value: 'ON HOLD',
                      child: Text(
                        localizations.taskStatusOnHold,
                        style: taskFormFieldStyle,
                      ),
                    ),
                    FormBuilderChipOption<String>(
                      value: 'DONE',
                      child: Text(
                        localizations.taskStatusDone,
                        style: taskFormFieldStyle,
                      ),
                    ),
                    FormBuilderChipOption<String>(
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
        EditorWidget(
          controller: widget.controller,
          focusNode: widget.focusNode,
          saveFn: widget.saveFn,
          journalEntity: widget.task,
        ),
      ],
    );
  }
}
