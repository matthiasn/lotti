import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/dashboards/dashboard_widget.dart';
import 'package:lotti/widgets/misc/datetime_bottom_sheet.dart';
import 'package:tinycolor2/tinycolor2.dart';
import 'package:url_launcher/url_launcher.dart';

class HabitDialog extends StatefulWidget {
  const HabitDialog({
    required this.habitId,
    super.key,
    this.data,
  });

  final String habitId;
  final Object? data;

  @override
  State<HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends State<HabitDialog> {
  final JournalDb _db = getIt<JournalDb>();
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();

  bool _startReset = false;

  final hotkeyCmdS = HotKey(
    KeyCode.keyS,
    modifiers: [KeyModifier.meta],
    scope: HotKeyScope.inapp,
  );

  Future<void> saveHabit(HabitCompletionType completionType) async {
    _formKey.currentState!.save();
    Navigator.pop(context);

    if (validate()) {
      final formData = _formKey.currentState?.value;
      final habitDefinition = await _db.watchHabitById(widget.habitId).first;

      final habitCompletion = HabitCompletionData(
        habitId: widget.habitId,
        dateTo: !_startReset ? DateTime.now() : _started,
        dateFrom: _started,
        completionType: completionType,
      );

      await persistenceLogic.createHabitCompletionEntry(
        data: habitCompletion,
        comment: formData!['comment'] as String,
        habitDefinition: habitDefinition,
      );
    }
  }

  @override
  void initState() {
    super.initState();

    DateTime endOfDay() {
      final date = DateTime.parse(widget.data.toString());
      return DateTime(date.year, date.month, date.day, 23, 59, 59);
    }

    _started = widget.data != null &&
            widget.data is String &&
            ymd(DateTime.now()) != widget.data
        ? endOfDay()
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

  late DateTime _started;

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
        final timeSpanDays = isDesktop ? 30 : 14;

        final rangeStart = getStartOfDay(
          DateTime.now().subtract(Duration(days: timeSpanDays)),
        );

        final rangeEnd = getEndOfToday();

        return SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 50),
              AlertDialog(
                insetPadding: const EdgeInsets.symmetric(horizontal: 32),
                contentPadding: const EdgeInsets.only(
                  left: 30,
                  top: 10,
                  right: 10,
                  bottom: 10,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(20)),
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
                      style: failButtonStyle(),
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
                      style: saveButtonStyle().copyWith(
                        color: styleConfig().primaryColor.darken(25),
                      ),
                    ),
                  ),
                ],
                content: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 600,
                    minWidth: 280,
                  ),
                  child: FormBuilder(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
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
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
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
                              DateTimeField(
                                dateTime: _started,
                                labelText: localizations.addHabitDateLabel,
                                style: newInputStyle()
                                    .copyWith(color: Colors.black),
                                setDateTime: (picked) {
                                  setState(() {
                                    _startReset = true;
                                    _started = picked;
                                  });
                                },
                              ),
                              inputSpacer,
                              FormBuilderTextField(
                                initialValue: '',
                                key: const Key('habit_comment_field'),
                                decoration: createDialogInputDecoration(
                                  labelText: localizations.addHabitCommentLabel,
                                ),
                                minLines: 1,
                                maxLines: 10,
                                keyboardAppearance: keyboardAppearance(),
                                style: newInputStyle()
                                    .copyWith(color: Colors.black),
                                name: 'comment',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (habitDefinition.dashboardId != null)
                DashboardWidget(
                  rangeStart: rangeStart,
                  rangeEnd: rangeEnd,
                  dashboardId: habitDefinition.dashboardId!,
                ),
            ],
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
        style: habitCompletionHeaderStyle.copyWith(fontSize: fontSizeMedium),
        linkStyle: habitCompletionHeaderStyle.copyWith(
          fontSize: fontSizeMedium,
          color: styleConfig().primaryColor.darken(25),
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
