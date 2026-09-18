import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/inputs/design_system_text_input.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/check_in_transcription_service.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/features/relationships/ui/shared/sentiment.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_inline_recorder.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:material_ui/material_ui.dart';

/// Adds images to a check-in: the platform's picker in production; a seam
/// tests replace, since the picker is an OS dialog.
typedef CheckInPhotoImporter =
    Future<void> Function(
      BuildContext context, {
      required String checkInId,
      String? categoryId,
    });

final checkInPhotoImporterProvider = Provider<CheckInPhotoImporter>(
  (ref) =>
      // The production importer opens the OS picker, which no test can drive.
      // coverage:ignore-start
      (context, {required checkInId, categoryId}) => importImagesForPlatform(
        context,
        linkedId: checkInId,
        categoryId: categoryId,
      ),
  // coverage:ignore-end
  name: 'checkInPhotoImporterProvider',
);

/// One check-in and everything it holds (ADR 0062): what kind of contact it
/// was and how it felt, the text it was saved with, then its comments,
/// recordings and photos as the nested entries a task shows — with a bar to
/// add another comment, dictation or photo.
///
/// Shared by the phone page and the desktop person pane; [onBack] leads
/// back to the person.
///
/// Whenever one of its entries is newer than the check-in — a transcript or
/// a comment edited in place here — the check-in is saved again, so the
/// agent reads the edit as changed evidence (see
/// `RelationshipRepository.touchCheckIn`).
class CheckInDetailView extends ConsumerStatefulWidget {
  const CheckInDetailView({
    required this.relationshipId,
    required this.checkInId,
    this.onBack,
    super.key,
  });

  final String relationshipId;
  final String checkInId;
  final VoidCallback? onBack;

  @override
  ConsumerState<CheckInDetailView> createState() => _CheckInDetailViewState();
}

class _CheckInDetailViewState extends ConsumerState<CheckInDetailView> {
  final _comment = TextEditingController();
  bool _recording = false;
  bool _adding = false;

  /// The newest entry change the check-in was last brought up to, so one
  /// edit saves the check-in once.
  DateTime? _touchedFor;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      relationshipDetailControllerProvider(widget.relationshipId),
      (_, next) => _touchIfEntriesChanged(next.value),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  void _touchIfEntriesChanged(RelationshipDetail? detail) {
    final checkIn = _checkInOf(detail);
    if (checkIn == null) return;
    DateTime? newest;
    for (final entry
        in detail!.checkInEntries[checkIn.id] ?? const <JournalEntity>[]) {
      final at = entry.meta.updatedAt;
      if (newest == null || at.isAfter(newest)) newest = at;
    }
    if (newest == null ||
        !newest.isAfter(checkIn.meta.updatedAt) ||
        newest == _touchedFor) {
      return;
    }
    _touchedFor = newest;
    unawaited(
      ref.read(relationshipRepositoryProvider).touchCheckIn(checkIn.id),
    );
  }

  CheckInEntry? _checkInOf(RelationshipDetail? detail) =>
      detail?.checkIns.where((c) => c.meta.id == widget.checkInId).firstOrNull;

  Future<void> _addComment(CheckInEntry checkIn) async {
    final text = _comment.text.trim();
    if (text.isEmpty || _adding) return;
    setState(() => _adding = true);
    final added = await ref
        .read(relationshipRepositoryProvider)
        .addCommentToCheckIn(checkIn, text);
    if (!mounted) return;
    setState(() => _adding = false);
    if (added == null) {
      context.showToast(
        tone: DesignSystemToastTone.error,
        title: context.messages.relationshipErrorUpdateFailed,
      );
      return;
    }
    _comment.clear();
  }

  Future<void> _addPhotos(CheckInEntry checkIn) async {
    final repository = ref.read(relationshipRepositoryProvider);
    await ref.read(checkInPhotoImporterProvider)(
      context,
      checkInId: checkIn.id,
      categoryId: checkIn.meta.categoryId,
    );
    // The photos are linked as they are created; saving the check-in again
    // is what tells the agent it holds something new.
    await repository.touchCheckIn(checkIn.id);
  }

  void _onRecorded(CheckInEntry checkIn, String audioEntryId) {
    setState(() => _recording = false);
    final repository = ref.read(relationshipRepositoryProvider);
    final transcription = ref.read(checkInTranscriptionServiceProvider);
    // The recorder linked the audio to the check-in as it saved it. The
    // words follow in the background; the service saves the check-in again
    // when they land.
    unawaited(repository.touchCheckIn(checkIn.id));
    unawaited(
      transcription
          .transcribe(
            audioEntryId: audioEntryId,
            relationshipId: widget.relationshipId,
          )
          .result,
    );
  }

