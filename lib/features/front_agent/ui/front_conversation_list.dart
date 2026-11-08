import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/ui/agent_surface_menu.dart';
import 'package:lotti/features/design_system/components/badges/design_system_badge.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_button.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/ui/front_conversation_actions.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Stable keys for the list's controls.
@visibleForTesting
abstract final class FrontConversationListKeys {
  static const Key newChat = Key('front-conversations-new');
  static const Key archived = Key('front-conversations-archived');
  static Key row(String id) => Key('front-conversation-$id');
  static Key menu(String id) => Key('front-conversation-menu-$id');
  static const Key search = Key('front-conversations-search');
  static const Key searchField = Key('front-conversations-search-field');
  static const Key inbox = Key('front-conversations-inbox');
}

/// The user's conversations with her, as a ChatGPT or Claude sidebar lists
/// them: a new one first, the search, then the live ones newest first under
/// recency sections, each with rename, archive and delete; the archived ones
/// folded away at the end, below a divider. A search looks through every
/// conversation, archived ones included. Picking one opens it and closes the
/// list.
///
/// Rows sit inset in the page gutter, so the open one is a quiet rounded
/// pill — the search field's width — and their text and the section labels
/// share one left edge. A new conversation and the search are the band's
/// ([FrontConversationListActions]): the list's own beside the conversation,
/// the page header's where the list is a page.
class FrontConversationList extends ConsumerStatefulWidget {
  const FrontConversationList({this.beside = false, super.key});

  /// Beside the open conversation (a desktop window), whose header carries
  /// that conversation's menu: its row keeps its time then, and shows its
  /// menu on hover or focus like any other.
  final bool beside;

  @override
  ConsumerState<FrontConversationList> createState() =>
      _FrontConversationListState();
}

class _FrontConversationListState extends ConsumerState<FrontConversationList> {
  String _query = '';
  bool _showArchived = false;

  /// An open search that is left empty closes when focus leaves it.
  late final FocusNode _searchFocus = FocusNode()..addListener(_searchBlurred);

  void _searchBlurred() {
    // Focus also leaves as the list goes away, when there is nothing to close.
    if (!mounted || _searchFocus.hasFocus || _query.trim().isNotEmpty) return;
    ref.read(frontConversationSearchOpenProvider.notifier).close();
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    super.dispose();
  }

  void _closeList() =>
      ref.read(frontConversationListOpenProvider.notifier).close();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final controller = ref.read(frontChatControllerProvider.notifier);
    final actions = FrontConversationActions(context, ref);
    // Read through `.value`: a reload keeps the list on screen.
    final index = ref.watch(frontConversationsProvider).value;
    final activeId = ref.watch(frontActiveConversationProvider).value;
    final inboxOnly = ref.watch(frontInboxFilterProvider);
    // Read through `.value`: a re-projection keeps the last count.
    final inboxCount =
        ref.watch(
          frontAllChatsThreadProvider.select((t) => t.value?.inboxCount),
        ) ??
        0;
    // The band opens it: the list's own, or the page header's.
    final searchOpen = ref.watch(frontConversationSearchOpenProvider);
    final needle = _query.trim().toLowerCase();
    final searching = needle.isNotEmpty;
    final matching = [
      for (final c in index?.conversations ?? const <FrontConversation>[])
        if (!searching || c.title.toLowerCase().contains(needle)) c,
    ];
    // A search looks through the archived ones too, in place.
    final live = [
      for (final c in matching)
        if (searching || !c.archived) c,
    ];
    final archived = searching
        ? const <FrontConversation>[]
        : [
            for (final c in matching)
              if (c.archived) c,
          ];
    final hasAny = index?.conversations.isNotEmpty ?? false;
    // The open conversation is always on the page: when it is archived, its
    // group opens.
    final showArchived = _showArchived || archived.any((c) => c.id == activeId);
    final now = clock.now();
    final rowSize = _rowSize(context);
    // Labels sit on the row text's own edge.
    final textInset = DesignSystemListItem.contentInset(tokens, rowSize);
    final rounded = BorderRadius.circular(tokens.radii.s);

