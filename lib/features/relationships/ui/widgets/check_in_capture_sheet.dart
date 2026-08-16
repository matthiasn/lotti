import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/calendar_pickers/design_system_date_picker_modal.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:lotti/widgets/form/form_widgets.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Upper bound on the form's height as a fraction of the viewport — the
/// create-modal sizing shared with `ProjectCreateForm`.
const double _modalMaxHeightFraction = 0.9;

/// The localized label for an interaction type — shared by the capture sheet
/// and the detail page's check-in rows.
String checkInInteractionLabel(
  BuildContext context,
  CheckInInteractionType type,
) => switch (type) {
  CheckInInteractionType.inPerson =>
    context.messages.checkInInteractionInPerson,
  CheckInInteractionType.call => context.messages.checkInInteractionCall,
  CheckInInteractionType.videoCall =>
    context.messages.checkInInteractionVideoCall,
  CheckInInteractionType.message => context.messages.checkInInteractionMessage,
  CheckInInteractionType.other => context.messages.checkInInteractionOther,
};

/// The icon for an interaction type — shared by the detail page's check-in
/// rows and the journal card, so the two can't drift apart.
IconData checkInInteractionIcon(CheckInInteractionType type) => switch (type) {
  CheckInInteractionType.inPerson => Icons.people_rounded,
  CheckInInteractionType.call => Icons.call_rounded,
  CheckInInteractionType.videoCall => Icons.videocam_rounded,
  CheckInInteractionType.message => Icons.chat_rounded,
  CheckInInteractionType.other => Icons.forum_rounded,
};

/// The localized label for a sentiment — shared by the capture sheet and the
/// detail page's check-in rows.
String checkInSentimentLabel(
  BuildContext context,
  CheckInSentiment sentiment,
) => switch (sentiment) {
  CheckInSentiment.delightful => context.messages.checkInSentimentDelightful,
  CheckInSentiment.good => context.messages.checkInSentimentGood,
  CheckInSentiment.neutral => context.messages.checkInSentimentNeutral,
  CheckInSentiment.strained => context.messages.checkInSentimentStrained,
  CheckInSentiment.difficult => context.messages.checkInSentimentDifficult,
};

/// Opens the responsive check-in capture overlay for [relationshipId].
/// Resolves to the created [CheckInEntry], or `null` when dismissed.
Future<CheckInEntry?> showCheckInCaptureSheet({
  required BuildContext context,
  required String relationshipId,
}) {
  return ModalUtils.showSinglePageModal<CheckInEntry>(
    context: context,
    title: context.messages.relationshipLogCheckIn,
    builder: (modalContext) =>
        CheckInCaptureForm(relationshipId: relationshipId),
  );
}

/// Opens the capture overlay prefilled from [checkIn] for editing. Resolves
/// to the updated [CheckInEntry], or `null` when dismissed or deleted.
Future<CheckInEntry?> showCheckInEditSheet({
  required BuildContext context,
  required CheckInEntry checkIn,
}) {
  return ModalUtils.showSinglePageModal<CheckInEntry>(
    context: context,
    title: context.messages.checkInEditTitle,
    builder: (modalContext) => CheckInCaptureForm(
      relationshipId: checkIn.data.relationshipId,
      initial: checkIn,
    ),
  );
}

/// The check-in capture form: interaction type, date, optional sentiment
/// (explicit user judgment — never pre-filled), topics, narrative, and the
/// "next time" guidance fields. Persists through [RelationshipRepository].
/// With [initial] set it edits that check-in instead, and offers deletion.
class CheckInCaptureForm extends ConsumerStatefulWidget {
  const CheckInCaptureForm({
    required this.relationshipId,
    this.initial,
    super.key,
  });

  final String relationshipId;

  /// When set, the form edits this check-in instead of creating one.
  final CheckInEntry? initial;

  @override
  ConsumerState<CheckInCaptureForm> createState() => _CheckInCaptureFormState();
}

