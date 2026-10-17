import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/person_name.dart';
import 'package:lotti/features/relationships/repository/person_timeline_repository.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_duration_picker.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_meta_summary_line.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_pickers.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:material_ui/material_ui.dart';

/// Opens the sheet that plans a meeting with [person]: what it is, when it
/// starts and how long it runs. Saving writes a planned event on their
/// timeline, which the Daily OS Day view shows on its day.
Future<void> showPersonMeetingSheet({
  required BuildContext context,
  required RelationshipEntry person,
}) {
  return DsActionModal.show<void>(
    context: context,
    title: context.messages.relationshipPlanMeeting(person.shortName),
    builder: (sheetContext) => PersonMeetingForm(person: person),
  );
}

/// The meeting sheet's body: the title, the when and the how long as the
/// composer's own fact tags, and the sheet's actions.
class PersonMeetingForm extends ConsumerStatefulWidget {
  const PersonMeetingForm({required this.person, super.key});

  final RelationshipEntry person;

  /// How long a new meeting runs until the user says otherwise.
  static const defaultDuration = Duration(hours: 1);

  /// When a new meeting starts until the user says otherwise: tomorrow, at
  /// the next full hour — a time that is free to move and never in the past.
  /// Late in the evening the next full hour is already tomorrow's midnight,
  /// and stays there rather than moving a day further.
  static DateTime defaultStart(DateTime now) {
    final next = nextFullHour(now);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (!next.isBefore(tomorrow)) return next;
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, next.hour);
  }

  @override
  ConsumerState<PersonMeetingForm> createState() => _PersonMeetingFormState();
}

class _PersonMeetingFormState extends ConsumerState<PersonMeetingForm> {
  TextEditingController? _title;
  late DateTime _start = PersonMeetingForm.defaultStart(clock.now());
  Duration _duration = PersonMeetingForm.defaultDuration;
  var _saving = false;

  /// What went wrong with the last save, said under the title; null while
  /// nothing has. Inside the sheet: a toast would render behind it.
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The default title is localized, so it is read once the sheet has a
    // locale to read it in.
    _title ??= TextEditingController(
      text: context.messages.relationshipMeetingDefaultTitle(
        widget.person.shortName,
      ),
    )..addListener(_changed);
  }

  @override
  void dispose() {
    _title
      ?..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  void _changed() => setState(() => _error = null);

  bool get _canSave => !_saving && (_title?.text.trim().isNotEmpty ?? false);

  Future<void> _pickStart() async {
    final picked = await pickMeetingStart(context: context, initial: _start);
    if (picked == null || !mounted) return;
    setState(() => _start = picked);
  }

  Future<void> _pickDuration() async {
    final picked = await showCheckInDurationPicker(
      context: context,
      initialDuration: _duration,
    );
    // A meeting always runs for a while: "no duration" keeps the last one.
    if (picked == null || picked <= Duration.zero || !mounted) return;
    setState(() => _duration = picked);
  }

  /// Plans the meeting and closes the sheet; a write that fails, or throws,
  /// keeps the sheet open with the reason under the title.
  Future<void> _save() async {
    final failed = context.messages.relationshipMeetingSaveFailed;
    setState(() => _saving = true);
    bool saved;
    try {
      saved =
          await ref
              .read(personTimelineRepositoryProvider)
              .createMeeting(
                person: widget.person,
                title: _title!.text,
                start: _start,
                duration: _duration,
              ) !=
          null;
    } catch (error, stackTrace) {
      ref
          .read(domainLoggerProvider)
          .error(
            LogDomain.general,
            error,
            stackTrace: stackTrace,
            subDomain: 'PersonMeetingSheet',
            message: 'Failed to plan a meeting on the person timeline',
          );
      saved = false;
    }
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _error = failed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final startLabel =
        '${relationshipDayLabelOf(context, _start)} · '
        '${relationshipTimeLabel(_start)}';
    final durationLabel = checkInDurationLabel(context, _duration);
    // While the meeting is being written the sheet holds — Cancel, the
    // close, the scrim and Esc alike — so it never closes on a write that
    // then lands anyway.
    return PopScope(
      canPop: !_saving,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignSystemTextInput(
            key: const ValueKey('person-meeting-title'),
            controller: _title,
            label: messages.relationshipMeetingTitleLabel,
            errorText: _error,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) {
              if (_canSave) _save();
            },
          ),
          SizedBox(height: tokens.spacing.step4),
          // When and how long, as the composer sets them: the same tags, each
          // opening the same kind of picker.
          Wrap(
            spacing: tokens.spacing.step2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FactTag(
                key: const ValueKey('person-meeting-start'),
                semanticsLabel: messages.relationshipMeetingStartsSemantics(
                  startLabel,
                ),
                icon: LottiIcons.calendar,
                label: startLabel,
                emphasised: true,
                onTap: _saving ? null : _pickStart,
              ),
              FactTag(
                key: const ValueKey('person-meeting-duration'),
                semanticsLabel: messages.checkInDurationChipSemantics(
                  durationLabel,
                ),
                icon: LottiIcons.timer,
                label: durationLabel,
                emphasised: true,
                onTap: _saving ? null : _pickDuration,
              ),
            ],
          ),
          SizedBox(height: tokens.spacing.step5),
          DesignSystemModalActionBar(
            primary: DesignSystemButton(
              key: const ValueKey('person-meeting-save'),
              label: messages.relationshipMeetingSave,
              size: DesignSystemButtonSize.large,
              fullWidth: true,
              onPressed: _canSave ? _save : null,
            ),
            secondary: [
              DesignSystemButton(
                key: const ValueKey('person-meeting-cancel'),
                label: messages.cancelButton,
                variant: DesignSystemButtonVariant.quiet,
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