    Widget row(FrontConversation c) => _ConversationRow(
      key: FrontConversationListKeys.row(c.id),
      conversation: c,
      borderRadius: rounded,
      selected: !inboxOnly && c.id == activeId,
      pinMenu: !widget.beside,
      menu: actions.menuItems(c),
      onOpen: () {
        controller.openConversation(c.id);
        _closeList();
      },
    );

    // A group: its name over its conversations, flat. The name in the
    // accent splits the days — the rows stay neutral, so the open row's
    // fill is still the one strong surface in the list.
    Widget group(String? label, List<FrontConversation> rows) => Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null)
            Padding(
              // Snug over its rows, on their text's edge.
              padding: EdgeInsets.only(
                left: textInset,
                right: textInset,
                bottom: tokens.spacing.step1,
              ),
              // Neutral: the accent means "press", and a day is not pressed.
              child: Text(
                label,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: tokens.colors.text.lowEmphasis,
                ),
              ),
            ),
          for (final c in rows) row(c),
        ],
      ),
    );

    // Live conversations under recency sections, as ChatGPT and Claude
    // group them — the date is said once per section, not on every row.
    final sections = <_Recency, List<FrontConversation>>{};
    for (final c in live) {
      sections.putIfAbsent(_Recency.of(c.lastActivity, now), () => []).add(c);
    }
    // The thread's own gutter: the pills, the search and the divider line
    // up with the bubbles' edges.
    final list = ListView(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step3,
        tokens.spacing.step5,
        tokens.spacing.step5,
      ),
      children: [
        // What waits on the user, from every conversation: a destination
        // of its own, opening the thread filtered to it — first, since it
        // is what asks for attention.
        if (!searching && (inboxCount > 0 || inboxOnly))
          DesignSystemListItem(
            key: FrontConversationListKeys.inbox,
            // At full strength while something waits; the badge counts it.
            titleContent: Text(
              messages.frontChatInboxTitle,
              style: _labelStyle(context).copyWith(
                color: inboxCount > 0
                    ? tokens.colors.text.highEmphasis
                    : tokens.colors.text.mediumEmphasis,
              ),
            ),
            size: rowSize,
            borderRadius: rounded,
            activated: inboxOnly,
            activatedBackgroundColor: tokens.colors.surface.hover,
            hoverBackgroundColor: tokens.colors.surface.enabled,
            leading: Icon(
              LottiIcons.inbox,
              size: IconSizes.s,
              color: tokens.colors.text.mediumEmphasis,
            ),
            // The header's dot, counted: the same warm mark on the row that
            // resolves it.
            trailing: _TrailingSlot(
              child: DesignSystemBadge.number(
                value: '$inboxCount',
                tone: DesignSystemBadgeTone.warning,
                semanticLabel: messages.frontChatInboxChip(inboxCount),
              ),
            ),
            onTap: () {
              if (!inboxOnly) {
                ref.read(frontInboxFilterProvider.notifier).toggle();
              }
              _closeList();
            },
          ),
        if (hasAny && searchOpen) ...[
          SizedBox(height: tokens.spacing.step2),
          DesignSystemSearch(
            // Keyed: the first letter hides the Inbox row above it, and
            // unkeyed the field would be rebuilt at its new index — its
            // text and focus lost.
            key: FrontConversationListKeys.searchField,
            hintText: messages.frontChatSearchChats,
            size: DesignSystemSearchSize.small,
            focusNode: _searchFocus,
            autofocus: true,
            onChanged: (value) => setState(() => _query = value),
            // Clearing closes it again: the list is back as it was.
            onClear: () {
              setState(() => _query = '');
              ref.read(frontConversationSearchOpenProvider.notifier).close();
            },
          ),
        ],
        // A search is one group of what matched; otherwise the recency groups.
        if (searching && live.isNotEmpty) group(null, live),
        if (!searching)
          for (final MapEntry(key: recency, value: rows) in sections.entries)
            group(recency.label(messages), rows),
        if (index != null && live.isEmpty && archived.isEmpty)
          Padding(
            padding: EdgeInsets.all(textInset),
            child: Text(
              hasAny
                  ? messages.frontChatNoMatchingChats
                  : messages.frontChatNoChats,
              textAlign: TextAlign.center,
              style: _labelStyle(context).copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            ),
          ),
        if (archived.isNotEmpty) ...[
          // Room on both sides: the divider separates the groups rather than
          // bordering the row below it.
          Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spacing.step5),
            child: const DesignSystemDivider(),
          ),
          MergeSemantics(
            child: Semantics(
              expanded: showArchived,
              child: DesignSystemListItem(
                key: FrontConversationListKeys.archived,
                // A row that opens, in a row's voice — not another section
                // label.
                titleContent: Text(
                  messages.frontChatArchivedRow(archived.length),
                  style: _labelStyle(context).copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
                size: rowSize,
                borderRadius: rounded,
                hoverBackgroundColor: tokens.colors.surface.enabled,
                leading: Icon(
                  LottiIcons.archive,
                  size: IconSizes.s,
                  color: tokens.colors.text.mediumEmphasis,
                ),
                // On the rows' trailing rail, where their menus sit.
                trailing: _TrailingSlot(
                  child: Icon(
                    showArchived ? LottiIcons.collapse : LottiIcons.expand,
                    size: IconSizes.s,
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
                onTap: () => setState(() => _showArchived = !showArchived),
              ),
            ),
          ),
          if (showArchived) group(null, archived),
        ],
      ],
    );
    if (!widget.beside) return list;
    // Beside the conversation the list has a band of its own, as tall as
    // her header's, so the two hairlines run across the sheet as one.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: tokens.colors.decorative.level01),
            ),
          ),
          child: Padding(
            padding: frontBandPadding(tokens),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    // On the rows' text edge.
                    padding: EdgeInsetsDirectional.only(start: textInset),
                    child: Text(
                      messages.queryChats,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tokens.typography.styles.subtitle.subtitle2
                          .copyWith(color: tokens.colors.text.highEmphasis),
                    ),
                  ),
                ),
                ...FrontConversationListActions.of(context, ref),
              ],
            ),
          ),
        ),
        Expanded(child: list),
      ],
    );
  }
}

