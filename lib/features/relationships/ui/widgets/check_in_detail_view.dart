import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/check_in_transcription_service.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_context_chips.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_duration_picker.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_inline_recorder.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/themes/theme.dart';
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

/// One check-in and everything it holds (ADR 0062), laid out like a task's
/// detail page (design panel 2026-09-19): a header that names the check-in
/// and carries its when, how, how long and how it felt as chips that edit
/// in place; the notes for next time; a timeline of what it holds — the
/// note it was logged with first, then its recordings, comments and photos
/// as the journal's own entry cards; and a floating glass action bar that
/// adds to that timeline.
///
/// Shared by the phone page and the desktop person pane; [onBack] leads
/// back to the person.
///
/// Whenever one of its entries changes after the check-in — a transcript,
/// or a comment written in place here — the check-in is saved again, so
/// the agent reads the change as new evidence (see
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

  /// From this many entries up the timeline offers its Timer / Audio /
  /// Images filters; a shorter one has nothing to filter.
  @visibleForTesting
  static const filtersFrom = 5;

  @override
  ConsumerState<CheckInDetailView> createState() => _CheckInDetailViewState();
}

class _CheckInDetailViewState extends ConsumerState<CheckInDetailView> {
  bool _recording = false;
  bool _startingComment = false;

  /// The newest entry change the check-in was last brought up to, so one
  /// edit saves the check-in once.
  DateTime? _touchedFor;

  /// Scroll-to keys for the timeline's cards, so a comment started from the
  /// bar is brought into view.
  final Map<String, GlobalKey> _entryKeys = {};

  GlobalKey _keyFor(String entryId) =>
      _entryKeys.putIfAbsent(entryId, GlobalKey.new);

  /// Comments started here; any still blank when the view closes are
  /// removed, so a stray tap on *Comment* leaves nothing behind.
  final Set<String> _startedComments = {};

  /// Read up front: `dispose` may not use `ref`.
  late final RelationshipRepository _repository;

