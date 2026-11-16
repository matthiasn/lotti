import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:collection/collection.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_cited_answer.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/model/front_task_draft.dart';
import 'package:lotti/features/front_agent/ui/a2ui/front_reply_catalog.dart';
import 'package:lotti/features/front_agent/ui/a2ui/front_reply_surfaces.dart';
import 'package:lotti/features/front_agent/ui/front_cited_source_row.dart';
import 'package:lotti/features/front_agent/ui/front_door_ways.dart';
import 'package:lotti/features/front_agent/ui/front_task_setup.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';
import 'package:material_ui/material_ui.dart';

/// What the user can do under a door. Every callback takes the door's id,
/// except [onOpen], which needs what the door wrote; the surface decides
/// what each one writes or opens.
class FrontDoorActions {
  const FrontDoorActions({
    required this.onFile,
    required this.onDecline,
    required this.onUndoDecline,
    required this.onTakeBack,
    required this.onOpen,
    required this.onMakeTask,
    required this.onMakePrompt,
    required this.onSaveNote,
    required this.onStartGoal,
    required this.onNewProject,
    required this.onPlanDay,
    this.onMakeEvent,
    this.onOpenEvidence,
    this.onOpenLink,
  });

  /// File the proposal under its task or project — the one tap of
  /// decision 1.
  final ValueChanged<String> onFile;

  /// Say no to what a waiting door offers: a proposal's words go to the
  /// inbox, an inbox item is left where it is.
  final ValueChanged<String> onDecline;

  /// A left door waits again as what it was.
  final ValueChanged<String> onUndoDecline;

  /// Take back what the door wrote: the filed entry, the note, the task or
  /// the event.
  final ValueChanged<String> onTakeBack;

  /// Open what the door wrote.
  final ValueChanged<FrontDoorEntry> onOpen;

  /// Make a task of an inbox item, by its id, set up as the user chose in
  /// the card ([FrontTaskSetup]).
  final void Function(String doorId, FrontTaskChoices choices) onMakeTask;

  /// Make a task of an inbox item, by its id, with the choices she read
  /// from the words, and have a coding prompt written for it from them.
  final void Function(String doorId, FrontTaskChoices choices) onMakePrompt;

  /// Make an event of an inbox item; null where events are off, and the
  /// item offers no such way.
  final ValueChanged<String>? onMakeEvent;

  /// Save an inbox item as a note.
  final ValueChanged<String> onSaveNote;

  /// Open the goal wizard for an inbox item, with its words.
  final ValueChanged<FrontDoorEntry> onStartGoal;

  /// Open the project creation for an inbox item, with its words.
  final ValueChanged<FrontDoorEntry> onNewProject;

  /// Take a change to today into the Daily OS planning, with its words.
  final ValueChanged<FrontDoorEntry> onPlanDay;

  /// Open the source a journal answer cites.
  final ValueChanged<QueryEvidence>? onOpenEvidence;

  /// Open a link in an answer — a task it names, say — by its url.
  final ValueChanged<String>? onOpenLink;
}

/// What came back through the doors of one routed turn, as a stack of
/// cards under her reply — or under the user's bubble until she has
/// replied. One card per segment: a kind tile, the words in full, one
/// status line, at most one filled action — the tap that writes
/// (decision 1) — and an overflow menu holding every other way out. An
/// inbox item that waits is its choices instead: the question, the words
/// as the headline, and every way it can go as a row ([FrontDoorWays]). A
/// card that went a way is one row: the way's glyph in the success ink,
/// the words on one line, what became of them, and *Open*.
///
/// Specialist text is shown as the specialist's, under its owner's name —
/// never reworded by the front agent (decision 2) — and as what it is,
/// Markdown, whose links open through [FrontDoorActions.onOpenLink]; the
/// user's own words stay plain text. Her own answer from the
/// journal is shown as hers, with the sources it cites, and only while
/// [journalAccess] still shows all of them.
///
/// While an inbox item is being set up as a task, its *Create task* is the
/// card's one filled button: the other items' *Make it a task* step back to
/// the secondary look until it is made or left.
class FrontDoorCard extends StatefulWidget {
  const FrontDoorCard({
    required this.doors,
    this.actions,
    this.busyDoorIds = const {},
    this.failedDoorIds = const {},
    this.coverArtDoorIds = const {},
    this.journalAccess,
    super.key,
  });