/// The inset of the sheet's top band — her header, and the list's own band
/// beside it: with a tap target inside, both come out the same height, so
/// their hairlines meet.
EdgeInsets frontBandPadding(DsTokens tokens) => EdgeInsets.symmetric(
  horizontal: tokens.spacing.step5,
  vertical: tokens.spacing.step2,
);

/// The list's two actions, as glyphs on its band: the search (once there is
/// anything to search) and a new conversation — the page's one action, so the
/// accent. On the list's own band beside the conversation, and on the page
/// header where the list is a page.
abstract final class FrontConversationListActions {
  static List<Widget> of(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final hasAny =
        ref.watch(frontConversationsProvider).value?.conversations.isNotEmpty ??
        false;
    return [
      if (hasAny)
        DesignSystemIconAction(
          key: FrontConversationListKeys.search,
          tooltip: messages.frontChatSearchChats,
          icon: LottiIcons.search,
          onPressed: ref
              .read(frontConversationSearchOpenProvider.notifier)
              .open,
        ),
      DesignSystemIconAction(
        key: FrontConversationListKeys.newChat,
        tooltip: messages.queryNewChat,
        icon: LottiIcons.editNote,
        tone: tokens.colors.interactive.enabled,
        onPressed: () {
          ref.read(frontChatControllerProvider.notifier).startConversation();
          ref.read(frontConversationListOpenProvider.notifier).close();
        },
      ),
    ];
  }
}

/// How recent a conversation is: the section it is listed under.
enum _Recency {
  today,
  yesterday,
  week,
  older;

  static _Recency of(DateTime at, DateTime now) {
    final days = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(at.year, at.month, at.day)).inDays;
    return days <= 0
        ? today
        : days == 1
        ? yesterday
        : days < 7
        ? week
        : older;
  }

  String label(AppLocalizations messages) => switch (this) {
    today => messages.calendarTodayLabel,
    yesterday => messages.frontChatYesterday,
    week => messages.frontChatPrevious7Days,
    older => messages.frontChatOlder,
  };
}