  void _onRecordingFailed(CheckInSpeechFailureKind kind) {
    setState(() => _recording = false);
    final (title, body) = checkInRecordingFailureCopy(context.messages, kind);
    context.showToast(
      tone: DesignSystemToastTone.error,
      title: title,
      description: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final detail = ref
        .watch(relationshipDetailControllerProvider(widget.relationshipId))
        .value;
    final checkIn = _checkInOf(detail);
    final person = detail?.relationship.data;
    final title = person == null
        ? messages.entryTypeLabelCheckIn
        : person.nickname ?? person.title;

    return Column(
      children: [
        _Header(
          subtitle: title,
          onBack: widget.onBack,
          onEdit: checkIn == null
              ? null
              : () => showCheckInEditSheet(context: context, checkIn: checkIn),
        ),
        Expanded(
          child: checkIn == null
              ? Center(
                  child: detail == null
                      ? const CircularProgressIndicator()
                      : Text(
                          messages.relationshipCheckInGone,
                          key: const ValueKey('check-in-detail-gone'),
                          style: tokens.typography.styles.body.bodyMedium
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                )
              : ListView(
                  key: const ValueKey('check-in-detail-list'),
                  padding: EdgeInsets.all(tokens.spacing.step5),
                  children: [
                    _SummaryCard(checkIn: checkIn),
                    if (checkIn.entryText?.plainText.trim() case final note?
                        when note.isNotEmpty) ...[
                      SizedBox(height: tokens.spacing.cardItemSpacing),
                      _NoteCard(note: note),
                    ],
                    SizedBox(height: tokens.spacing.cardItemSpacing),
                    if ((detail!.checkInEntries[checkIn.id] ?? const [])
                        .isEmpty)
                      Text(
                        messages.relationshipCheckInEmpty,
                        key: const ValueKey('check-in-detail-empty'),
                        style: tokens.typography.styles.body.bodyMedium
                            .copyWith(
                              color: tokens.colors.text.mediumEmphasis,
                            ),
                      )
                    else
                      LinkedEntriesWidget(checkIn),
                  ],
                ),
        ),
        if (checkIn != null)
          _AddBar(
            recording: _recording,
            adding: _adding,
            comment: _comment,
            recorder: CheckInInlineRecorder(
              key: ValueKey('check-in-detail-recorder-${checkIn.id}'),
              linkedId: checkIn.id,
              categoryId: checkIn.meta.categoryId,
              onRecorded: (audioEntryId, _) =>
                  _onRecorded(checkIn, audioEntryId),
              onDiscarded: () => setState(() => _recording = false),
              onFailed: _onRecordingFailed,
            ),
            onSendComment: () => _addComment(checkIn),
            onDictate: () => setState(() => _recording = true),
            onPhoto: () => _addPhotos(checkIn),
          ),
      ],
    );
  }
}

/// The title and body a recording that could not start or finish reports,
/// in the composer's own words for each failure.
(String, String) checkInRecordingFailureCopy(
  AppLocalizations messages,
  CheckInSpeechFailureKind kind,
) => switch (kind) {
  CheckInSpeechFailureKind.microphoneDenied => (
    messages.checkInMicrophoneDeniedCalloutTitle,
    messages.checkInMicrophoneDeniedBody,
  ),
  CheckInSpeechFailureKind.recorderBusy => (
    messages.checkInRecorderBusyTitle,
    messages.checkInRecorderBusyBody,
  ),
  CheckInSpeechFailureKind.recordingNotSaved => (
    messages.checkInRecordingNotSavedTitle,
    messages.checkInRecordingNotSavedBody,
  ),
  _ => (
    messages.checkInRecordingFailedTitle,
    messages.checkInRecordingFailedBody,
  ),
};

/// The bar above the page: back to the person, what this is and whose, and
/// the way to change the check-in's own details.
class _Header extends StatelessWidget {
  const _Header({required this.subtitle, this.onBack, this.onEdit});

  final String subtitle;
  final VoidCallback? onBack;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        border: Border(
          bottom: BorderSide(color: tokens.colors.decorative.level01),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(tokens.spacing.step4),
        child: Row(
          children: [
            if (onBack != null) ...[
              IconButton(
                key: const ValueKey('check-in-detail-back'),
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
                icon: const Icon(LottiIcons.back),
              ),
              SizedBox(width: tokens.spacing.step2),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    messages.entryTypeLabelCheckIn,
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                  SizedBox(height: tokens.spacing.step1),
                  Text(
                    subtitle,
                    key: const ValueKey('check-in-detail-person'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.lowEmphasis,
                    ),
                  ),
                ],
              ),
            ),
            if (onEdit != null)
              DesignSystemButton(
                key: const ValueKey('check-in-detail-edit'),
                label: messages.editMenuTitle,
                leadingIcon: LottiIcons.edit,
                variant: DesignSystemButtonVariant.tertiary,
                tapTargetSize: MaterialTapTargetSize.padded,
                onPressed: onEdit,
              ),
          ],
        ),
      ),
    );
  }
}

