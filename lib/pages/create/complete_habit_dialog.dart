import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/dashboards/ui/widgets/dashboard_widget.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/ds_segmented_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/ds_surface_elevation.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
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
    this.showLinkedDashboard = true,
    super.key,
  });

  final String habitId;
  final String? dateString;
  final ThemeData themeData;

  /// Whether to embed the habit's linked dashboard above the completion form.
  /// Suppressed when the dialog is opened from within that same dashboard,
  /// where it is already on screen.
  final bool showLinkedDashboard;

  @override
  State<HabitDialog> createState() => _HabitDialogState();
}

class _HabitDialogState extends State<HabitDialog> {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();
  final _formKey = GlobalKey<FormBuilderState>();

  bool _startReset = false;

  /// The outcome the [DsSegmentedToggle] currently selects; the Record button
  /// (and the Cmd+S shortcut) persist with this. Defaults to success — the
  /// overwhelmingly common case — so the happy path is a single tap.
  HabitCompletionType _outcome = HabitCompletionType.success;

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
        keyDownHandler: (hotKey) => saveHabit(_outcome),
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

    final rangeStart = DateTime.now().dayAtMidnight.subtract(
      Duration(days: timeSpanDays),
    );

    final rangeEnd = getEndOfToday();

    // Only embed the linked dashboard when the caller wants it (suppressed when
    // the dialog opens from within that dashboard) and the habit actually has
    // one.
    final showLinkedDashboard =
        widget.showLinkedDashboard && habitDefinition.dashboardId != null;

    final form = _CompletionForm(
      formKey: _formKey,
      habitDefinition: habitDefinition,
      started: _started,
      outcome: _outcome,
      onOutcomeChanged: (value) => setState(() => _outcome = value),
      onPickDate: (picked) {
        setState(() {
          _startReset = true;
          _started = picked;
        });
      },
      onClose: () => Navigator.pop(context),
      onRecord: () => saveHabit(_outcome),
    );

    return Theme(
      data: widget.themeData,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: showLinkedDashboard
            ? SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DashboardWidget(
                      rangeStart: rangeStart,
                      rangeEnd: rangeEnd,
                      dashboardId: habitDefinition.dashboardId!,
                    ),
                    form,
                  ],
                ),
              )
            : GestureDetector(
                // The form floats on a transparent sheet; make a tap on the
                // empty space around it close the dialog (the scrim above the
                // sheet isn't reachable here), as is conventional in the app.
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  // Swallow taps on the form itself so they don't bubble up and
                  // dismiss it.
                  child: GestureDetector(
                    onTap: () {},
                    child: form,
                  ),
                ),
              ),
      ),
    );
  }
}

/// The completion-capture card: habit name, optional description, the date
/// being recorded, an optional note, the outcome segmented picker, and the
/// primary Record action. Split from [HabitDialog] so the form layout reads on
/// its own and the dialog keeps only the state/persistence wiring.
class _CompletionForm extends StatelessWidget {
  const _CompletionForm({
    required this.formKey,
    required this.habitDefinition,
    required this.started,
    required this.outcome,
    required this.onOutcomeChanged,
    required this.onPickDate,
    required this.onClose,
    required this.onRecord,
  });

  final GlobalKey<FormBuilderState> formKey;
  final HabitDefinition habitDefinition;
  final DateTime started;
  final HabitCompletionType outcome;
  final ValueChanged<HabitCompletionType> onOutcomeChanged;
  final ValueChanged<DateTime> onPickDate;
  final VoidCallback onClose;
  final VoidCallback onRecord;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: dsCardSurface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radii.xl),
        ),
        side: BorderSide(color: tokens.colors.decorative.level01),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500,
          minWidth: isMobile ? MediaQuery.of(context).size.width : 250,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.step6,
            tokens.spacing.step4,
            tokens.spacing.step4,
            tokens.spacing.step5,
          ),
          child: FormBuilder(
            key: formKey,
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
                        style: tokens.typography.styles.subtitle.subtitle1
                            .copyWith(color: tokens.colors.text.highEmphasis),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.all(tokens.spacing.step3),
                      icon: Semantics(
                        label: 'close habit completion',
                        child: const Icon(Icons.close_rounded),
                      ),
                      onPressed: onClose,
                    ),
                  ],
                ),
                if (habitDefinition.description.isNotEmpty)
                  HabitDescription(habitDefinition),
                SizedBox(height: tokens.spacing.step4),
                DateTimeField(
                  dateTime: started,
                  labelText: messages.addHabitDateLabel,
                  setDateTime: onPickDate,
                ),
                SizedBox(height: tokens.spacing.step4),
                FormBuilderTextField(
                  initialValue: '',
                  key: const Key('habit_comment_field'),
                  decoration: createDialogInputDecoration(
                    labelText: messages.addHabitCommentLabel,
                    themeData: Theme.of(context),
                  ),
                  minLines: 1,
                  maxLines: 10,
                  keyboardAppearance: Theme.of(context).brightness,
                  name: 'comment',
                ),
                SizedBox(height: tokens.spacing.step5),
                SizedBox(
                  width: double.infinity,
                  child: DsSegmentedToggle<HabitCompletionType>(
                    expand: true,
                    selected: outcome,
                    onChanged: onOutcomeChanged,
                    // Positive-first reading order: the pre-selected Success
                    // leads, the negative "Missed" is tucked last, so the
                    // common, encouraging outcome is what the eye meets first.
                    segments: [
                      DsSegment(
                        HabitCompletionType.success,
                        messages.completeHabitSuccessButton,
                      ),
                      DsSegment(
                        HabitCompletionType.skip,
                        messages.completeHabitSkipButton,
                      ),
                      DsSegment(
                        HabitCompletionType.fail,
                        messages.completeHabitFailButton,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: tokens.spacing.step4),
                DesignSystemButton(
                  key: const Key('habit_save'),
                  label: messages.habitsRecordButton,
                  onPressed: onRecord,
                  fullWidth: true,
                  size: DesignSystemButtonSize.large,
                ),
              ],
            ),
          ),
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
        getIt<DomainLogger>().log(
          LogDomain.habits,
          'Could not launch $uri',
          subDomain: 'Click Link in Description',
        );
        DevLogger.warning(
          name: 'HabitDialog',
          message: 'Could not launch $uri',
        );
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
