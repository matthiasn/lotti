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
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:tinycolor2/tinycolor2.dart';
import 'package:url_launcher/url_launcher.dart';

class HabitDialog extends StatefulWidget {
  const HabitDialog({
    required this.habitId,
    this.dateString,
    super.key,
  });

  final String habitId;
  final String? dateString;

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
      final date = DateTime.parse(widget.dateString.toString());
      return DateTime(date.year, date.month, date.day, 23, 59, 59);
    }

    _started =
        widget.dateString is String && ymd(DateTime.now()) != widget.dateString
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

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Stack(
            children: [
              if (habitDefinition.dashboardId != null)
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 280),
                    child: DashboardWidget(
                      rangeStart: rangeStart,
                      rangeEnd: rangeEnd,
                      dashboardId: habitDefinition.dashboardId!,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                heightFactor: habitDefinition.dashboardId != null ? 10 : 1,
                child: Card(
                  elevation: 10,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  color: styleConfig().primaryColorLight.darken(5),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: 500,
                      minWidth:
                          isMobile ? MediaQuery.of(context).size.width : 250,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 30,
                        top: 5,
                        right: 10,
                        bottom: 5,
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
                            if (habitDefinition.description.isNotEmpty)
                              HabitDescription(habitDefinition),
                            Padding(
                              padding: const EdgeInsets.only(right: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  inputSpacerSmall,
                                  DateTimeField(
                                    dateTime: _started,
                                    labelText: localizations.addHabitDateLabel,
                                    style: dialogInputStyle(),
                                    setDateTime: (picked) {
                                      setState(() {
                                        _startReset = true;
                                        _started = picked;
                                      });
                                    },
                                  ),
                                  inputSpacerSmall,
                                  FormBuilderTextField(
                                    initialValue: '',
                                    key: const Key('habit_comment_field'),
                                    decoration: createDialogInputDecoration(
                                      labelText:
                                          localizations.addHabitCommentLabel,
                                      style: dialogInputStyle(),
                                    ),
                                    minLines: 1,
                                    maxLines: 10,
                                    keyboardAppearance: keyboardAppearance(),
                                    style: dialogInputStyle(),
                                    name: 'comment',
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 20,
                                right: 20,
                                top: 5,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  TextButton(
                                    key: const Key('habit_fail'),
                                    onPressed: () =>
                                        saveHabit(HabitCompletionType.fail),
                                    child: Text(
                                      localizations.completeHabitFailButton,
                                      style: failButtonStyle(),
                                    ),
                                  ),
                                  TextButton(
                                    key: const Key('habit_skip'),
                                    onPressed: () =>
                                        saveHabit(HabitCompletionType.skip),
                                    child: Text(
                                      localizations.completeHabitSkipButton,
                                      style: saveButtonStyle().copyWith(
                                        color: styleConfig().secondaryTextColor,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    key: const Key('habit_save'),
                                    onPressed: () =>
                                        saveHabit(HabitCompletionType.success),
                                    child: Text(
                                      localizations.completeHabitSuccessButton,
                                      style: saveButtonStyle().copyWith(
                                        color: styleConfig()
                                            .primaryColor
                                            .darken(25),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
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