  final List<FrontDoorEntry> doors;

  /// The waiting items a cover can be drawn for, by their door ids: those
  /// whose task would land in a category with a profile that draws. An
  /// item's setup offers its cover chip only when it is one of them.
  final Set<String> coverArtDoorIds;

  /// The live visibility of the sources journal answers cite; null until it
  /// is known, and a journal answer stays hidden until then.
  final QueryAccessSnapshot? journalAccess;

  /// Null renders the cards without their controls.
  final FrontDoorActions? actions;

  /// Doors whose action is in flight: their controls are disabled.
  final Set<String> busyDoorIds;

  /// Doors whose last action did not go through: they say so, and offer
  /// the controls again.
  final Set<String> failedDoorIds;

  @override
  State<FrontDoorCard> createState() => _FrontDoorCardState();
}

class _FrontDoorCardState extends State<FrontDoorCard> {
  /// The door whose *Make it a task* was tapped: being set up as a task.
  /// One at a time — opening another leaves the first, so Enter can only
  /// ever make the one just opened.
  String? _settingUp;

  /// The way last taken for each door, by its name: the row that shows
  /// progress while the item's action is in flight.
  final _taken = <String, String>{};

  @override
  void didUpdateWidget(FrontDoorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Made, left or taken back: a task set up before is not being set up
    // now — an item that waits again offers *Make it a task* afresh.
    final before = {
      for (final door in oldWidget.doors)
        door.doorId: door.record.outcome.runtimeType,
    };
    final id = _settingUp;
    if (id != null &&
        !widget.doors.any(
          (door) =>
              door.doorId == id &&
              door.record.outcome.runtimeType == before[id],
        )) {
      _settingUp = null;
    }
  }

  void _setUp(String doorId, {required bool on}) => setState(() {
    _settingUp = on ? doorId : (_settingUp == doorId ? null : _settingUp);
  });

