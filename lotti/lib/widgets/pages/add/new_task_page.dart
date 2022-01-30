import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/blocs/journal/persistence_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/form_builder/cupertino_datepicker.dart';
import 'package:lotti/widgets/journal/editor_tools.dart';
import 'package:lotti/widgets/journal/editor_widget.dart';

class NewTaskPage extends StatefulWidget {
  const NewTaskPage({
    Key? key,
    this.linked,
  }) : super(key: key);

  final JournalEntity? linked;

  @override
  State<NewTaskPage> createState() => _NewTaskPageState();
}

class _NewTaskPageState extends State<NewTaskPage> {
  final formKey = GlobalKey<FormBuilderState>();
  final quill.QuillController _controller = makeController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  void _save() async {
    formKey.currentState!.save();
    if (formKey.currentState!.validate()) {
      DateTime now = DateTime.now();

      final formData = formKey.currentState?.value;
      final DateTime due = formData!['due'];
      final String title = formData['title'];
      final DateTime dt = formData['estimate'];
      final Duration estimate = Duration(
        hours: dt.hour,
        minutes: dt.minute,
      );
      final String status = formData['status'];

      TaskData taskData = TaskData(
        due: due,
        status: taskStatusFromString(status),
        title: title,
        statusHistory: [],
        dateTo: due,
        dateFrom: DateTime.now(),
        estimate: estimate,
      );

      context.read<PersistenceCubit>().createTaskEntry(
            data: taskData,
            entryText: entryTextFromController(_controller),
            linked: widget.linked,
          );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PersistenceCubit, PersistenceState>(
      builder: (context, PersistenceState state) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'New Task',
              style: TextStyle(
                color: AppColors.entryTextColor,
                fontFamily: 'Oswald',
              ),
            ),
            backgroundColor: AppColors.headerBgColor,
            foregroundColor: AppColors.appBarFgColor,
            actions: <Widget>[
              TextButton(
                onPressed: _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    'Save',
                    style: TextStyle(
                      fontSize: 20,
                      fontFamily: 'Oswald',
                      fontWeight: FontWeight.bold,
                      color: AppColors.appBarFgColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.bodyBgColor,
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: TaskForm(
                      formKey: formKey,
                      controller: _controller,
                      focusNode: _focusNode,
                      saveFn: _save,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class TaskForm extends StatelessWidget {
  const TaskForm({
    Key? key,
    required this.formKey,
    required this.controller,
    required this.focusNode,
    required this.saveFn,
    this.data,
  }) : super(key: key);

  final GlobalKey<FormBuilderState> formKey;
  final quill.QuillController controller;
  final FocusNode focusNode;
  final Function saveFn;
  final TaskData? data;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.headerBgColor,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          FormBuilder(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              children: <Widget>[
                FormBuilderTextField(
                  initialValue: data?.title ?? '',
                  decoration: InputDecoration(
                    labelText: 'Task:',
                    labelStyle: labelStyle,
                  ),
                  style: inputStyle,
                  name: 'title',
                ),
                FormBuilderCupertinoDateTimePicker(
                  name: 'due',
                  alwaysUse24HourFormat: true,
                  format: DateFormat('EEEE, MMMM d, yyyy \'at\' HH:mm'),
                  inputType: CupertinoDateTimePickerInputType.both,
                  style: inputStyle,
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
                  style: inputStyle,
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
                        blocked: (_) => 'BLOCKED',
                        done: (_) => 'DONE',
                        rejected: (_) => 'REJECTED',
                      ) ??
                      'OPEN',
                  decoration: InputDecoration(
                    labelText: 'Task Status:',
                    labelStyle: labelStyle,
                  ),
                  selectedColor: data?.status.map(
                        open: (_) => AppColors.entryBgColor,
                        started: (_) => AppColors.entryBgColor,
                        blocked: (_) => Colors.red,
                        done: (_) => Colors.green,
                        rejected: (_) => Colors.red,
                      ) ??
                      AppColors.entryBgColor,
                  runSpacing: 4,
                  spacing: 4,
                  options: const [
                    FormBuilderFieldOption(
                      value: 'OPEN',
                      child: Text(
                        'OPEN',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ),
                    FormBuilderFieldOption(
                      value: 'STARTED',
                      child: Text(
                        'STARTED',
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
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(8.0)),
            child: EditorWidget(
              controller: controller,
              focusNode: focusNode,
              saveFn: saveFn,
              height: 200,
            ),
          ),
        ],
      ),
    );
  }
}