class _CheckInCaptureFormState extends ConsumerState<CheckInCaptureForm> {
  late final TextEditingController _topicsController;
  late final TextEditingController _narrativeController;
  late final TextEditingController _payAttentionController;
  late final TextEditingController _avoidController;
  late CheckInInteractionType _interactionType;
  late CheckInSentiment? _sentiment;
  late DateTime _interactionTime;
  bool _isSaving = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final data = initial?.data;
    _topicsController = TextEditingController(
      text: data?.topics.join(', ') ?? '',
    );
    _narrativeController = TextEditingController(
      text: initial?.entryText?.plainText ?? '',
    );
    _payAttentionController = TextEditingController(
      text: data?.payAttentionTo ?? '',
    );
    _avoidController = TextEditingController(text: data?.avoid ?? '');
    _interactionType = data?.interactionType ?? CheckInInteractionType.inPerson;
    _sentiment = data?.sentiment;
    _interactionTime = initial?.meta.dateFrom ?? DateTime.now();
  }

  @override
  void dispose() {
    _topicsController.dispose();
    _narrativeController.dispose();
    _payAttentionController.dispose();
    _avoidController.dispose();
    super.dispose();
  }

  List<String> get _topics => _topicsController.text
      .split(',')
      .map((topic) => topic.trim())
      .where((topic) => topic.isNotEmpty)
      .toList();

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final result = await showDesignSystemDatePicker(
      context: context,
      title: context.messages.checkInDateLabel,
      initialDate: _interactionTime,
      firstDate: DateTime(today.year - 50),
      lastDate: today,
    );
    final picked = result?.date;
    if (!mounted || picked == null) return;
    // Keep the existing time of day — the picker is date-only, and a
    // check-in edited to another day shouldn't jump to midnight.
    setState(() {
      _interactionTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _interactionTime.hour,
        _interactionTime.minute,
      );
    });
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final repository = ref.read(relationshipRepositoryProvider);
    final narrative = _narrativeController.text.trim();
    final payAttentionTo = _payAttentionController.text.trim();
    final avoid = _avoidController.text.trim();
    final data = CheckInData(
      relationshipId: widget.relationshipId,
      interactionType: _interactionType,
      sentiment: _sentiment,
      topics: _topics,
      payAttentionTo: payAttentionTo.isEmpty ? null : payAttentionTo,
      avoid: avoid.isEmpty ? null : avoid,
    );
    final entryText = narrative.isEmpty
        ? null
        : EntryText(plainText: narrative);

    try {
      if (_isEditing) {
        final initial = widget.initial!;
        final updated = initial.copyWith(
          data: data,
          entryText: entryText,
          meta: initial.meta.copyWith(
            dateFrom: _interactionTime,
            dateTo: _interactionTime,
          ),
        );
        final success = await repository.updateCheckIn(updated);
        if (!mounted) return;
        if (success) {
          Navigator.of(context).pop(updated);
        } else {
          context.showToast(
            tone: DesignSystemToastTone.error,
            title: context.messages.checkInErrorCreateFailed,
          );
        }
      } else {
        final created = await repository.createCheckIn(
          data: data,
          entryText: entryText,
          dateFrom: _interactionTime,
        );
        if (!mounted) return;
        if (created != null) {
          Navigator.of(context).pop(created);
        } else {
          context.showToast(
            tone: DesignSystemToastTone.error,
            title: context.messages.checkInErrorCreateFailed,
          );
        }
      }
    } catch (e, s) {
      developer.log(
        'Failed to save check-in',
        name: 'CheckInCaptureForm',
        error: e,
        stackTrace: s,
      );
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.checkInErrorCreateFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handleDelete() async {
    final initial = widget.initial;
    if (initial == null || _isSaving) return;

    final confirmed = await showConfirmationModal(
      context: context,
      message: context.messages.checkInDeleteConfirmMessage,
      confirmLabel: context.messages.deleteButton,
    );
    if (!confirmed || !mounted) return;

    setState(() => _isSaving = true);
    try {
      final deleted = await ref
          .read(relationshipRepositoryProvider)
          .deleteCheckIn(initial.id);
      if (!mounted) return;
      if (deleted) {
        Navigator.of(context).pop();
      } else {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.checkInErrorDeleteFailed,
        );
      }
    } catch (e, s) {
      developer.log(
        'Failed to delete check-in',
        name: 'CheckInCaptureForm',
        error: e,
        stackTrace: s,
      );
      if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.checkInErrorDeleteFailed,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    final tokens = context.designTokens;

    Widget sectionLabel(String text) => Padding(
      padding: EdgeInsets.only(bottom: tokens.spacing.step3),
      child: Text(
        text,
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
      ),
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * _modalMaxHeightFraction,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  sectionLabel(messages.checkInInteractionLabel),
                  Wrap(
                    spacing: tokens.spacing.step3,
                    runSpacing: tokens.spacing.step3,
                    children: [
                      for (final type in CheckInInteractionType.values)
                        ChoiceChip(
                          label: Text(checkInInteractionLabel(context, type)),
                          selected: _interactionType == type,
                          onSelected: (_) =>
                              setState(() => _interactionType = type),
                        ),
                    ],
                  ),
                  SizedBox(height: tokens.spacing.step5),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(tokens.radii.s),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: messages.checkInDateLabel,
                        prefixIcon: const Icon(Icons.calendar_today_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(tokens.radii.s),
                        ),
                      ),
                      child: Text(
                        _interactionTime.ymd,
                        style: tokens.typography.styles.body.bodyLarge.copyWith(
                          color: tokens.colors.text.highEmphasis,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step5),
                  sectionLabel(messages.checkInSentimentLabel),
                  Wrap(
                    spacing: tokens.spacing.step3,
                    runSpacing: tokens.spacing.step3,
                    children: [
                      for (final sentiment in CheckInSentiment.values)
                        ChoiceChip(
                          label: Text(
                            checkInSentimentLabel(context, sentiment),
                          ),
                          selected: _sentiment == sentiment,
                          // Tapping the selected sentiment clears it again —
                          // sentiment is optional, never forced.
                          onSelected: (_) => setState(
                            () => _sentiment = _sentiment == sentiment
                                ? null
                                : sentiment,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: tokens.spacing.step5),
                  LottiTextField(
                    controller: _narrativeController,
                    labelText: messages.checkInNarrativeLabel,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  SizedBox(height: tokens.spacing.step5),
                  LottiTextField(
                    controller: _topicsController,
                    labelText: messages.checkInTopicsLabel,
                    hintText: messages.checkInTopicsHint,
                  ),
                  SizedBox(height: tokens.spacing.step5),
                  LottiTextField(
                    controller: _payAttentionController,
                    labelText: messages.checkInPayAttentionLabel,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  SizedBox(height: tokens.spacing.step5),
                  LottiTextField(
                    controller: _avoidController,
                    labelText: messages.checkInAvoidLabel,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: tokens.spacing.step6),
          Row(
            children: [
              if (_isEditing)
                IconButton(
                  tooltip: messages.deleteButton,
                  onPressed: _isSaving ? null : _handleDelete,
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              const Spacer(),
              DesignSystemButton(
                label: messages.cancelButton,
                variant: DesignSystemButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
              SizedBox(width: tokens.spacing.step4),
              DesignSystemButton(
                label: messages.saveButton,
                onPressed: _isSaving ? null : _handleSave,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
