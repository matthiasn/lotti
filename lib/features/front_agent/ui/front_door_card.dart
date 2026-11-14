import 'package:intl/intl.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/features/agents/query/query_source_access.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/model/front_task_draft.dart';
import 'package:lotti/features/front_agent/ui/front_task_setup.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';
import 'package:lotti/widgets/markdown/citation_badge.dart';
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
/// replied. One card per segment, and every card the same shape: a kind
/// tile, the words in full, one status line, at most one filled action —
/// the tap that writes (decision 1), or *Open* on what was written — and an
/// overflow menu holding every other way out. A settled card's tile is the
/// done glyph, a failed one's the warning, so state is more than a shade of
/// grey.
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
    this.journalAccess,
    super.key,
  });

  final List<FrontDoorEntry> doors;

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

  void _setUp(String doorId, {required bool on}) => setState(
    () => _settingUp = on ? doorId : (_settingUp == doorId ? null : _settingUp),
  );

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final FrontDoorCard(
      :doors,
      :actions,
      :journalAccess,
      :busyDoorIds,
      :failedDoorIds,
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
                settingUp: _settingUp == door.doorId,
                quiet: _settingUp != null && _settingUp != door.doorId,
                onSetUp: ({required on}) => _setUp(door.doorId, on: on),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One door as a card row: tile, words, status, action, overflow — or,
/// for an inbox item being made a task, the question of how
/// ([FrontTaskSetup]) in place of the status, action and overflow.
class _DoorRow extends StatelessWidget {
  const _DoorRow({
    required this.door,
    required this.actions,
    required this.busy,
    required this.failed,
    required this.settingUp,
    required this.quiet,
    required this.onSetUp,
    this.journalAccess,
    super.key,
  });

  final FrontDoorEntry door;
  final FrontDoorActions? actions;
  final QueryAccessSnapshot? journalAccess;
  final bool busy;
  final bool failed;

  /// Whether *Make it a task* was tapped and the task is being set up.
  final bool settingUp;

  /// Whether another item is being set up: this one's action steps back.
  final bool quiet;

  /// Starts (`on`) or leaves the setup.
  final void Function({required bool on}) onSetUp;

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
    var sources = const <QueryEvidence>[];
    final menu = <DesignSystemContextMenuItem>[];

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
    Widget open() => DesignSystemButton(
      key: ValueKey('front-door-open-$index'),
      label: messages.frontDoorOpen,
      variant: DesignSystemButtonVariant.secondary,
      onPressed: acting == null ? null : guarded(() => acting.onOpen(door)),
    );

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
        if (visible) sources = answer.evidence;
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
        glyph = LottiIcons.confirmCircled;
        ink = tokens.colors.alert.success.ink;
        if (acting != null) action = open();
      case FrontDoorInbox(:final newKind, :final ownerId):
        // While it is set up, the headline is the title she read — the one
        // the task will be made with — so "here's what I heard" shows it.
        title = acting != null && settingUp
            ? record.task?.title ?? words
            : words;
        status = ownerId == null
            ? messages.frontDoorInbox
            : messages.frontDoorInboxInstead;
        glyph = _guessGlyph(newKind);
        if (acting != null && settingUp) {
          setup = FrontTaskSetup(
            index: index,
            initial: FrontTaskChoices.of(record.task),
            heard: record.task?.namesChoices ?? false,
            // The overflow's slot, which the setup takes over.
            endInset:
                tokens.spacing.step1 +
                DesignSystemContextMenuButton.extent(tokens),
            busy: busy,
            failed: failed,
            onCreate: (choices) => acting.onMakeTask(id, choices),
            onBack: () => onSetUp(on: false),
          );
        } else if (acting != null) {
          action = DesignSystemButton(
            key: ValueKey('front-door-task-$index'),
            label: messages.frontDoorMakeTask,
            variant: quiet
                ? DesignSystemButtonVariant.secondary
                : DesignSystemButtonVariant.primary,
            onPressed: guarded(() => onSetUp(on: true)),
          );
          // The router's guess leads the other ways; leaving it comes last.
          final ways = [
            (
              'goal',
              messages.frontDoorStartGoal,
              LottiIcons.focus,
              () => acting.onStartGoal(door),
            ),
            if (newKind == FrontNewKind.project)
              (
                'project',
                messages.frontDoorNewProject,
                LottiIcons.folder,
                () => acting.onNewProject(door),
              ),
            if (acting.onMakeEvent case final makeEvent?)
              (
                'event',
                messages.frontDoorMakeEvent,
                LottiIcons.calendar,
                () => makeEvent(id),
              ),
            (
              'note',
              messages.frontDoorSaveNote,
              LottiIcons.note,
              () => acting.onSaveNote(id),
            ),
          ];
          final guess = switch (newKind) {
            FrontNewKind.goal => 'goal',
            FrontNewKind.project => 'project',
            FrontNewKind.task || null => null,
          };
          ways.sort((a, b) {
            if (a.$1 == guess) return -1;
            if (b.$1 == guess) return 1;
            return 0;
          });
          menu.addAll([
            for (final (name, label, icon, go) in ways)
              item(name, label, icon, go),
            item(
              'decline',
              messages.frontDoorLeaveIt,
              LottiIcons.close,
              () => acting.onDecline(id),
            ),
          ]);
        }
      case FrontDoorFiled(:final ownerId):
        title = words;
        status = ownerId == null
            ? messages.frontDoorSavedAsNote
            : messages.frontDoorFiledUnder(owner);
        glyph = LottiIcons.confirmCircled;
        ink = tokens.colors.alert.success.ink;
        if (acting != null) {
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
      case FrontDoorTaskCreated() || FrontDoorEventCreated():
        title = words;
        status = record.outcome is FrontDoorEventCreated
            ? messages.frontDoorEventCreated
            : messages.frontDoorTaskCreated;
        glyph = LottiIcons.confirmCircled;
        ink = tokens.colors.alert.success.ink;
        if (acting != null) {
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
          : tokens.colors.text.mediumEmphasis,
    );

    return Row(
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
              if (isAnswer)
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
                ),
              // The evidence is set apart from the answer under a heading
              // of its own, so the words read first and the sources after.
              if (sources.isNotEmpty)
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
              for (final (number, source) in sources.indexed)
                _SourceRow(
                  key: ValueKey('front-door-source-$index-$number'),
                  number: number + 1,
                  evidence: source,
                  onOpen: switch (acting?.onOpenEvidence) {
                    final open? => () => open(source),
                    null => null,
                  },
                ),
              // The setup is her question: a step more air above it groups it
              // with its chips, not as a subtitle of the words.
              SizedBox(
                height: setup == null
                    ? tokens.spacing.step1
                    : tokens.spacing.step3,
              ),
              if (setup != null)
                setup
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        failed ? messages.frontDoorActionFailed : status,
                        key: ValueKey('front-door-status-$index'),
                        style: statusStyle,
                      ),
                    ),
                    if (action != null) ...[
                      SizedBox(width: tokens.spacing.step2),
                      action,
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
    FrontDestinationKind.newThing ||
    FrontDestinationKind.unrouted => LottiIcons.inbox,
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
      FrontDestinationKind.unrouted => messages.frontDoorKindOther,
    };
  }
}

