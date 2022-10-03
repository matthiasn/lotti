import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/form_builder/cupertino_datepicker.dart';

class HabitDialog extends StatefulWidget {
  const HabitDialog({
    super.key,
    required this.habitId,
    required this.beamerDelegate,
  });

  final String habitId;
  final BeamerDelegate beamerDelegate;

  @override
  State<HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends State<HabitDialog> {
  final JournalDb _db = getIt<JournalDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();
  bool dirty = true;

  final hotkeyCmdS = HotKey(
    KeyCode.keyS,
    modifiers: [KeyModifier.meta],
    scope: HotKeyScope.inapp,
  );

  Future<void> saveHabit() async {
    _formKey.currentState!.save();
    if (validate()) {
      final formData = _formKey.currentState?.value;

      final habitCompletion = HabitCompletionData(
        habitId: widget.habitId,
        dateTo: formData!['date'] as DateTime,
        dateFrom: formData['date'] as DateTime,
      );

      await persistenceLogic.createHabitCompletionEntry(
        data: habitCompletion,
        comment: formData['comment'] as String,
      );

      setState(() {
        dirty = false;
      });

      widget.beamerDelegate.beamBack();
    }
  }

  @override
  void initState() {
    super.initState();

    hotKeyManager.register(
      hotkeyCmdS,
      keyDownHandler: (hotKey) => saveHabit(),
    );
  }

  @override
  void dispose() {
    super.dispose();
    hotKeyManager.unregister(hotkeyCmdS);
  }

  bool validate() {
    if (_formKey.currentState != null) {
      return _formKey.currentState!.validate();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<HabitDefinition?>(
      stream: _db.watchHabitById(widget.habitId),
      builder: (
        BuildContext context,
        AsyncSnapshot<HabitDefinition?> snapshot,
      ) {
        final habitDefinition = snapshot.data;

        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          contentPadding: const EdgeInsets.only(
            left: 30,
            top: 20,
            right: 10,
            bottom: 20,
          ),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(50)),
          ),
          backgroundColor: styleConfig().primaryColorLight,
          actionsAlignment: MainAxisAlignment.end,
          actionsPadding: const EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: 20,
          ),
          actions: [
            if (dirty && validate())
              TextButton(
                key: const Key('habit_save'),
                onPressed: saveHabit,
                child: Text(
                  localizations.addMeasurementSaveButton,
                  style: saveButtonStyle(),
                ),
              ),
          ],
          content: FormBuilder(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onChanged: () {
              setState(() {
                dirty = true;
              });
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      habitDefinition?.name ?? '',
                      style: const TextStyle(
                        color: Colors.black,
                        fontFamily: mainFont,
                        fontSize: 20,
                      ),
                    ),
                    IconButton(
                      padding: const EdgeInsets.all(10),
                      icon: SvgPicture.asset('assets/icons/close.svg'),
                      hoverColor: Colors.transparent,
                      onPressed: widget.beamerDelegate.beamBack,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      FormBuilderCupertinoDateTimePicker(
                        name: 'date',
                        alwaysUse24HourFormat: true,
                        format: DateFormat(
                          "MMMM d, yyyy 'at' HH:mm",
                        ),
                        style: newInputStyle().copyWith(color: Colors.black),
                        decoration: InputDecoration(
                          fillColor: styleConfig().negspace,
                          labelText: localizations.addHabitDateLabel,
                          labelStyle:
                              newLabelStyle().copyWith(color: Colors.black),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                        ),
                        initialValue: DateTime.now(),
                        theme: datePickerTheme(),
                      ),
                      FormBuilderTextField(
                        initialValue: '',
                        key: const Key('habit_comment_field'),
                        decoration: InputDecoration(
                          labelText: localizations.addHabitCommentLabel,
                          labelStyle:
                              newLabelStyle().copyWith(color: Colors.black),
                          floatingLabelBehavior: FloatingLabelBehavior.always,
                        ),
                        keyboardAppearance: Brightness.light,
                        style: newInputStyle().copyWith(color: Colors.black),
                        name: 'comment',
                      ),
                    ],
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
