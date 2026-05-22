import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboard_widget.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/habits/state/habit_completion_controller.dart';
import 'package:lotti/features/habits/ui/widgets/habit_day_strip.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/utils/platform.dart';
import 'package:lotti/widgets/charts/utils.dart';
import 'package:lotti/widgets/date_time/datetime_field.dart';
import 'package:url_launcher/url_launcher.dart';

class HabitDialog extends ConsumerStatefulWidget {
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
  ConsumerState<HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends ConsumerState<HabitDialog> {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();

  bool _startReset = false;

  final hotkeyCmdS = HotKey(
    key: LogicalKeyboardKey.keyS,
    modifiers: [HotKeyModifier.meta],
    scope: HotKeyScope.inapp,
  );

  Future<void> _saveHabit(HabitCompletionType completionType) async {
    _formKey.currentState!.save();
    Navigator.pop(context);

    if (!_validate()) {
      return;
    }
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
        keyDownHandler: (hotKey) => _saveHabit(HabitCompletionType.success),
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

  bool _validate() {
    final formState = _formKey.currentState;
    if (formState != null) {
      return formState.validate();
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

    final tokens = widget.themeData.extension<DsTokens>() ?? dsTokensDark;
    final themeWithTokens = widget.themeData.extension<DsTokens>() != null
        ? widget.themeData
        : widget.themeData.copyWith(
            extensions: <ThemeExtension<dynamic>>[tokens],
          );

    final stripRangeStart = DateTime.now().dayAtMidnight.subtract(
      const Duration(days: 6),
    );
    final stripRangeEnd = getEndOfToday();
    final stripResults = ref
        .watch(
          habitCompletionControllerProvider(
            habitId: widget.habitId,
            rangeStart: stripRangeStart,
            rangeEnd: stripRangeEnd,
          ),
        )
        .value;

    final dashboardRangeStart = DateTime.now().dayAtMidnight.subtract(
      Duration(days: isDesktop ? 30 : 14),
    );

    return Theme(
      data: themeWithTokens,
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
                    rangeStart: dashboardRangeStart,
                    rangeEnd: getEndOfToday(),
                    dashboardId: habitDefinition.dashboardId!,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              heightFactor: habitDefinition.dashboardId != null ? 10 : 1,
              child: Material(
                color: tokens.colors.background.level02,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(tokens.radii.xl),
                  ),
                  side: BorderSide(color: tokens.colors.decorative.level01),
                ),
                elevation: 10,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 500,
                    minWidth: isMobile
                        ? MediaQuery.of(context).size.width
                        : 250,
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      tokens.spacing.step5,
                      tokens.spacing.step2,
                      tokens.spacing.step3,
                      tokens.spacing.step3,
                    ),
                    child: FormBuilder(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  habitDefinition.name,
                                  style: tokens
                                      .typography
                                      .styles
                                      .subtitle
                                      .subtitle1
                                      .copyWith(
                                        color: tokens.colors.text.highEmphasis,
                                      ),
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.all(tokens.spacing.step2),
                                icon: Semantics(
                                  label: 'close habit completion',
                                  child: const Icon(Icons.close_rounded),
                                ),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          if (stripResults != null && stripResults.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.only(
                                top: tokens.spacing.step1,
                                bottom: tokens.spacing.step3,
                              ),
                              child: HabitDayStrip(
                                results: stripResults,
                                semanticPrefix: habitDefinition.name,
                              ),
                            ),
                          if (habitDefinition.description.isNotEmpty)
                            HabitDescription(habitDefinition),
                          SizedBox(height: tokens.spacing.step2),
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
                          SizedBox(height: tokens.spacing.step2),
                          FormBuilderTextField(
                            initialValue: '',
                            key: const Key('habit_comment_field'),
                            decoration: createDialogInputDecoration(
                              labelText: context.messages.addHabitCommentLabel,
                              themeData: Theme.of(context),
                            ),
                            minLines: 1,
                            maxLines: 10,
                            keyboardAppearance: Theme.of(context).brightness,
                            name: 'comment',
                          ),
                          SizedBox(height: tokens.spacing.step3),
                          _DialogActions(
                            onFail: () => _saveHabit(HabitCompletionType.fail),
                            onSkip: () => _saveHabit(HabitCompletionType.skip),
                            onSuccess: () =>
                                _saveHabit(HabitCompletionType.success),
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

class _DialogActions extends StatelessWidget {
  const _DialogActions({
    required this.onFail,
    required this.onSkip,
    required this.onSuccess,
  });

  final VoidCallback onFail;
  final VoidCallback onSkip;
  final VoidCallback onSuccess;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Row(
      children: [
        _OutlineAction(
          key: const Key('habit_fail'),
          label: context.messages.completeHabitFailButton,
          color: tokens.colors.alert.error.defaultColor,
          onPressed: onFail,
        ),
        SizedBox(width: tokens.spacing.step2),
        _OutlineAction(
          key: const Key('habit_skip'),
          label: context.messages.completeHabitSkipButton,
          color: tokens.colors.alert.warning.defaultColor,
          onPressed: onSkip,
        ),
        const Spacer(),
        _FilledAction(
          key: const Key('habit_save'),
          label: context.messages.completeHabitSuccessButton,
          onPressed: onSuccess,
        ),
      ],
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({
    required this.label,
    required this.color,
    required this.onPressed,
    super.key,
  });

  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
        side: BorderSide(color: color, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step4,
            vertical: tokens.spacing.step2,
          ),
          child: Text(
            label,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _FilledAction extends StatelessWidget {
  const _FilledAction({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;

    return Material(
      color: teal,
      borderRadius: BorderRadius.circular(tokens.radii.badgesPills),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step5,
            vertical: tokens.spacing.step2,
          ),
          child: Text(
            label,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.onInteractiveAlert,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class HabitDescription extends StatelessWidget {
  const HabitDescription(this.habitDefinition, {super.key});

  final HabitDefinition? habitDefinition;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

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
        DevLogger.warning(
          name: 'HabitDialog',
          message: 'Could not launch $uri',
        );
      }
    }

    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step2),
      child: Linkify(
        onOpen: onOpen,
        text: '${habitDefinition?.description}',
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
        linkStyle: tokens.typography.styles.body.bodyMedium.copyWith(
          color: tokens.colors.interactive.enabled,
        ),
      ),
    );
  }
}