/// How the contact went: when, how and for how long, the feeling, the
/// topics, and the notes for next time.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.checkIn});

  final CheckInEntry checkIn;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final data = checkIn.data;
    final duration = relationshipDurationLabelOf(
      context,
      checkIn.meta.dateTo.difference(checkIn.meta.dateFrom),
    );
    final meta = [
      relationshipTimestampLabelOf(context, checkIn.meta.dateFrom),
      checkInInteractionLabel(context, data.interactionType),
      ?duration,
    ].join(' · ');
    final guidance = [
      if (data.payAttentionTo?.trim() case final text? when text.isNotEmpty)
        (messages.relationshipPayAttentionTo, text),
      if (data.avoid?.trim() case final text? when text.isNotEmpty)
        (messages.checkInAvoidLabel, text),
    ];

    return DesignSystemSectionCard(
      key: const ValueKey('check-in-detail-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                checkInInteractionIcon(data.interactionType),
                size: IconSizes.m,
                color: tokens.colors.text.mediumEmphasis,
              ),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Text(
                  meta,
                  key: const ValueKey('check-in-detail-meta'),
                  style: relationshipTimestampStyle(
                    tokens,
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ),
              if (data.sentiment case final sentiment?)
                DsPill(
                  variant: DsPillVariant.tinted,
                  shape: DsPillShape.tag,
                  color: sentimentColor(tokens, sentiment),
                  labelColor: tokens.colors.text.highEmphasis,
                  label: checkInSentimentLabel(context, sentiment),
                ),
            ],
          ),
          if (data.topics.isNotEmpty) ...[
            SizedBox(height: tokens.spacing.step4),
            Wrap(
              spacing: tokens.spacing.step2,
              runSpacing: tokens.spacing.step2,
              children: [
                for (final topic in data.topics)
                  DsPill(
                    variant: DsPillVariant.filled,
                    shape: DsPillShape.tag,
                    bordered: true,
                    label: topic,
                    labelColor: tokens.colors.text.mediumEmphasis,
                  ),
              ],
            ),
          ],
          if (guidance.isNotEmpty) ...[
            SizedBox(height: tokens.spacing.step5),
            Text(
              messages.relationshipNextTimeTitle,
              style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            for (final (label, text) in guidance) ...[
              SizedBox(height: tokens.spacing.step3),
              Text(
                label,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
              SizedBox(height: tokens.spacing.step1),
              Text(
                text,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// The text a check-in was saved with before check-ins held entries: shown
/// first, as the check-in's opening note.
class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemSectionCard(
      key: const ValueKey('check-in-detail-note'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.relationshipCheckInNoteLabel,
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
          SelectableText(
            note,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Adds to the check-in: a comment typed in place, a dictation recorded in
/// place, or photos from the library.
class _AddBar extends StatelessWidget {
  const _AddBar({
    required this.recording,
    required this.adding,
    required this.comment,
    required this.recorder,
    required this.onSendComment,
    required this.onDictate,
    required this.onPhoto,
  });

  final bool recording;
  final bool adding;
  final TextEditingController comment;
  final Widget recorder;
  final VoidCallback onSendComment;
  final VoidCallback onDictate;
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level01,
        border: Border(
          top: BorderSide(color: tokens.colors.decorative.level01),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step4),
          child: recording
              ? recorder
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DesignSystemTextInput(
                      key: const ValueKey('check-in-detail-comment'),
                      controller: comment,
                      hintText: messages.relationshipCheckInCommentHint,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !adding,
                      trailingIcon: LottiIcons.send,
                      trailingIconKey: const ValueKey(
                        'check-in-detail-send-comment',
                      ),
                      trailingIconTooltip:
                          messages.relationshipCheckInAddComment,
                      onTrailingIconTap: onSendComment,
                      onSubmitted: (_) => onSendComment(),
                    ),
                    SizedBox(height: tokens.spacing.step3),
                    Row(
                      children: [
                        DesignSystemButton(
                          key: const ValueKey('check-in-detail-dictate'),
                          label: messages.checkInDictateButton,
                          leadingIcon: LottiIcons.mic,
                          variant: DesignSystemButtonVariant.secondary,
                          tapTargetSize: MaterialTapTargetSize.padded,
                          onPressed: onDictate,
                        ),
                        SizedBox(width: tokens.spacing.step3),
                        DesignSystemButton(
                          key: const ValueKey('check-in-detail-photo'),
                          label: messages.relationshipCheckInAddPhoto,
                          leadingIcon: LottiIcons.image,
                          variant: DesignSystemButtonVariant.secondary,
                          tapTargetSize: MaterialTapTargetSize.padded,
                          onPressed: onPhoto,
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