  void _take(String doorId, String way) => setState(() => _taken[doorId] = way);

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final FrontDoorCard(
      :doors,
      :actions,
      :journalAccess,
      :busyDoorIds,
      :failedDoorIds,
      :coverArtDoorIds,
    ) = widget;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.background.level02,
        borderRadius: BorderRadius.circular(tokens.radii.l),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step4,
          vertical: tokens.spacing.step3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, door) in doors.indexed) ...[
              if (index > 0)
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: tokens.spacing.step3,
                  ),
                  child: const DesignSystemDivider(),
                ),
              _DoorRow(
                key: ValueKey('front-door-${door.record.segmentIndex}'),
                door: door,
                actions: actions,
                journalAccess: journalAccess,
                busy: busyDoorIds.contains(door.doorId),
                failed: failedDoorIds.contains(door.doorId),
                coverArtAvailable: coverArtDoorIds.contains(door.doorId),
                settingUp: _settingUp == door.doorId,
                onSetUp: ({required on}) => _setUp(door.doorId, on: on),
                taken: _taken[door.doorId],
                onTake: (way) => _take(door.doorId, way),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One door as a card row: tile, words, status, action, overflow — or,
/// for an inbox item that waits, its question, its words and its choices,
/// which the question of how ([FrontTaskSetup]) stands in for while it is
/// being made a task.
class _DoorRow extends StatelessWidget {
  const _DoorRow({
    required this.door,
    required this.actions,
    required this.busy,
    required this.failed,
    required this.settingUp,
    required this.onSetUp,
    required this.taken,
    required this.onTake,
    required this.coverArtAvailable,
    this.journalAccess,
    super.key,
  });

  final FrontDoorEntry door;

  /// Whether a cover can be drawn for the task this item would become
  /// ([FrontDoorCard.coverArtDoorIds]).
  final bool coverArtAvailable;
  final FrontDoorActions? actions;
  final QueryAccessSnapshot? journalAccess;
  final bool busy;
  final bool failed;

  /// Whether *Make it a task* was tapped and the task is being set up.
  final bool settingUp;

  /// Starts (`on`) or leaves the setup.
  final void Function({required bool on}) onSetUp;

  /// The way last taken for this item, by name: its row shows progress
  /// while [busy].
  final String? taken;

  /// Notes the way being taken, as it is.
  final ValueChanged<String> onTake;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final record = door.record;
    final owner = _ownerName(messages, record);
    final index = record.segmentIndex;
    final words = record.text.trim();
    final id = door.doorId;
    final acting = actions;
    void Function()? guarded(VoidCallback action) => busy ? null : action;

    // What the card says and offers, per outcome: the title, the status,
    // the tile's glyph and ink, the one action, the overflow's rows.
    var glyph = _kindGlyph(record.kind);
    var ink = tokens.colors.aiCard.accent;
    final String title;
    // An answer is an agent's Markdown; the user's words are text.
    var isAnswer = false;
    final String status;
    Widget? action;
    Widget? setup;
    // Whether the item went a way and is done: see `made`.
    var settled = false;
    var sources = const <QueryEvidence>[];
    // Her journal answer's points, when the thread drew them a surface.
    SurfaceModel<ComponentImplementation>? answerSurface;
    final menu = <DesignSystemContextMenuItem>[];

    // The ways an inbox item can go, and the way that leaves it: the
    // card's choices, every one in sight. Which of them are listed is hers
    // to say, on the surface the thread drew from what she picked for the
    // item's words.
    FrontDoorWaysFor? waysFor;
    SurfaceModel<ComponentImplementation>? waysSurface;
    FrontDoorWay? leave;

    DesignSystemContextMenuItem item(
      String name,
      String label,
      IconData icon,
      VoidCallback onTap,
    ) => DesignSystemContextMenuItem(
      key: ValueKey('front-door-$name-$index'),
      label: label,
      icon: icon,
      onTap: guarded(onTap),
    );
    // The way on: text and a chevron, where a filled button would be a
    // second thing to decide on a card that is done.
    Widget open() => DesignSystemButton(
      key: ValueKey('front-door-open-$index'),
      label: messages.frontDoorOpen,
      variant: DesignSystemButtonVariant.tertiary,
      trailingIcon: LottiIcons.chevronRight,
      onPressed: acting == null ? null : guarded(() => acting.onOpen(door)),
    );

    // Something the door made or filed, under the glyph of the [way] it
    // went, in the success ink: done, opened, or taken back. The card is
    // one row then — the words on one line, what became of them under it.
    void made(IconData way) {
      glyph = way;
      ink = tokens.colors.alert.success.ink;
      settled = true;
      if (acting == null) return;
      action = open();
      menu.add(
        item(
          'take-back',
          messages.frontDoorUndo,
          LottiIcons.undo,
          () => acting.onTakeBack(id),
        ),
      );
    }

    switch (record.outcome) {
      case null:
        title = words;
        status = record.kind == FrontDestinationKind.journal
            ? messages.frontDoorSearchingJournal
            : messages.frontDoorWalking(owner);
      case FrontDoorAnswer(fromJournal: true) && final answer:
        // Shown only while every source it rests on still is, as query chat
        // does; until that is known it stays hidden too.
        final visible =
            journalAccess?.allowsContent(
              answer.dependencies,
              private: answer.private,
            ) ??
            false;
        title = visible ? answer.text : messages.frontDoorAnswerHidden;
        if (visible) {
          sources = answer.evidence;
          answerSurface = FrontReplySurfaces.surfaceOf(
            context,
            frontDoorAnswerSurfaceId(id),
          );
        }
        isAnswer = visible;
        status = [
          messages.frontDoorFromJournal,
          if (answer.incomplete) messages.frontDoorIncomplete,
        ].join(' · ');
      case FrontDoorAnswer(:final text, :final summaryBased, :final incomplete):
        title = text;
        isAnswer = true;
        status = [
          messages.frontDoorAttribution(owner),
          if (summaryBased) messages.frontDoorSummaryBased,
          if (incomplete) messages.frontDoorIncomplete,
        ].join(' · ');
      case FrontDoorChatTurn() when door.specialistReply != null:
        title = door.specialistReply!;
        isAnswer = true;
        status = messages.frontDoorAttribution(owner);
      case FrontDoorChatTurn():
        title = words;
        status = messages.frontDoorAwaitingReply(owner);
      case FrontDoorSkipped(:final reason):
        title = words;
        status = switch (reason) {
          FrontDoorSkipReason.noAgent => messages.frontDoorNoAgent(owner),
          FrontDoorSkipReason.inferenceUnavailable
              when record.kind == FrontDestinationKind.journal =>
            messages.frontDoorJournalUnavailable,
          FrontDoorSkipReason.inferenceUnavailable =>
            messages.frontDoorInferenceUnavailable(owner),
          FrontDoorSkipReason.noDoor => messages.frontDoorNoDoor,
        };
      case FrontDoorFailed():
        title = words;
        status = messages.frontDoorFailed(owner);
        glyph = LottiIcons.warning;
        ink = tokens.colors.alert.error.ink;
      case FrontDoorProposal(:final unfiled):
        title = words;
        status = unfiled
            ? messages.frontDoorUnfiled(owner)
            : messages.frontDoorProposal(owner);
        glyph = LottiIcons.checkboxChecked;
        if (acting != null) {
          action = DesignSystemButton(
            key: ValueKey('front-door-file-$index'),
            label: failed ? messages.frontDoorTryAgain : messages.frontDoorFile,
            isLoading: busy,
            onPressed: guarded(() => acting.onFile(id)),
          );
          menu.add(
            item(
              'decline',
              messages.frontDoorNotThis,
              LottiIcons.inbox,
              () => acting.onDecline(id),
            ),
          );
        }
      case FrontDoorDay():
        title = words;
        status = messages.frontDoorDayProposal;
        if (acting != null) {
          action = DesignSystemButton(
            key: ValueKey('front-door-day-$index'),
            label: messages.frontDoorChangeDay,
            // Busy while the planning is open, so a second tap opens none.
            isLoading: busy,
            onPressed: guarded(() => acting.onPlanDay(door)),
          );
          menu.add(
            item(
              'decline',
              messages.frontDoorNotThis,
              LottiIcons.inbox,
              () => acting.onDecline(id),
            ),
          );
        }
      case FrontDoorDayPlanned():
        title = words;
        status = messages.frontDoorDayPlanned;
        glyph = LottiIcons.confirmCircled;
        ink = tokens.colors.alert.success.ink;
        if (acting != null) action = open();
      case FrontDoorProjectCreated():
        title = words;
        status = messages.frontDoorProjectCreated;
        glyph = LottiIcons.folder;
        ink = tokens.colors.alert.success.ink;
        settled = true;
        if (acting != null) action = open();
      case FrontDoorInbox(:final newKind, :final ownerId):
        // A drafted task's headline is the title she read — the one the task
        // will be made with — so "here's what I heard" shows it, and a
        // "yes, make it a task" is never the headline.
        final draft = record.task;
        title = acting != null ? draft?.title ?? words : words;
        status = ownerId == null
            ? messages.frontDoorInbox
            : messages.frontDoorInboxInstead;
        glyph = _guessGlyph(newKind);
        if (acting != null && settingUp) {
          setup = FrontTaskSetup(
            index: index,
            initial: FrontTaskChoices.of(record.task),
            heard: record.task?.namesChoices ?? false,
            // Offered where a profile can draw one for the task it would
            // become: elsewhere the chip is not there to ask.
            coverArtAvailable: coverArtAvailable,
            busy: busy,
            failed: failed,
            onCreate: (choices) => acting.onMakeTask(id, choices),
            onBack: () => onSetUp(on: false),
          );
        } else if (acting != null) {
          // The router's guess is the one tinted row. A task is its guess
          // only where the user asked for one — where she drafted it; words
          // nobody asked to be a task offer it as a way like the others.
          final guess = switch (newKind) {
            FrontNewKind.goal => 'goal',
            FrontNewKind.project => 'project',
            FrontNewKind.task when draft != null => 'task',
            FrontNewKind.task || null => null,
          };
          // A way says what choosing it does, the names alone leaving "a
          // goal" and "a note" a guess; taken, its row shows the progress.
          FrontDoorWay way(
            String name,
            String label,
            String hint,
            IconData icon,
            VoidCallback go,
          ) => FrontDoorWay(
            name: name,
            label: label,
            hint: hint,
            icon: icon,
            suggested: name == guess,
            inFlight: busy && taken == name,
            onTap: guarded(() {
              onTake(name);
              go();
            }),
          );
          final offered = [
            way(
              'task',
              messages.frontDoorMakeTask,
              messages.frontDoorMakeTaskHint,
              LottiIcons.checkboxChecked,
              () => onSetUp(on: true),
            ),
            way(
              'prompt',
              messages.frontDoorMakePrompt,
              messages.frontDoorMakePromptHint,
              LottiIcons.code,
              () => acting.onMakePrompt(id, FrontTaskChoices.of(record.task)),
            ),
            way(
              'goal',
              messages.frontDoorStartGoal,
              messages.frontDoorStartGoalHint,
              LottiIcons.focus,
              () => acting.onStartGoal(door),
            ),
            way(
              'project',
              messages.frontDoorNewProject,
              messages.frontDoorNewProjectHint,
              LottiIcons.folder,
              () => acting.onNewProject(door),
            ),
            if (acting.onMakeEvent case final makeEvent?)
              way(
                'event',
                messages.frontDoorMakeEvent,
                messages.frontDoorMakeEventHint,
                LottiIcons.calendar,
                () => makeEvent(id),
              ),
            way(
              'note',
              messages.frontDoorSaveNote,
              messages.frontDoorSaveNoteHint,
              LottiIcons.note,
              () => acting.onSaveNote(id),
            ),
          ];
          // Making a task of it and keeping it as a note are always
          // offered, and so is the router's guess, which leads. The rest
          // are those she picked for the words; where she picked none —
          // an item from before she did, a block she left out — every way
          // is offered, a project only as the guess.
          waysFor = (picked) {
            final shown = offered.where(
              (way) => switch (way.name) {
                'task' || 'note' => true,
                final name when name == guess => true,
                'project' => picked?.contains('project') ?? false,
                final name => picked?.contains(name) ?? true,
              },
            );
            return [
              ...shown.where((way) => way.name == guess),
              ...shown.where((way) => way.name != guess),
            ];
          };
          waysSurface = FrontReplySurfaces.surfaceOf(
            context,
            frontDoorWaysSurfaceId(id),
          );
          // The way out makes nothing: the item stays, left, in the inbox.
          // It is one line and no row, so it has no hint of its own.
          leave = way(
            'decline',
            messages.frontDoorLeaveIt,
            '',
            LottiIcons.inbox,
            () => acting.onDecline(id),
          );
        }
      case FrontDoorFiled(:final ownerId):
        title = words;
        status = ownerId == null
            ? messages.frontDoorSavedAsNote
            : messages.frontDoorFiledUnder(owner);
        // A note under the note's glyph; something filed, under its owner's.
        made(ownerId == null ? LottiIcons.note : _kindGlyph(record.kind));
      case FrontDoorTaskCreated(:final extras):
        title = words;
        // What was asked for with the task is said after it, in the order
        // it was offered: the prompt's menu row, then the cover's chip.
        status = [
          messages.frontDoorTaskCreated,
          if (extras.contains(FrontTaskExtra.codingPrompt))
            messages.frontDoorPromptRequested,
          if (extras.contains(FrontTaskExtra.coverArt))
            messages.frontDoorCoverRequested,
        ].join(' · ');
        made(LottiIcons.checkboxChecked);
      case FrontDoorEventCreated():
        title = words;
        status = messages.frontDoorEventCreated;
        made(LottiIcons.calendar);
      case FrontDoorDeclined(:final ownerId):
        title = words;
        status = ownerId == null
            ? messages.frontDoorLeft
            : messages.frontDoorDeclined;
        glyph = ownerId == null ? LottiIcons.inbox : LottiIcons.checkboxChecked;
        ink = tokens.colors.text.lowEmphasis;
        if (acting != null) {
          menu.add(
            item(
              'undo',
              messages.frontDoorUndo,
              LottiIcons.undo,
              () => acting.onUndoDecline(id),
            ),
          );
        }
    }

    final titleStyle = tokens.typography.styles.body.bodyMedium.copyWith(
      color: tokens.colors.text.highEmphasis,
    );
    final statusStyle = tokens.typography.styles.others.caption.copyWith(
      color: failed
          ? tokens.colors.alert.error.ink
          : settled
          ? tokens.colors.alert.success.ink
          : tokens.colors.text.mediumEmphasis,
    );

    final statusText = Text(
      failed ? messages.frontDoorActionFailed : status,
      key: ValueKey('front-door-status-$index'),
      style: statusStyle,
    );
    // A waiting inbox item is its choices: the question, the words as the
    // headline — under no glyph, nothing being decided yet — and every way
    // as a row, a tap on one doing it. Being made a task, the setup stands
    // where the choices stood.
    if (setup != null || (leave != null && waysFor != null)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (setup == null) ...[
            statusText,
            SizedBox(height: tokens.spacing.step1),
          ],
          Text(
            title,
            key: ValueKey('front-door-text-$index'),
            style: tokens.typography.styles.subtitle.subtitle1.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step4),
          if (setup != null)
            setup
          // The ways she picked for the words: an A2UI surface of the reply
          // catalog, whose `InboxWays` draws the list from what this card
          // offers.
          else if (waysSurface case final surface?)
            FrontDoorWaysScope(
              index: index,
              waysFor: waysFor!,
              leave: leave!,
              child: A2uiSurface(key: ObjectKey(surface), surface: surface),
            )
          else
            FrontDoorWays(index: index, ways: waysFor!(null), leave: leave!),
        ],
      );
    }
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Tile(
          glyph: glyph,
          ink: ink,
          glyphKey: ValueKey('front-door-glyph-$index'),
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (answerSurface != null)
                // Her journal answer as its points, each with the entries it
                // rests on: an A2UI surface of the reply catalog, composed by
                // the app (`FrontChatThread.surfaces`).
                FrontReplyScope(
                  key: ValueKey('front-door-text-$index'),
                  surface: answerSurface,
                  prose: (markdown) => AgentMarkdownView(
                    markdown,
                    style: titleStyle,
                    onLinkTap: switch (acting?.onOpenLink) {
                      final open? => (url, _) => open(url),
                      null => null,
                    },
                  ),
                  onOpen: (_) {},
                  onOpenTask: (_) {},
                  onOpenSource: switch (acting?.onOpenEvidence) {
                    final open? => (cited) {
                      if (sources.firstWhereOrNull(
                            (e) => e.source.id == cited.id,
                          )
                          case final evidence?) {
                        open(evidence);
                      }
                    },
                    null => null,
                  },
                  child: Material(
                    type: MaterialType.transparency,
                    child: A2uiSurface(
                      key: ObjectKey(answerSurface),
                      surface: answerSurface,
                    ),
                  ),
                )
              else if (isAnswer)
                // The card is drawn on a plain box; a link's ink needs a
                // surface of its own.
                Material(
                  type: MaterialType.transparency,
                  child: AgentMarkdownView(
                    title,
                    key: ValueKey('front-door-text-$index'),
                    style: titleStyle,
                    onLinkTap: switch (acting?.onOpenLink) {
                      final open? => (url, _) => open(url),
                      null => null,
                    },
                    // `[n]` opens the n-th source, as its row below does.
                    onCitationTap: switch (acting?.onOpenEvidence) {
                      final open? => (number) {
                        if (number >= 1 && number <= sources.length) {
                          open(sources[number - 1]);
                        }
                      },
                      null => null,
                    },
                  ),
                )
              else
                Text(
                  title,
                  key: ValueKey('front-door-text-$index'),
                  style: titleStyle,
                  // Done, the card is one row: the words are on the page
                  // *Open* leads to.
                  maxLines: settled ? 1 : null,
                  overflow: settled ? TextOverflow.ellipsis : null,
                ),
              // Without its surface the answer is her Markdown, and the
              // evidence is set apart under a heading of its own.
              if (answerSurface == null && sources.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(
                    top: tokens.spacing.step4,
                    bottom: tokens.spacing.step1,
                  ),
                  child: Text(
                    messages.frontDoorSources,
                    key: ValueKey('front-door-sources-$index'),
                    style: tokens.typography.styles.others.caption.copyWith(
                      color: tokens.colors.text.mediumEmphasis,
                    ),
                  ),
                ),
              if (answerSurface == null)
                for (final (number, source) in sources.indexed)
                  FrontCitedSourceRow(
                    key: ValueKey('front-door-source-$index-$number'),
                    number: number + 1,
                    source: FrontCitedSource.fromEvidence(source),
                    onOpen: switch (acting?.onOpenEvidence) {
                      final open? => () => open(source),
                      null => null,
                    },
                  ),
              SizedBox(height: tokens.spacing.step1),
              Row(
                children: [
                  Expanded(child: statusText),
                  if (action case final button?) ...[
                    SizedBox(width: tokens.spacing.step2),
                    button,
                  ],
                  if (menu.isNotEmpty) ...[
                    SizedBox(width: tokens.spacing.step1),
                    DesignSystemContextMenuButton(
                      key: ValueKey('front-door-menu-$index'),
                      items: menu,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
    return row;
  }

  /// The glyph for where a segment went.
  static IconData _kindGlyph(FrontDestinationKind kind) => switch (kind) {
    FrontDestinationKind.task => LottiIcons.checkboxChecked,
    FrontDestinationKind.project => LottiIcons.folder,
    FrontDestinationKind.goal => LottiIcons.focus,
    FrontDestinationKind.person => LottiIcons.person,
    FrontDestinationKind.day => LottiIcons.calendar,
    // A journal question is searched; a journal statement lands in the
    // inbox, whose glyph replaces this one.
    FrontDestinationKind.journal => LottiIcons.search,
    // Words meant for her are never drawn (the thread builder drops them).
    FrontDestinationKind.newThing ||
    FrontDestinationKind.unrouted ||
    FrontDestinationKind.you => LottiIcons.inbox,
  };

  /// The glyph for what the router thought an inbox item would become.
  static IconData _guessGlyph(FrontNewKind? kind) => switch (kind) {
    FrontNewKind.task => LottiIcons.checkboxChecked,
    FrontNewKind.goal => LottiIcons.focus,
    FrontNewKind.project => LottiIcons.folder,
    null => LottiIcons.inbox,
  };

  /// The owner's title when the walker found one, else the kind of thing
  /// the segment went to, so the line never names an id.
  static String _ownerName(AppLocalizations messages, FrontDoorRecord record) {
    final title = record.ownerTitle?.trim();
    if (title != null && title.isNotEmpty) return title;
    return switch (record.kind) {
      FrontDestinationKind.task => messages.frontDoorKindTask,
      FrontDestinationKind.project => messages.frontDoorKindProject,
      FrontDestinationKind.goal => messages.frontDoorKindGoal,
      FrontDestinationKind.person => messages.frontDoorKindPerson,
      FrontDestinationKind.day ||
      FrontDestinationKind.newThing ||
      FrontDestinationKind.journal ||
      FrontDestinationKind.unrouted ||
      FrontDestinationKind.you => messages.frontDoorKindOther,
    };
  }
}

/// The compact tinted tile that leads a card row, carrying its glyph.
class _Tile extends StatelessWidget {
  const _Tile({required this.glyph, required this.ink, required this.glyphKey});

  final IconData glyph;
  final Color ink;
  final Key glyphKey;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Container(
      width: ControlSizes.iconChipCompact,
      height: ControlSizes.iconChipCompact,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tokens.colors.aiCard.accentSoft,
        borderRadius: BorderRadius.circular(tokens.radii.s),
      ),
      child: Icon(glyph, key: glyphKey, size: IconSizes.s, color: ink),
    );
  }
}
