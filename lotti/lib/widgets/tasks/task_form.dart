import 'package:flutter/material.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/task_utils.dart';
import 'package:lotti/widgets/form_builder/cupertino_datepicker.dart';
import 'package:lotti/widgets/journal/editor_widget.dart';

class TaskForm extends StatelessWidget {
  const TaskForm({
    Key? key,
    required this.formKey,
    required this.controller,
    required this.focusNode,
    required this.saveFn,
    required this.journalEntity,
    this.data,
    this.focusOnTitle = false,
  }) : super(key: key);

  final GlobalKey<FormBuilderState> formKey;
  final quill.QuillController controller;
  final FocusNode focusNode;
  final Function saveFn;
  final TaskData? data;
  final JournalEntity? journalEntity;
  final bool focusOnTitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.headerBgColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 16, right: 16),
            child: FormBuilder(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: <Widget>[
                  FormBuilderTextField(
                    autofocus: focusOnTitle,
                    initialValue: data?.title ?? '',
                    decoration: InputDecoration(
                      labelText: 'Task:',
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
                  FormBuilderCupertinoDateTimePicker(
                    name: 'due',
                    alwaysUse24HourFormat: true,
                    format: DateFormat('EEEE, MMMM d, yyyy \'at\' HH:mm'),
                    inputType: CupertinoDateTimePickerInputType.both,
                    style: inputStyle.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                      fontFamily: 'Oswald',
                    ),
                    decoration: InputDecoration(
                      labelText: 'Task due:',
                      labelStyle: labelStyle,
                    ),
                    initialValue: data?.due ?? DateTime.now(),
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
                    onChanged: (_) => saveFn(),
                    decoration: InputDecoration(
                      labelText: 'Estimate:',
                      labelStyle: labelStyle,
                    ),
                    initialValue: DateTime.fromMillisecondsSinceEpoch(
                      data?.estimate?.inMilliseconds ?? 0,
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
                    initialValue: data?.status.map(
                          open: (_) => 'OPEN',
                          started: (_) => 'STARTED',
                          inProgress: (_) => 'IN PROGRESS',
                          blocked: (_) => 'BLOCKED',
                          onHold: (_) => 'ON HOLD',
                          done: (_) => 'DONE',
                          rejected: (_) => 'REJECTED',
                        ) ??
                        'OPEN',
                    decoration: InputDecoration(
                      labelText: 'Task Status:',
                      labelStyle: labelStyle.copyWith(
                        height: 0.6,
                        fontFamily: 'Oswald',
                      ),
                    ),
                    onChanged: (_) => saveFn(),
                    selectedColor: data?.status != null
                        ? taskColor(data!.status)
                        : AppColors.entryBgColor,
                    runSpacing: 4,
                    spacing: 4,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      fontFamily: 'Oswald',
                    ),
                    options: const [
                      FormBuilderFieldOption(
                        value: 'OPEN',
                        child: Text(
                          'OPEN',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                      FormBuilderFieldOption(
                        value: 'IN PROGRESS',
                        child: Text(
                          'IN PROGRESS',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                      FormBuilderFieldOption(
                        value: 'BLOCKED',
                        child: Text(
                          'BLOCKED',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                      FormBuilderFieldOption(
                        value: 'ON HOLD',
                        child: Text(
                          'ON HOLD',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                      FormBuilderFieldOption(
                        value: 'DONE',
                        child: Text(
                          'DONE',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                      FormBuilderFieldOption(
                        value: 'REJECTED',
                        child: Text(
                          'REJECTED',
                          style: TextStyle(color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          EditorWidget(
            controller: controller,
            focusNode: focusNode,
            saveFn: saveFn,
            minHeight: 100,
            journalEntity: journalEntity,
            autoFocus: false,
          ),
        ],
      ),
    );
  }
}
