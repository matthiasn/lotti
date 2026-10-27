import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
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
  });

  /// File the proposal under its task — the one tap of decision 1.
  final ValueChanged<String> onFile;

  /// Say no to what a waiting door offers: a proposal's words go to the
  /// inbox, an inbox item is left where it is.
  final ValueChanged<String> onDecline;

  /// A left door waits again as what it was.
  final ValueChanged<String> onUndoDecline;

  /// Take back what the door wrote: the filed entry, the note or the task.
  final ValueChanged<String> onTakeBack;

  /// Open what the door wrote.
  final ValueChanged<FrontDoorEntry> onOpen;

  /// Make a task of an inbox item.
  final ValueChanged<String> onMakeTask;

  /// Save an inbox item as a note.
  final ValueChanged<String> onSaveNote;

  /// Open the goal wizard for an inbox item.
  final ValueChanged<String> onStartGoal;

  /// Open the project creation for an inbox item.
  final ValueChanged<String> onNewProject;
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
/// never reworded by the front agent (decision 2).
class FrontDoorCard extends StatelessWidget {
  const FrontDoorCard({
    required this.doors,
    this.actions,
    this.busyDoorIds = const {},
    this.failedDoorIds = const {},
    super.key,
  });

  final List<FrontDoorEntry> doors;

  /// Null renders the cards without their controls.
  final FrontDoorActions? actions;

  /// Doors whose action is in flight: their controls are disabled.
  final Set<String> busyDoorIds;

  /// Doors whose last action did not go through: they say so, and offer
  /// the controls again.
  final Set<String> failedDoorIds;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
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
                busy: busyDoorIds.contains(door.doorId),
                failed: failedDoorIds.contains(door.doorId),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One door as a card row: tile, words, status, action, overflow.
class _DoorRow extends StatelessWidget {
  const _DoorRow({
    required this.door,
    required this.actions,
    required this.busy,
    required this.failed,
    super.key,
  });

  final FrontDoorEntry door;
  final FrontDoorActions? actions;
  final bool busy;
  final bool failed;

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
    final String status;
    Widget? action;
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
        status = messages.frontDoorWalking(owner);
      case FrontDoorAnswer(:final text, :final summaryBased, :final incomplete):
        title = text;
        status = [
          messages.frontDoorAttribution(owner),
          if (summaryBased) messages.frontDoorSummaryBased,
          if (incomplete) messages.frontDoorIncomplete,
        ].join(' · ');
      case FrontDoorChatTurn() when door.specialistReply != null:
        title = door.specialistReply!;
        status = messages.frontDoorAttribution(owner);
      case FrontDoorChatTurn():
        title = words;
        status = messages.frontDoorAwaitingReply(owner);
      case FrontDoorSkipped(:final reason):
        title = words;
        status = switch (reason) {
          FrontDoorSkipReason.noAgent => messages.frontDoorNoAgent(owner),
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
      case FrontDoorInbox(:final newKind, :final ownerId):
        title = words;
        status = ownerId == null
            ? messages.frontDoorInbox
            : messages.frontDoorInboxInstead;
        glyph = _guessGlyph(newKind);
        if (acting != null) {
          action = DesignSystemButton(
            key: ValueKey('front-door-task-$index'),
            label: messages.frontDoorMakeTask,
            isLoading: busy,
            onPressed: guarded(() => acting.onMakeTask(id)),
          );
          // The router's guess leads the other ways; leaving it comes last.
          final ways = [
            (
              'goal',
              messages.frontDoorStartGoal,
              LottiIcons.focus,
              acting.onStartGoal,
            ),
            if (newKind == FrontNewKind.project)
              (
                'project',
                messages.frontDoorNewProject,
                LottiIcons.folder,
                acting.onNewProject,
              ),
            (
              'note',
              messages.frontDoorSaveNote,
              LottiIcons.note,
              acting.onSaveNote,
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
              item(name, label, icon, () => go(id)),
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
      case FrontDoorTaskCreated():
        title = words;
        status = messages.frontDoorTaskCreated;
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
              Text(
                title,
                key: ValueKey('front-door-text-$index'),
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
              SizedBox(height: tokens.spacing.step1),
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
    FrontDestinationKind.newThing ||
    FrontDestinationKind.journal ||
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
