import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/check_in_data.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/form/form_widgets.dart';
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

/// The check-in capture form: interaction type, optional sentiment
/// (explicit user judgment — never pre-filled), topics, narrative, and the
/// "next time" guidance fields. Persists through [RelationshipRepository].
class CheckInCaptureForm extends ConsumerStatefulWidget {
  const CheckInCaptureForm({required this.relationshipId, super.key});

  final String relationshipId;

  @override
  ConsumerState<CheckInCaptureForm> createState() => _CheckInCaptureFormState();
}

class _CheckInCaptureFormState extends ConsumerState<CheckInCaptureForm> {
  late final TextEditingController _topicsController;
  late final TextEditingController _narrativeController;
  late final TextEditingController _payAttentionController;
  late final TextEditingController _avoidController;
  CheckInInteractionType _interactionType = CheckInInteractionType.inPerson;
  CheckInSentiment? _sentiment;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _topicsController = TextEditingController();
    _narrativeController = TextEditingController();
    _payAttentionController = TextEditingController();
    _avoidController = TextEditingController();
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

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final repository = ref.read(relationshipRepositoryProvider);
    final narrative = _narrativeController.text.trim();
    final payAttentionTo = _payAttentionController.text.trim();
    final avoid = _avoidController.text.trim();

    try {
      final created = await repository.createCheckIn(
        data: CheckInData(
          relationshipId: widget.relationshipId,
          interactionType: _interactionType,
          sentiment: _sentiment,
          topics: _topics,
          payAttentionTo: payAttentionTo.isEmpty ? null : payAttentionTo,
          avoid: avoid.isEmpty ? null : avoid,
        ),
        entryText: narrative.isEmpty ? null : EntryText(plainText: narrative),
      );

      if (created != null) {
        if (mounted) {
          Navigator.of(context).pop(created);
        }
      } else if (mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.checkInErrorCreateFailed,
        );
      }
    } catch (e, s) {
      developer.log(
        'Failed to create check-in',
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
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
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
