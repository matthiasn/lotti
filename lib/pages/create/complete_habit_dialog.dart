import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboard_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:tinycolor2/tinycolor2.dart';
import 'package:url_launcher/url_launcher.dart';

class HabitDialog extends StatefulWidget {
  const HabitDialog({
    required this.habitId,
    required this.themeData,
    this.dateString,
    super.key,
  });

  final String habitId;
  final String? dateString;
  final ThemeData themeData;

  @override
  State<HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends State<HabitDialog> {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();

  bool _startReset = false;

  final hotkeyCmdS = HotKey(
    key: LogicalKeyboardKey.keyS,
    modifiers: [HotKeyModifier.meta],
    scope: HotKeyScope.inapp,
  );

  Future<void> saveHabit(HabitCompletionType completionType) async {
    _formKey.currentState!.save();
    Navigator.pop(context);

    if (validate()) {
      final formData = _formKey.currentState?.value;
      final habitDefinition = getIt<EntitiesCacheService>().getHabitById(
        widget.habitId,
      );

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
        widget.dateString is String && DateTime.now().ymd != widget.dateString
            ? endOfDay()
            : DateTime.now();

    if (isDesktop) {
      hotKeyManager.register(
        hotkeyCmdS,
        keyDownHandler: (hotKey) => saveHabit(HabitCompletionType.success),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
    if (isDesktop) {
      hotKeyManager.unregister(hotkeyCmdS);
    }
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
    final habitDefinition = getIt<EntitiesCacheService>().getHabitById(
      widget.habitId,
    );

    if (habitDefinition == null) {
      return const SizedBox.shrink();
    }
    final timeSpanDays = isDesktop ? 30 : 14;

    final rangeStart =
        DateTime.now().dayAtMidnight.subtract(Duration(days: timeSpanDays));

    final rangeEnd = getEndOfToday();

    return Theme(
      data: widget.themeData,
      child: Padding(
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
                margin: EdgeInsets.zero,
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  side: BorderSide(
                    color: (context.textTheme.titleLarge?.color ?? Colors.black)
                        .withAlpha(127),
                  ),
                ),
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
                                icon: Semantics(
                                  label: 'close habit completion',
                                  child: const Icon(Icons.close_rounded),
                                ),
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
                                  labelText: context.messages.addHabitDateLabel,
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
                                        context.messages.addHabitCommentLabel,
                                    themeData: Theme.of(context),
                                  ),
                                  minLines: 1,
                                  maxLines: 10,
                                  keyboardAppearance:
                                      Theme.of(context).brightness,
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  key: const Key('habit_fail'),
                                  onPressed: () =>
                                      saveHabit(HabitCompletionType.fail),
                                  child: Text(
                                    context.messages.completeHabitFailButton,
                                    style: failButtonStyle(),
                                  ),
                                ),
                                TextButton(
                                  key: const Key('habit_skip'),
                                  onPressed: () =>
                                      saveHabit(HabitCompletionType.skip),
                                  child: Text(
                                    context.messages.completeHabitSkipButton,
                                    style: saveButtonStyle(Theme.of(context))
                                        .copyWith(
                                      color: habitSkipColor
                                          .desaturate(40)
                                          .withAlpha(204),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  key: const Key('habit_save'),
                                  onPressed: () => saveHabit(
                                    HabitCompletionType.success,
                                  ),
                                  child: Text(
                                    context.messages.completeHabitSuccessButton,
                                    style: saveButtonStyle(Theme.of(context))
                                        .copyWith(
                                      color: successColor,
                                    ),
                                  ),
                                ).animate(autoPlay: true).shimmer(
                                      delay: 1.seconds,
                                      duration: .7.seconds,
                                      color: Theme.of(context).cardColor,
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
      ),
    );
  }
}

class HabitDescription extends StatelessWidget {
  const HabitDescription(
    this.habitDefinition, {
    super.key,
  });

  final HabitDefinition? habitDefinition;

  @override
  Widget build(BuildContext context) {
    Future<void> onOpen(LinkableElement link) async {
      final uri = Uri.tryParse(link.url);

      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        getIt<LoggingService>().captureEvent(
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
          color: Theme.of(context).primaryColor.darken(25),
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
