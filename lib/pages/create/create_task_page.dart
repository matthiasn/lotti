import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:lotti/classes/task.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/app_bar/title_app_bar.dart';
import 'package:lotti/widgets/journal/editor/editor_tools.dart';
import 'package:lotti/widgets/tasks/task_form.dart';

class CreateTaskPage extends StatefulWidget {
  const CreateTaskPage({
    super.key,
    @PathParam() this.linkedId,
  });

  final String? linkedId;

  @override
  State<CreateTaskPage> createState() => _CreateTaskPageState();
}

class _CreateTaskPageState extends State<CreateTaskPage> {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final formKey = GlobalKey<FormBuilderState>();
  final quill.QuillController _controller = makeController();
  final FocusNode _focusNode = FocusNode();
  DateTime started = DateTime.now();

  @override
  void initState() {
    super.initState();
  }

  Future<void> _save() async {
    formKey.currentState!.save();
    if (formKey.currentState!.validate()) {
      final now = DateTime.now();

      final formData = formKey.currentState?.value;
      // final DateTime due = formData!['due'];
      final title = formData!['title'] as String;
      final dt = formData['estimate'] as DateTime;
      final estimate = Duration(
        hours: dt.hour,
        minutes: dt.minute,
      );
      final status = formData['status'] as String;

      final taskData = TaskData(
        // due: due,
        status: taskStatusFromString(status),
        title: title,
        statusHistory: [],
        dateTo: now,
        dateFrom: started,
        estimate: estimate,
      );

      await persistenceLogic.createTaskEntry(
        data: taskData,
        entryText: entryTextFromController(_controller),
        linkedId: widget.linkedId,
      );
      await context.router.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: TitleAppBar(
        title: localizations.addTaskTitle,
      ),
      backgroundColor: AppColors.bodyBgColor,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8),
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
                  withOpenDetails: true,
                ),
              ),
              TextButton(
                onPressed: _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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
        ),
      ),
    );
  }
}
