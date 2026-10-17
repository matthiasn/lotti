import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/create/entry_creation_service.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/check_in_photo_analysis_trigger.dart';
import 'package:lotti/features/relationships/service/check_in_transcription_service.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_capture_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_duration_picker.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_inline_recorder.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_meta_summary_line.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_pickers.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_speech_state.dart';
import 'package:lotti/features/relationships/ui/widgets/person_brief_card.dart';
import 'package:lotti/features/speech/state/recorder_controller.dart';
import 'package:lotti/features/tasks/ui/header/desktop_task_header.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
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
        // Describes the photo where the person's profile assigns an
        // image-analysis skill, and tells the check-in its evidence changed.
        analysisTrigger: ref.read(checkInPhotoAnalysisTriggerProvider),
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

  /// The recorder a live take runs on, held from the moment Dictate is
  /// pressed: `dispose` may not touch `ref`, and it is in `dispose` that an
  /// escaped take gets its indicator back.
  AudioRecorderController? _recorder;
  bool _startingComment = false;

  /// The newest entry change the check-in was last brought up to, so one
  /// edit saves the check-in once.
  DateTime? _touchedFor;

  /// Scroll-to keys for the timeline's cards, so a comment started from the
  /// bar is brought into view.
  final Map<String, GlobalKey> _entryKeys = {};

  GlobalKey _keyFor(String entryId) =>
      _entryKeys.putIfAbsent(entryId, GlobalKey.new);

  /// Leaving while a take is live asks first — the recorder's own question,
  /// since only the audio is at stake — and discards it on Discard, so a
  /// recording can never keep running behind a page the user has left.
  /// Returns whether to go.
  Future<bool> _confirmLeaveRecording() async {
    if (!_recording) return true;
    // A stop already in flight holds the page: `cancel` would return at
    // once without discarding anything, and the entry would land behind a
    // page the user thought they had left. The take lands within a moment
    // — `_onRecorded` then clears `_recording` and back works as usual.
    if (_recorder?.isFinishing ?? false) return false;
    final messages = context.messages;
    final confirmed = await showConfirmationModal(
      context: context,
      title: messages.audioRecordingDiscardDialogTitle,
      message: messages.checkInDiscardRecordingBody,
      cancelLabel: messages.audioRecordingDiscardDialogCancel,
      confirmLabel: messages.audioRecordingDiscardDialogConfirm,
    );
    if (!confirmed || !mounted) return false;
    await _recorder?.cancel();
    if (mounted) setState(() => _recording = false);
    return true;
  }

  // Both short-circuit before the first `await` when nothing is recording,
  // so the ordinary back is as synchronous as it always was.
  Future<void> _back() async {
    if (_recording && !await _confirmLeaveRecording()) return;
    if (mounted) widget.onBack?.call();
  }

  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    if (didPop) return;
    if (_recording && !await _confirmLeaveRecording()) return;
    if (!mounted) return;
    // `pop` guarded by `canPop`, never `maybePop`: on a root route maybePop
    // bubbles and re-invokes this callback, which would loop. With the take
    // gone a pushed page pops; a root page simply stays, and the next back
    // goes through the scope unhindered.
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop(result);
  }

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
    // The recorder hid the floating indicator while it was up. A page torn
    // down mid-take — a route change, the desktop pane swapping people —
    // leaves the recording running, and the indicator is the only way left
    // to stop it; the composer's sheet restores it the same way.
    if (_recording) _recorder?.setModalVisible(modalVisible: false);
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _repository = ref.read(relationshipRepositoryProvider);
    // The entries and the links that attach them reload on their own
    // notifications, in either order: each re-checks against the other's
    // latest.
    ref
      ..listenManual(
        relationshipDetailControllerProvider(widget.relationshipId),
        (_, _) => _touchIfEntriesChanged(),
        fireImmediately: true,
      )
      ..listenManual(
        sortedLinkedEntriesProvider(widget.checkInId),
        (_, _) => _touchIfEntriesChanged(),
      );
  }

  /// Saves the check-in again when an entry changed, or was attached, after
  /// it. An entry counts from the later of its own last change and its link's
  /// creation, so a picture imported long ago and attached now — its entity
  /// reused, its date old — is new evidence all the same. An empty comment
  /// is not evidence yet — only its words are.
  void _touchIfEntriesChanged() {
    final detail = ref
        .read(relationshipDetailControllerProvider(widget.relationshipId))
        .value;
    final checkIn = _checkInOf(detail);
    if (checkIn == null) return;
    final attachedAt = {
      for (final link in ref.read(sortedLinkedEntriesProvider(checkIn.id)))
        link.toId: link.createdAt,
    };
    DateTime? newest;
    for (final entry
        in detail!.checkInEntries[checkIn.id] ?? const <JournalEntity>[]) {
      if (entry is JournalEntry &&
          (entry.entryText?.plainText.trim() ?? '').isEmpty) {
        continue;
      }
      final updated = entry.meta.updatedAt;
      final attached = attachedAt[entry.id];
      final at = attached != null && attached.isAfter(updated)
          ? attached
          : updated;
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

  /// The person's category as the task crumb draws it — its name beside its
  /// colour — or null where the person has none, or it is not cached.
  DesktopTaskHeaderCategory? _categoryOf(RelationshipEntry relationship) {
    final definition = ref
        .watch(entitiesCacheServiceProvider)
        ?.getCategoryById(relationship.meta.categoryId);
    if (definition == null) return null;
    return DesktopTaskHeaderCategory(
      label: definition.name,
      color: colorFromCssHex(
        definition.color,
        substitute: context.designTokens.colors.text.mediumEmphasis,
      ),
    );
  }

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

  /// *Add*: the logbook's Add sheet with the check-in as its host — the
  /// long tail a regular entry's bar offers: a timer, a linked task, a
  /// pasted or captured image and the rest. The sheet leaves out what only
  /// a task holds (a checklist, pull request tracking). What it creates is
  /// linked from the check-in; the detail controller reloads on that link,
  /// and [_touchIfEntriesChanged] saves the check-in once it holds
  /// something new. Its images go through the check-in's own analysis.
  Future<void> _openAddSheet(CheckInEntry checkIn) => ref
      .read(entryCreationServiceProvider)
      .showCreateEntryModal(
        context,
        linkedFromId: checkIn.id,
        categoryId: checkIn.meta.categoryId,
        // Its images are analysed as the bar's own photos are: on the
        // person's terms, the check-in saved again once a description lands.
        imageAnalysisTrigger: ref.read(checkInPhotoAnalysisTriggerProvider),
      );

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

    // While a take is live the page does not simply pop: the system back
    // and the bar's back both go through the discard question.
    return PopScope(
      canPop: !_recording,
      onPopInvokedWithResult: _onPopInvoked,
      child: Column(
        children: [
          _TopBar(
            onBack: widget.onBack == null ? null : _back,
            // Held, as the facts are, while a take is live.
            onEdit: checkIn == null || _recording
                ? null
                : () => showCheckInEditSheet(
                    context: context,
                    checkIn: checkIn,
                  ),
          ),
          Expanded(
            child: checkIn == null
                ? Center(
                    child: detail == null && detailAsync.isLoading
                        ? const DesignSystemSpinner()
                        : Text(
                            // A failed first load is an error; a person or
                            // check-in that resolved to nothing is gone.
                            detail == null && detailAsync.hasError
                                ? messages.commonError
                                : messages.relationshipCheckInGone,
                            key: const ValueKey('check-in-detail-gone'),
                            style: tokens.typography.styles.body.bodySmall
                                .copyWith(
                                  color: tokens.colors.text.mediumEmphasis,
                                ),
                          ),
                  )
                : _Body(
                    checkIn: checkIn,
                    // The nickname where there is one, as the composer says
                    // "with Pip": the title fits a line and the note comes up.
                    personName:
                        detail!.relationship.data.nickname ??
                        detail.relationship.data.title,
                    // The crumb names the person in full, as their own page
                    // does, under the category they are filed in.
                    personFullName: detail.relationship.data.title,
                    category: _categoryOf(detail.relationship),
                    onPersonTap: widget.onBack == null ? null : _back,
                    entries: detail.checkInEntries[checkIn.id] ?? const [],
                    hasLinks: ref
                        .watch(sortedLinkedEntriesProvider(checkIn.id))
                        .isNotEmpty,
                    entryKeyBuilder: _keyFor,
                    onPickType: () => _pickType(checkIn),
                    onPickStart: () => _pickStart(checkIn),
                    onPickDuration: () => _pickDuration(checkIn),
                    onPickSentiment: () => _pickSentiment(checkIn),
                    onEditTopics: () => showCheckInEditSheet(
                      context: context,
                      checkIn: checkIn,
                    ),
                    // Held — shown, not hidden — while a take is live: an
                    // edit sheet or a picker over a running recorder, with
                    // the floating indicator hidden, was a door to a
                    // recording nothing on screen could stop.
                    chipsEnabled: !_recording,
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
                      // No room for the orb over the check-in, and no header
                      // to say the take is live.
                      compact: true,
                      showStatus: true,
                    )
                  : null,
              onDictate: () => setState(() {
                _recording = true;
                _recorder = ref.read(audioRecorderControllerProvider.notifier);
              }),
              onComment: () => _startComment(checkIn),
              onPhoto: () => _addPhotos(checkIn),
              onAdd: () => _openAddSheet(checkIn),
            ),
        ],
      ),
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

/// The bar above the page: back to the person on the leading edge and, on
/// the trailing one, the menu that holds *Edit check-in* — a lever that sat
/// in the facts' lane as a dashed pill read as one more empty fact (design
/// review 2026-10-16).
class _TopBar extends StatelessWidget {
  const _TopBar({this.onBack, this.onEdit});

  final VoidCallback? onBack;

  /// Null while a take is live: no sheet opens over a running recorder.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step2,
      ),
      child: ConstrainedBox(
        // The bar keeps its height without a back, so the crumb sits at the
        // same place on the phone page and in the desktop pane.
        constraints: const BoxConstraints(
          minHeight: kMinInteractiveDimension,
        ),
        child: Row(
          children: [
            // The design system's icon action, as the person hero's header:
            // a raw `IconButton` was the one Material-default control on
            // the feature.
            if (onBack != null)
              DesignSystemIconAction(
                key: const ValueKey('check-in-detail-back'),
                // The chevron a task's page and the person hero lead back
                // with, not a third back glyph.
                icon: LottiIcons.chevronLeft,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
              ),
            const Spacer(),
            DesignSystemContextMenuButton(
              key: const ValueKey('check-in-detail-menu'),
              tooltip: context.messages.relationshipMoreActions,
              items: [
                DesignSystemContextMenuItem(
                  key: const ValueKey('check-in-detail-edit'),
                  label: context.messages.checkInEditTitle,
                  icon: LottiIcons.edit,
                  onTap: onEdit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The scrolling page, tiered as a task's page is (`DesktopTaskHeader` and
/// `TaskForm`): the crumb — the person's category and the person — the
/// title, the facts as one lane of read-outs, then a faint rule before the
/// words the check-in was logged with, sitting on the page the way a task's
/// description does; after them the notes for next time and the timeline,
/// centred at the reading width a task's page uses.
class _Body extends StatelessWidget {
  const _Body({
    required this.checkIn,
    required this.personName,
    required this.personFullName,
    required this.entries,
    required this.hasLinks,
    required this.entryKeyBuilder,
    required this.onPickType,
    required this.onPickStart,
    required this.onPickDuration,
    required this.onPickSentiment,
    required this.onEditTopics,
    this.category,
    this.onPersonTap,
    this.chipsEnabled = true,
  });

  final CheckInEntry checkIn;

  /// How the title calls the person — the nickname where there is one.
  final String personName;

  /// How the crumb calls the person — their name in full.
  final String personFullName;
  final DesktopTaskHeaderCategory? category;

  /// The crumb's person segment leads back to their page.
  final VoidCallback? onPersonTap;

  /// What the check-in holds, oldest first.
  final List<JournalEntity> entries;

  /// Whether anything is linked from the check-in — beyond [entries], a
  /// task or the like added through the Add sheet, which the timeline lists
  /// although the check-in does not hold it as evidence.
  final bool hasLinks;
  final GlobalKey Function(String entryId) entryKeyBuilder;
  final VoidCallback onPickType;
  final VoidCallback onPickStart;
  final VoidCallback onPickDuration;
  final VoidCallback onPickSentiment;

  /// The topics fact opens the edit sheet, where topics change.
  final VoidCallback onEditTopics;

  /// Whether the header's read-outs take a tap — not while a take is live.
  final bool chipsEnabled;

  bool get _showsTimeline => entries.isNotEmpty || hasLinks;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final data = checkIn.data;
    final note = checkIn.entryText?.plainText.trim() ?? '';

    return LayoutBuilder(
      builder: (context, constraints) {
        // The person page's `step5` rail, less the `step2` every card on
        // this page adds as its own margin (and the header block matches),
        // so the three People pages put their text on one left edge.
        final gutter =
            math.max(
              tokens.spacing.step5,
              (constraints.maxWidth - kDetailContentMaxWidth) / 2,
            ) -
            tokens.spacing.step2;
        return ListView(
          key: const ValueKey('check-in-detail-list'),
          padding: EdgeInsets.fromLTRB(
            gutter,
            tokens.spacing.step2,
            gutter,
            tokens.spacing.step6,
          ),
          children: [
            // The header block sits on the cards' edge — their `step2`
            // margin — so the page has one left rail from the crumb down.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The task header's own crumb and spacing: ancestry a full
                  // step4 above the title, the title bonded a tighter step3
                  // down to its facts.
                  TaskHierarchyCrumb(
                    key: const ValueKey('check-in-detail-crumb'),
                    category: category,
                    project: DesktopTaskHeaderProject(label: personFullName),
                    onCategoryTap: null,
                    onProjectTap: onPersonTap,
                  ),
                  SizedBox(height: tokens.spacing.step4),
                  Text(
                    messages.relationshipCheckInTitle(personName),
                    key: const ValueKey('check-in-detail-title'),
                    style: detailPageTitleStyle(tokens),
                  ),
                  SizedBox(height: tokens.spacing.step3),
                  CheckInMetaSummaryLine(
                    type: data.interactionType,
                    startedLabel: checkInStartedLabelOf(
                      context,
                      checkIn.meta.dateFrom,
                    ),
                    duration: checkIn.meta.dateTo.difference(
                      checkIn.meta.dateFrom,
                    ),
                    sentiment: data.sentiment,
                    topics: data.topics,
                    onPickType: onPickType,
                    onPickStart: onPickStart,
                    onPickDuration: onPickDuration,
                    onPickSentiment: onPickSentiment,
                    // The topics change in the edit sheet, so their fact
                    // opens it — the menu's *Edit check-in*, from where the
                    // topics are read.
                    onEdit: onEditTopics,
                    readOut: true,
                    enabled: chipsEnabled,
                  ),
                  SizedBox(height: tokens.spacing.sectionGap),
                  // The faint rule a task draws between its identity and its
                  // body, so the two read as anchored bands.
                  DesignSystemDivider(
                    key: const ValueKey('check-in-detail-rule'),
                    color: tokens.colors.decorative.level01,
                  ),
                  SizedBox(height: tokens.spacing.step4),
                  // The user's own words first, on the page itself where a
                  // task keeps its description — not boxed under a caption,
                  // which put the one thing the page is opened for a tier
                  // below the cards around it.
                  if (note.isNotEmpty)
                    SelectableText(
                      note,
                      key: const ValueKey('check-in-detail-note'),
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    )
                  else if (!_showsTimeline)
                    Text(
                      messages.relationshipCheckInEmpty,
                      key: const ValueKey('check-in-detail-empty'),
                      style: tokens.typography.styles.body.bodySmall.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                ],
              ),
            ),
            if (note.isNotEmpty || !_showsTimeline)
              SizedBox(height: tokens.spacing.step5),
            // The person page's own card for the same notes: the note to bring
            // up as its headline, what to avoid under it.
            if (PersonBriefCard.hasContent(checkIn))
              Padding(
                padding: EdgeInsets.only(
                  left: tokens.spacing.step2,
                  right: tokens.spacing.step2,
                  bottom: tokens.spacing.step4,
                ),
                child: PersonBriefCard(
                  key: const ValueKey('check-in-detail-next-time'),
                  source: checkIn,
                  meeting: null,
                  now: checkIn.meta.dateFrom,
                  showProvenance: false,
                ),
              ),
            if (_showsTimeline)
              LinkedEntriesWidget(
                checkIn,
                entryKeyBuilder: entryKeyBuilder,
                showActivityFilters:
                    entries.length >= CheckInDetailView.filtersFrom,
              ),
          ],
        );
      },
    );
  }
}

/// The floating glass bar that adds to the check-in's timeline — the task
/// page's action bar, carrying what a check-in holds: *Dictate* as the
/// primary pill, then a comment and photos, and last the plus that opens
/// the Add sheet for the long tail, as on a logbook entry's bar. While
/// [recorder] is set the bar is the recorder.
class _CheckInActionBar extends StatelessWidget {
  const _CheckInActionBar({
    required this.recorder,
    required this.onDictate,
    required this.onComment,
    required this.onPhoto,
    required this.onAdd,
  });

  final Widget? recorder;
  final VoidCallback onDictate;
  final VoidCallback onComment;
  final VoidCallback onPhoto;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    // On the page's reading column, measured the way the person page's bar
    // and this page's body measure it, so the three line up; the gaps are
    // the person bar's `step4`, not a third spacing of their own.
    return DesignSystemGlassStrip(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final column = detailContentInsets(
            context,
            availableWidth: constraints.maxWidth,
          );
          return Padding(
            padding: EdgeInsets.fromLTRB(
              column.left,
              tokens.spacing.step4,
              column.right,
              tokens.spacing.step4 + safeBottom,
            ),
            child:
                recorder ??
                // Wraps rather than overflows: at large text on a narrow
                // phone the labelled pill and the round buttons take two
                // lines instead of clipping.
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: tokens.spacing.step4,
                  runSpacing: tokens.spacing.step4,
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
                      // A speech-bubble glyph, not a pencil: the page's one
                      // pencil is Edit in the top bar, and two pencils with
                      // two meanings on one screen were indistinguishable
                      // before the tap.
                      icon: LottiIcons.chat,
                      semanticLabel: messages.relationshipCheckInAddComment,
                      onPressed: onComment,
                    ),
                    DsGlassRoundButton(
                      key: const ValueKey('check-in-detail-photo'),
                      icon: LottiIcons.image,
                      semanticLabel: messages.relationshipCheckInAddPhoto,
                      onPressed: onPhoto,
                    ),
                    DsGlassRoundButton(
                      key: const ValueKey('check-in-detail-add'),
                      icon: LottiIcons.add,
                      semanticLabel: messages.addLinkedEntryLabel,
                      onPressed: onAdd,
                    ),
                  ],
                ),
          );
        },
      ),
    );
  }
}
