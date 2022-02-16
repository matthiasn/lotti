import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/editor_tools.dart';
import 'package:lotti/widgets/tasks/task_form.dart';

class NewTaskPage extends StatefulWidget {
  const NewTaskPage({
    Key? key,
    this.linked,
    this.journalEntity,
  }) : super(key: key);

  final JournalEntity? linked;
  final JournalEntity? journalEntity;

  @override
  State<NewTaskPage> createState() => _NewTaskPageState();
}

class _NewTaskPageState extends State<NewTaskPage> {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final formKey = GlobalKey<FormBuilderState>();
  final quill.QuillController _controller = makeController();
  final FocusNode _focusNode = FocusNode();
  DateTime started = DateTime.now();

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
        dateTo: now,
        dateFrom: started,
        estimate: estimate,
      );

      persistenceLogic.createTaskEntry(
        data: taskData,
        entryText: entryTextFromController(_controller),
        linked: widget.linked,
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  focusOnTitle: true,
                  saveFn: _save,
                  journalEntity: widget.journalEntity,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
