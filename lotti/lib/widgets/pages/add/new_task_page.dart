import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:intl/intl.dart';
import 'package:lotti/blocs/journal/persistence_cubit.dart';
import 'package:lotti/blocs/journal/persistence_state.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/file_utils.dart';
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
  final JournalDb _db = getIt<JournalDb>();
  final _formKey = GlobalKey<FormBuilderState>();
  final quill.QuillController _controller = makeController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PersistenceCubit, PersistenceState>(
      builder: (context, PersistenceState state) {
        void _save() async {
          _formKey.currentState!.save();
          if (_formKey.currentState!.validate()) {
            DateTime now = DateTime.now();
            final formData = _formKey.currentState?.value;
            debugPrint('$formData');

            DateTime dt = formData!['estimate'];
            Duration estimate = Duration(hours: dt.hour, minutes: dt.minute);

            TaskData taskData = TaskData(
              due: formData['due'],
              status: TaskStatus.open(
                id: uuid.v1(),
                createdAt: now,
                utcOffset: now.timeZoneOffset.inMinutes,
              ),
              title: formData['title'],
              statusHistory: [],
              dateTo: formData['due'],
              dateFrom: DateTime.now(),
              estimate: estimate,
            );

            EntryText entryText = entryTextFromController(_controller);

            context.read<PersistenceCubit>().createTaskEntry(
                  data: taskData,
                  entryText: entryTextFromController(_controller),
                  linked: widget.linked,
                );
            Navigator.pop(context);
          }
        }

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
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    color: AppColors.headerBgColor,
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        FormBuilder(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            children: <Widget>[
                              FormBuilderTextField(
                                initialValue: '',
                                decoration: InputDecoration(
                                  labelText: 'Task:',
                                  labelStyle: labelStyle,
                                ),
                                style: inputStyle,
                                name: 'title',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                              FormBuilderCupertinoDateTimePicker(
                                name: 'due',
                                alwaysUse24HourFormat: true,
                                format: DateFormat(
                                    'EEEE, MMMM d, yyyy \'at\' HH:mm'),
                                inputType:
                                    CupertinoDateTimePickerInputType.both,
                                style: inputStyle,
                                decoration: InputDecoration(
                                  labelText: 'Task due:',
                                  labelStyle: labelStyle,
                                ),
                                initialValue: DateTime.now(),
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
                                inputType:
                                    CupertinoDateTimePickerInputType.time,
                                style: inputStyle,
                                decoration: InputDecoration(
                                  labelText: 'Estimate:',
                                  labelStyle: labelStyle,
                                ),
                                initialValue:
                                    DateTime.fromMillisecondsSinceEpoch(0,
                                        isUtc: true),
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
                            ],
                          ),
                        ),
                        ClipRRect(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(8.0)),
                          child: EditorWidget(
                            controller: _controller,
                            focusNode: _focusNode,
                            saveFn: _save,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