  @override
  void dispose() {
    for (final id in _startedComments) {
      unawaited(_repository.discardCommentIfBlank(id));
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _repository = ref.read(relationshipRepositoryProvider);
    ref.listenManual(
      relationshipDetailControllerProvider(widget.relationshipId),
      (_, next) => _touchIfEntriesChanged(next.value),
      fireImmediately: true,
    );
  }

  /// Saves the check-in again when an entry changed after it. An empty
  /// comment is not evidence yet — only its words are.
  void _touchIfEntriesChanged(RelationshipDetail? detail) {
    final checkIn = _checkInOf(detail);
    if (checkIn == null) return;
    DateTime? newest;
    for (final entry
        in detail!.checkInEntries[checkIn.id] ?? const <JournalEntity>[]) {
      if (entry is JournalEntry &&
          (entry.entryText?.plainText.trim() ?? '').isEmpty) {
        continue;
      }
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

  /// *Comment*: an empty comment card in the timeline, its editor focused,
  /// the way a task's text entry starts.
  Future<void> _startComment(CheckInEntry checkIn) async {
    if (_startingComment) return;
    setState(() => _startingComment = true);
    final entry = await ref
        .read(relationshipRepositoryProvider)
        .startCommentOnCheckIn(checkIn);
    if (!mounted) return;
    setState(() => _startingComment = false);
    if (entry == null) {
      _failed();
      return;
    }
    _startedComments.add(entry.meta.id);
    final key = _keyFor(entry.meta.id);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cardContext = key.currentContext;
      if (!mounted || cardContext == null) return;
      await Scrollable.ensureVisible(
        cardContext,
        duration: MotionDurations.medium2,
        alignment: 0.3,
      );
      if (!mounted) return;
      ref
          .read(entryControllerProvider(entry.meta.id).notifier)
          .focusNode
          .requestFocus();
    });
  }

  Future<void> _addPhotos(CheckInEntry checkIn) async {
    final repository = ref.read(relationshipRepositoryProvider);
    Future<Set<String>> held() async => {
      for (final entry
          in (await repository.getAllEntriesForCheckIns({
                checkIn.id,
              }))[checkIn.id] ??
              const <JournalEntity>[])
        entry.id,
    };
    final before = await held();
    if (!mounted) return;
    await ref.read(checkInPhotoImporterProvider)(
      context,
      checkInId: checkIn.id,
      categoryId: checkIn.meta.categoryId,
    );
    // The photos are linked as they are created; saving the check-in again
    // is what tells the agent it holds something new — so only when it
    // does: a cancelled picker, or files that were all refused, change
    // nothing and must not stale the briefing.
    if ((await held()).difference(before).isEmpty) return;
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

  void _failed() => context.showToast(
    tone: DesignSystemToastTone.error,
    title: context.messages.relationshipErrorUpdateFailed,
  );

  /// Saves one field changed from a header chip.
  Future<void> _save(CheckInEntry updated) async {
    final saved = await ref
        .read(relationshipRepositoryProvider)
        .updateCheckIn(updated);
    if (!saved && mounted) _failed();
  }

  Duration _lengthOf(CheckInEntry checkIn) {
    final length = checkIn.meta.dateTo.difference(checkIn.meta.dateFrom);
    return length.isNegative ? Duration.zero : length;
  }

  Future<void> _pickStart(CheckInEntry checkIn) async {
    final picked = await pickCheckInStart(
      context: context,
      initial: checkIn.meta.dateFrom,
    );
    if (!mounted || picked == null || picked == checkIn.meta.dateFrom) return;
    await _save(
      checkIn.copyWith(
        meta: checkIn.meta.copyWith(
          dateFrom: picked,
          dateTo: picked.add(_lengthOf(checkIn)),
        ),
      ),
    );
  }

  Future<void> _pickDuration(CheckInEntry checkIn) async {
    final picked = await showCheckInDurationPicker(
      context: context,
      initialDuration: _lengthOf(checkIn),
    );
    if (!mounted || picked == null || picked == _lengthOf(checkIn)) return;
    await _save(
      checkIn.copyWith(
        meta: checkIn.meta.copyWith(
          dateTo: checkIn.meta.dateFrom.add(picked),
        ),
      ),
    );
  }

  Future<void> _pickType(CheckInEntry checkIn) async {
    final picked = await showCheckInTypePicker(
      context: context,
      current: checkIn.data.interactionType,
    );
    if (!mounted || picked == null || picked == checkIn.data.interactionType) {
      return;
    }
    await _save(
      checkIn.copyWith(data: checkIn.data.copyWith(interactionType: picked)),
    );
  }

  Future<void> _pickSentiment(CheckInEntry checkIn) async {
    final picked = await showCheckInSentimentPicker(
      context: context,
      current: checkIn.data.sentiment,
    );
    if (!mounted ||
        picked == null ||
        picked.sentiment == checkIn.data.sentiment) {
      return;
    }
    await _save(
      checkIn.copyWith(
        data: checkIn.data.copyWith(sentiment: picked.sentiment),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final detailAsync = ref.watch(
      relationshipDetailControllerProvider(widget.relationshipId),
    );
    // Keep the last rendered detail during background reloads.
    final detail = detailAsync.value;
    final checkIn = _checkInOf(detail);

    return Column(
      children: [
        _TopBar(
          onBack: widget.onBack,
          onEdit: checkIn == null
              ? null
              : () => showCheckInEditSheet(context: context, checkIn: checkIn),
        ),
        Expanded(
          child: checkIn == null
              ? Center(
                  child: detail == null && detailAsync.isLoading
                      ? const CircularProgressIndicator()
                      : Text(
                          // A failed first load is an error; a person or
                          // check-in that resolved to nothing is gone.
                          detail == null && detailAsync.hasError
                              ? messages.commonError
                              : messages.relationshipCheckInGone,
                          key: const ValueKey('check-in-detail-gone'),
                          style: tokens.typography.styles.body.bodyMedium
                              .copyWith(
                                color: tokens.colors.text.mediumEmphasis,
                              ),
                        ),
                )
              : _Body(
                  checkIn: checkIn,
                  personName: detail!.relationship.data.title,
                  entries: detail.checkInEntries[checkIn.id] ?? const [],
                  entryKeyBuilder: _keyFor,
                  onPickType: () => _pickType(checkIn),
                  onPickStart: () => _pickStart(checkIn),
                  onPickDuration: () => _pickDuration(checkIn),
                  onPickSentiment: () => _pickSentiment(checkIn),
                ),
        ),
        if (checkIn != null)
          _CheckInActionBar(
            recorder: _recording
                ? CheckInInlineRecorder(
                    key: ValueKey('check-in-detail-recorder-${checkIn.id}'),
                    linkedId: checkIn.id,
                    categoryId: checkIn.meta.categoryId,
                    onRecorded: (audioEntryId, _) =>
                        _onRecorded(checkIn, audioEntryId),
                    onDiscarded: () => setState(() => _recording = false),
                    onFailed: _onRecordingFailed,
                  )
                : null,
            onDictate: () => setState(() => _recording = true),
            onComment: () => _startComment(checkIn),
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

/// The bar above the page: back to the person, and — behind *More* — the
/// sheet that edits everything at once, for the fields no chip carries
/// (topics, the notes for next time, the logged note).
class _TopBar extends StatelessWidget {
  const _TopBar({this.onBack, this.onEdit});

  final VoidCallback? onBack;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step2,
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              key: const ValueKey('check-in-detail-back'),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack,
              icon: const Icon(LottiIcons.back),
            ),
          const Spacer(),
          if (onEdit != null)
            MenuAnchor(
              builder: (context, controller, _) => IconButton(
                key: const ValueKey('check-in-detail-more'),
                tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                icon: const Icon(LottiIcons.moreVertical),
              ),
              menuChildren: [
                MenuItemButton(
                  key: const ValueKey('check-in-detail-edit'),
                  leadingIcon: const Icon(LottiIcons.edit),
                  onPressed: onEdit,
                  child: Text(context.messages.checkInEditTitle),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The scrolling page: the header, the notes for next time and the
/// timeline, centred at the reading width a task's page uses.
class _Body extends StatelessWidget {
  const _Body({
    required this.checkIn,
    required this.personName,
    required this.entries,
    required this.entryKeyBuilder,
    required this.onPickType,
    required this.onPickStart,
    required this.onPickDuration,
    required this.onPickSentiment,
  });

  final CheckInEntry checkIn;
  final String personName;

  /// What the check-in holds, oldest first.
  final List<JournalEntity> entries;
  final GlobalKey Function(String entryId) entryKeyBuilder;
  final VoidCallback onPickType;
  final VoidCallback onPickStart;
  final VoidCallback onPickDuration;
  final VoidCallback onPickSentiment;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final data = checkIn.data;
    final length = checkIn.meta.dateTo.difference(checkIn.meta.dateFrom);
    final note = checkIn.entryText?.plainText.trim() ?? '';
    final guidance = [
      if (data.payAttentionTo?.trim() case final text? when text.isNotEmpty)
        (messages.relationshipPayAttentionTo, text),
      if (data.avoid?.trim() case final text? when text.isNotEmpty)
        (messages.checkInAvoidLabel, text),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = math.max(
          tokens.spacing.step5,
          (constraints.maxWidth - kDetailContentMaxWidth) / 2,
        );
        return ListView(
          key: const ValueKey('check-in-detail-list'),
          padding: EdgeInsets.fromLTRB(
            gutter,
            tokens.spacing.step2,
            gutter,
            tokens.spacing.step6,
          ),
          children: [
            Text(
              messages.relationshipCheckInTitle(personName),
              key: const ValueKey('check-in-detail-title'),
              style: tokens.typography.styles.heading.heading2.copyWith(
                color: tokens.colors.text.highEmphasis,
              ),
            ),
            SizedBox(height: tokens.spacing.step4),
            CheckInContextChips(
              type: data.interactionType,
              startedLabel: checkInStartedLabelOf(
                context,
                checkIn.meta.dateFrom,
              ),
              durationLabel: length <= Duration.zero
                  ? messages.checkInDurationChip
                  : checkInDurationLabel(context, length),
              sentiment: data.sentiment,
              onPickType: onPickType,
              onPickStart: onPickStart,
              onPickDuration: onPickDuration,
              onPickSentiment: onPickSentiment,
            ),
            if (data.topics.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step4),
              Wrap(
                key: const ValueKey('check-in-detail-topics'),
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
              SizedBox(height: tokens.spacing.sectionGap),
              _NextTimeCard(guidance: guidance),
            ],
            SizedBox(height: tokens.spacing.sectionGap),
            if (note.isNotEmpty) _NoteCard(checkIn: checkIn, note: note),
            if (entries.isNotEmpty)
              LinkedEntriesWidget(
                checkIn,
                entryKeyBuilder: entryKeyBuilder,
                showActivityFilters:
                    entries.length >= CheckInDetailView.filtersFrom,
              )
            else if (note.isEmpty)
              Text(
                messages.relationshipCheckInEmpty,
                key: const ValueKey('check-in-detail-empty'),
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
          ],
        );
      },
    );
  }
}

/// What to keep in mind next time, on a card of its own.
class _NextTimeCard extends StatelessWidget {
  const _NextTimeCard({required this.guidance});

  final List<(String, String)> guidance;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemSectionCard(
      key: const ValueKey('check-in-detail-next-time'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.relationshipNextTimeTitle,
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
      ),
    );
  }
}

/// The text a check-in was logged with, as the first card of its timeline:
/// the journal entry card's shell and its date language, stamped at the
/// check-in's start.
class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.checkIn, required this.note});

  final CheckInEntry checkIn;
  final String note;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final locale = Localizations.localeOf(context).toString();
    final at = checkIn.meta.dateFrom.toLocal();
    final stamp =
        '${DateFormat.yMMMd(locale).format(at)} '
        '${TimeOfDay.fromDateTime(at).format(context)}';
    return DesignSystemSectionCard(
      key: const ValueKey('check-in-detail-note'),
      // The linked entry cards' own margin, so the note lines up with the
      // cards that follow it.
      margin: EdgeInsets.only(
        left: tokens.spacing.step2,
        right: tokens.spacing.step2,
        bottom: tokens.spacing.step4,
      ),
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step4,
        tokens.spacing.step3,
        tokens.spacing.step4,
        tokens.spacing.step4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$stamp · ${context.messages.relationshipCheckInNoteLabel}',
            key: const ValueKey('check-in-detail-note-stamp'),
            style: tokens.typography.styles.others.caption.copyWith(
              color: tokens.colors.text.lowEmphasis,
              fontFeatures: numericBadgeFontFeatures,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
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

/// The floating glass bar that adds to the check-in's timeline — the task
/// page's action bar, carrying what a check-in holds: *Dictate* as the
/// primary pill, then a comment and photos. While [recorder] is set the
/// bar is the recorder.
class _CheckInActionBar extends StatelessWidget {
  const _CheckInActionBar({
    required this.recorder,
    required this.onDictate,
    required this.onComment,
    required this.onPhoto,
  });

  final Widget? recorder;
  final VoidCallback onDictate;
  final VoidCallback onComment;
  final VoidCallback onPhoto;

  /// The action row's width on a wide host, so the pills do not stretch
  /// into slabs — the day-planning bar's cap.
  static const double _actionsMaxWidth = 560;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spacing.step5,
          tokens.spacing.step4,
          tokens.spacing.step5,
          tokens.spacing.step4 + safeBottom,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _actionsMaxWidth),
            child:
                recorder ??
                // Wraps rather than overflows: at large text on a narrow
                // phone the labelled pill and the round buttons take two
                // lines instead of clipping.
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: tokens.spacing.step3,
                  runSpacing: tokens.spacing.step3,
                  children: [
                    DsGlassPill(
                      key: const ValueKey('check-in-detail-dictate'),
                      icon: LottiIcons.mic,
                      label: messages.checkInDictateButton,
                      fillColor: tokens.colors.interactive.enabled,
                      foregroundColor: tokens.colors.text.onInteractiveAlert,
                      onTap: onDictate,
                    ),
                    DsGlassRoundButton(
                      key: const ValueKey('check-in-detail-comment'),
                      icon: LottiIcons.editNote,
                      semanticLabel: messages.relationshipCheckInAddComment,
                      onPressed: onComment,
                    ),
                    DsGlassRoundButton(
                      key: const ValueKey('check-in-detail-photo'),
                      icon: LottiIcons.image,
                      semanticLabel: messages.relationshipCheckInAddPhoto,
                      onPressed: onPhoto,
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}
