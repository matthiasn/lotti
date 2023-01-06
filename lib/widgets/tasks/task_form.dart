// ignore_for_file: avoid_dynamic_calls

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/form_builder/cupertino_datepicker.dart';
import 'package:lotti/widgets/journal/editor/editor_widget.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class TaskForm extends StatefulWidget {
  const TaskForm({
    super.key,
    this.task,
    this.data,
    this.focusOnTitle = false,
  });

  final TaskData? data;
  final Task? task;
  final bool focusOnTitle;

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocBuilder<EntryCubit, EntryState>(
      builder: (
        context,
        EntryState snapshot,
      ) {
        final save = context.read<EntryCubit>().save;
        final formKey = context.read<EntryCubit>().formKey;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12),
              child: FormBuilder(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  children: <Widget>[
                    RawKeyboardListener(
                      focusNode: FocusNode(),
                      onKey: (RawKeyEvent event) {
                        if (event.data.isMetaPressed &&
                            event.character == 's') {
                          save();
                        }
                      },
                      child: FormBuilderTextField(
                        autofocus: widget.focusOnTitle,
                        initialValue: widget.data?.title ?? '',
                        decoration: InputDecoration(
                          labelText: '${widget.data?.title}'.isEmpty
                              ? localizations.taskNameLabel
                              : '',
                          labelStyle: labelStyle(),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        keyboardAppearance: keyboardAppearance(),
                        maxLines: null,
                        style: inputStyle().copyWith(
                          fontSize: 25,
                          fontWeight: FontWeight.normal,
                        ),
                        name: 'title',
                        onChanged: context.read<EntryCubit>().setDirty,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 120,
                          child: FormBuilderCupertinoDateTimePicker(
                            name: 'estimate',
                            alwaysUse24HourFormat: true,
                            format: hhMmFormat,
                            inputType: CupertinoDateTimePickerInputType.time,
                            style: inputStyle(),
                            onChanged: (_) => save(),
                            decoration: InputDecoration(
                              labelText: localizations.taskEstimateLabel,
                              labelStyle: labelStyle(),
                            ),
                            initialValue: DateTime.fromMillisecondsSinceEpoch(
                              widget.data?.estimate?.inMilliseconds ?? 0,
                              isUtc: true,
                            ),
                            theme: datePickerTheme(),
                          ),
                        ),
                        SizedBox(
                          width: 160,
                          child: FormBuilderDropdown<String>(
                            name: 'status',
                            borderRadius: BorderRadius.circular(20),
                            onChanged: (dynamic _) => save(),
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
                            items: [
                              DropdownMenuItem<String>(
                                value: 'OPEN',
                                child: TaskStatusLabel(
                                  localizations.taskStatusOpen,
                                ),
                              ),
                              DropdownMenuItem<String>(
                                value: 'GROOMED',
                                child: TaskStatusLabel(
                                  localizations.taskStatusGroomed,
                                ),
                              ),
                              DropdownMenuItem<String>(
                                value: 'IN PROGRESS',
                                child: TaskStatusLabel(
                                  localizations.taskStatusInProgress,
                                ),
                              ),
                              DropdownMenuItem<String>(
                                value: 'BLOCKED',
                                child: TaskStatusLabel(
                                  localizations.taskStatusBlocked,
                                ),
                              ),
                              DropdownMenuItem<String>(
                                value: 'ON HOLD',
                                child: TaskStatusLabel(
                                  localizations.taskStatusOnHold,
                                ),
                              ),
                              DropdownMenuItem<String>(
                                value: 'DONE',
                                child: TaskStatusLabel(
                                  localizations.taskStatusDone,
                                ),
                              ),
                              DropdownMenuItem<String>(
                                value: 'REJECTED',
                                child: TaskStatusLabel(
                                  localizations.taskStatusRejected,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            const EditorWidget(),
          ],
        );
      },
    );
  }
}

class TaskStatusLabel extends StatelessWidget {
  const TaskStatusLabel(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: inputStyle(),
    );
  }
}