/// A destination row's label style (Inbox, Archived): the size of a
/// conversation's title, never larger, so the list's own items lead.
TextStyle _labelStyle(BuildContext context) =>
    context.designTokens.typography.styles.body.bodySmall;

/// Rows are touch-sized on a phone and compact on a wide window.
/// A conversation's row on every layout: its two lines make it a full
/// target already, so it takes the denser padding.
const DesignSystemListItemSize _conversationRowSize =
    DesignSystemListItemSize.small;

DesignSystemListItemSize _rowSize(BuildContext context) =>
    isDesktopLayout(context)
    ? DesignSystemListItemSize.small
    : DesignSystemListItemSize.medium;

/// The trailing column every row shares, sized so its centre falls under
/// the header's close glyph: the list's gutter plus the row's inset plus
/// half this slot equals the header's gutter plus half a tap target. It is
/// as tall as a line of text, so it never sets a row's height; a row's menu
/// is laid over the row at this column's centre rather than inside it, so
/// the button keeps its whole target within the row it belongs to.
class _TrailingSlot extends StatelessWidget {
  const _TrailingSlot({this.child});

  final Widget? child;

  static double widthOf(BuildContext context) {
    final tokens = context.designTokens;
    return (TapTargets.minimum -
            2 * DesignSystemListItem.contentInset(tokens, _rowSize(context)))
        .clamp(0.0, DesignSystemContextMenuButton.extent(tokens));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return SizedBox(
      width: widthOf(context),
      height: tokens.spacing.step5,
      child: child == null
          ? null
          : OverflowBox(
              maxWidth: DesignSystemContextMenuButton.extent(tokens),
              child: Center(child: child),
            ),
    );
  }
}

/// The height one line of [style] takes as text lays out here — with the
/// text scaler — so a control can sit on that line.
double _lineHeight(BuildContext context, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: 'Hg', style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}

/// One conversation: its title, her last answer under it, and its menu.
/// When it moved is its section's to say (Today, Yesterday, …), as a chat
/// list has it, so the title has its line to itself. The open one is
/// the brightest neutral rounded fill — not the accent, which is the user's
/// own bubbles' colour. On a wide window the menu shows on
/// hover or focus and on the open row; the rest of the list stays words.
class _ConversationRow extends StatefulWidget {
  const _ConversationRow({
    required this.conversation,
    required this.borderRadius,
    required this.selected,
    required this.menu,
    required this.onOpen,
    this.pinMenu = true,
    super.key,
  });

  final FrontConversation conversation;

  /// The row's own corners, for its fill.
  final BorderRadius borderRadius;
  final bool selected;

  /// Whether the open row shows its menu at rest — not beside the open
  /// conversation, whose header already carries it.
  final bool pinMenu;
  final List<DesignSystemContextMenuItem> menu;
  final VoidCallback onOpen;

  @override
  State<_ConversationRow> createState() => _ConversationRowState();
}

