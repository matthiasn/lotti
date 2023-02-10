import 'package:beamer/beamer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/form_builder/cupertino_datepicker.dart';
import 'package:url_launcher/url_launcher.dart';

class HabitDialog extends StatefulWidget {
  const HabitDialog({
    required this.habitId,
    required this.beamerDelegate,
    super.key,
    this.data,
  });

  final String habitId;
  final Object? data;

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

  Future<void> saveHabit(HabitCompletionType completionType) async {
    _formKey.currentState!.save();
    if (validate()) {
      final formData = _formKey.currentState?.value;
      final habitDefinition = await _db.watchHabitById(widget.habitId).first;
      final formDate = formData!['date'] as DateTime;

      final habitCompletion = HabitCompletionData(
        habitId: widget.habitId,
        dateTo: formDate == _started && widget.data == null
            ? DateTime.now()
            : formDate,
        dateFrom: formDate,
        completionType: completionType,
      );

      await persistenceLogic.createHabitCompletionEntry(
        data: habitCompletion,
        comment: formData['comment'] as String,
        habitDefinition: habitDefinition,
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

    _started = widget.data != null &&
            widget.data is String &&
            ymd(DateTime.now()) != widget.data
        ? DateTime.parse(widget.data.toString()).add(
            const Duration(
              hours: 23,
              minutes: 59,
              seconds: 59,
            ),
          )
        : DateTime.now();

    hotKeyManager.register(
      hotkeyCmdS,
      keyDownHandler: (hotKey) => saveHabit(HabitCompletionType.success),
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

  late final DateTime _started;

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

        if (habitDefinition == null) {
          return const SizedBox.shrink();
        }

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
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actionsPadding: const EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: 20,
          ),
          actions: [
            TextButton(
              key: const Key('habit_fail'),
              onPressed: () => saveHabit(HabitCompletionType.fail),
              child: Text(
                localizations.completeHabitFailButton,
                style: saveButtonStyle(),
              ),
            ),
            TextButton(
              key: const Key('habit_skip'),
              onPressed: () => saveHabit(HabitCompletionType.skip),
              child: Text(
                localizations.completeHabitSkipButton,
                style: saveButtonStyle()
                    .copyWith(color: styleConfig().secondaryTextColor),
              ),
            ),
            TextButton(
              key: const Key('habit_save'),
              onPressed: () => saveHabit(HabitCompletionType.success),
              child: Text(
                localizations.completeHabitSuccessButton,
                style: saveButtonStyle()
                    .copyWith(color: styleConfig().primaryColor),
              ),
            ),
          ],
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: FormBuilder(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onChanged: () {
                setState(() {
                  dirty = true;
                });
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          habitDefinition.name,
                          style: habitCompletionHeaderStyle,
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
                  HabitDescription(habitDefinition),
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        inputSpacer,
                        FormBuilderCupertinoDateTimePicker(
                          name: 'date',
                          alwaysUse24HourFormat: true,
                          format: DateFormat(
                            "MMMM d, yyyy 'at' HH:mm",
                          ),
                          style: newInputStyle().copyWith(color: Colors.black),
                          decoration: inputDecorationWithLabel(
                            localizations.addHabitDateLabel,
                          ),
                          initialValue: _started,
                          theme: datePickerTheme(),
                        ),
                        inputSpacer,
                        FormBuilderTextField(
                          initialValue: '',
                          key: const Key('habit_comment_field'),
                          decoration: inputDecorationWithLabel(
                            localizations.addHabitCommentLabel,
                          ),
                          minLines: 1,
                          maxLines: 10,
                          keyboardAppearance: keyboardAppearance(),
                          style: newInputStyle().copyWith(color: Colors.black),
                          name: 'comment',
                        ),
                      ],
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

class HabitDescription extends StatelessWidget {
  const HabitDescription(this.habitDefinition, {super.key});
  final HabitDefinition? habitDefinition;

  @override
  Widget build(BuildContext context) {
    if ('${habitDefinition?.description}'.isEmpty) {
      return const SizedBox.shrink();
    }

    Future<void> onOpen(LinkableElement link) async {
      final uri = Uri.tryParse(link.url);

      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        getIt<LoggingDb>().captureEvent(
          'Could not launch $uri',
          domain: 'HABIT_COMPLETION',
          subDomain: 'Click Link in Description',
        );
        debugPrint('Could not launch $uri');
      }
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Linkify(
        onOpen: onOpen,
        text: '${habitDefinition?.description}',
        style: habitCompletionHeaderStyle.copyWith(fontSize: 15),
        linkStyle: habitCompletionHeaderStyle.copyWith(
          fontSize: fontSizeMedium,
          color: styleConfig().primaryColor,
        ),
      ),
    );
  }
}