/// One source a journal answer cites, numbered as the answer cites it: the
/// badge its citations wear, what it is and when, and the passage it gave,
/// opening the source on a tap.
class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.number,
    required this.evidence,
    required this.onOpen,
    super.key,
  });

  final int number;
  final QueryEvidence evidence;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final caption = tokens.typography.styles.others.caption;
    final quote = evidence.quote.trim();
    // A recording's label is its file name, which says nothing a reader can
    // use; what it is and when does.
    final label =
        evidence.kind == QuerySourceKind.recording &&
            evidence.textVersion.startsWith('transcript:')
        ? messages.queryRecordingTranscript
        : evidence.label;
    final date = DateFormat.yMMMd(
      Localizations.localeOf(context).toString(),
    ).add_Hm().format(evidence.sourceDate);
    // The card is drawn on a plain box; the ink needs a surface of its own.
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(tokens.radii.s),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.step2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CitationBadge('$number'),
              SizedBox(width: tokens.spacing.step3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        text: label,
                        children: [
                          TextSpan(
                            text: ' · $date',
                            style: caption.copyWith(
                              color: tokens.colors.text.lowEmphasis,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: caption.copyWith(
                        color: tokens.colors.text.highEmphasis,
                      ),
                    ),
                    if (quote.isNotEmpty)
                      // The passage as quoted, set off by a rule like a
                      // blockquote.
                      Container(
                        margin: EdgeInsets.only(top: tokens.spacing.step1),
                        padding: EdgeInsetsDirectional.only(
                          start: tokens.spacing.step3,
                        ),
                        decoration: BoxDecoration(
                          border: BorderDirectional(
                            start: BorderSide(
                              color: tokens.colors.decorative.level02,
                            ),
                          ),
                        ),
                        child: Text(
                          quote,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: caption.copyWith(
                            color: tokens.colors.text.mediumEmphasis,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