class _ConversationRowState extends State<_ConversationRow> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // The menu is on the open row, and on any row hovered or focused; the
    // rest of the list stays words.
    final showMenu =
        (widget.selected && widget.pinMenu) || _hovered || _focused;
    final extent = DesignSystemContextMenuButton.extent(tokens);
    final glyph = tokens.spacing.step5;
    final conversation = widget.conversation;
    final preview = conversation.preview?.trim();
    // A step brighter on the open row's fill, so it keeps its contrast there.
    final quiet = tokens.typography.styles.others.caption.copyWith(
      color: widget.selected
          ? tokens.colors.text.mediumEmphasis
          : tokens.colors.text.lowEmphasis,
    );
    final titleStyle = tokens.typography.styles.subtitle.subtitle2.copyWith(
      // An archived one is quieter in tone as well as marked — unless it is
      // the open one, whose fill never carries dim text.
      color: conversation.archived && !widget.selected
          ? tokens.colors.text.mediumEmphasis
          : tokens.colors.text.highEmphasis,
    );
    // The menu's glyph is centred on the title's first line; its whole tap
    // target stays inside the row, so where the target would reach above
    // it, the target stops at the row's top and the glyph moves up in it.
    final glyphCentre =
        DesignSystemListItem.verticalInset(tokens, _conversationRowSize) +
        _lineHeight(context, titleStyle) / 2;
    final menuTop = math.max(0, glyphCentre - extent / 2).toDouble();
    // From the content's end to the glyph's far side, and a gap before it:
    // the target sits a quarter past the content's edge (see below).
    final menuRoom = extent / 4 + glyph / 2 + tokens.spacing.step3;
    final glyphAlignment = Alignment(
      0,
      2 * (glyphCentre - menuTop - glyph / 2) / (extent - glyph) - 1,
    );
    final row = DesignSystemListItem(
      // One line of title, one of where the conversation got to — her last
      // answer, on the row's whole width, when there is one — so every row
      // is the same height and the list scans.
      titleContent: ConstrainedBox(
        // Never shorter than the menu's whole tap target: a one-line chat
        // with no answer yet would leave its lower part outside the row.
        constraints: BoxConstraints(
          minHeight:
              extent -
              2 *
                  DesignSystemListItem.verticalInset(
                    tokens,
                    _conversationRowSize,
                  ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              // Room for the menu at the title's end, kept on every row: it
              // shows on hover, focus and the open row, and nothing reflows.
              padding: EdgeInsetsDirectional.only(end: menuRoom),
              child: Text(
                conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
            if (preview != null && preview.isNotEmpty) ...[
              SizedBox(height: tokens.spacing.step1),
              Text(
                preview,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: quiet,
              ),
            ],
          ],
        ),
      ),
      size: _conversationRowSize,
      borderRadius: widget.borderRadius,
      // The open one is the brightest neutral in the list — one step, not
      // the pressed fill, so it reads as "here", not as held down; a hovered
      // one takes a quieter fill, so the two never look alike.
      activated: widget.selected,
      activatedBackgroundColor: tokens.colors.surface.hover,
      hoverBackgroundColor: tokens.colors.surface.enabled,
      // An archived one says so wherever it shows — a search included.
      leading: widget.conversation.archived
          ? Icon(
              LottiIcons.archive,
              size: IconSizes.s,
              color: tokens.colors.text.mediumEmphasis,
            )
          : null,
      onTap: widget.onOpen,
      onHoverChanged: (value) => setState(() => _hovered = value),
      onFocusChanged: (value) => setState(() => _focused = value),
    );
    return Semantics(
      selected: widget.selected,
      // A long press offers any row's menu, so a phone — no hover — reaches
      // the rows whose menu is not shown.
      onLongPressHint: context.messages.frontChatRowMenuHint,
      child: Stack(
        children: [
          GestureDetector(
            // The same menu its ⋯ opens, under the row pressed.
            onLongPress: () => showAgentSurfaceMenu(
              context,
              items: widget.menu,
              header: widget.conversation.title,
            ).ignore(),
            child: row,
          ),
          // Over the row, inside its bounds, so the whole target answers:
          // a near miss opens the menu, never the conversation.
          // On the title's first line, at its end, in the room kept for it.
          Positioned(
            top: menuTop,
            right:
                DesignSystemListItem.contentInset(
                  tokens,
                  _conversationRowSize,
                ) -
                extent / 4,
            width: extent,
            height: extent,
            child: Center(
              child: Visibility(
                visible: showMenu,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: FrontMenuButton(
                  key: FrontConversationListKeys.menu(widget.conversation.id),
                  // Which chat Delete deletes, said above it.
                  header: widget.conversation.title,
                  glyphAlignment: glyphAlignment,
                  // Quiet on every row but the open one, so the rail of
                  // menus a touch screen shows does not read as a column.
                  iconColor: widget.selected
                      ? tokens.colors.text.mediumEmphasis
                      : tokens.colors.text.lowEmphasis,
                  items: widget.menu,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
