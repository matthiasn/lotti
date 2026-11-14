import 'dart:math' as math;

import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/agents/query_chat_models.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/agents/ui/chat/agent_chat_view.dart';
import 'package:lotti/features/agents/ui/chat/agent_turn_failure_label.dart';
import 'package:lotti/features/agents/ui/chat/chat_recorder_controller.dart';
import 'package:lotti/features/ai/state/subject_dictation_providers.dart';
import 'package:lotti/features/companion/state/companion_card_controller.dart';
import 'package:lotti/features/daily_os_next/state/selected_date_provider.dart';
import 'package:lotti/features/design_system/components/chat_input/design_system_chat_input.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_dispatch.dart';
import 'package:lotti/features/front_agent/model/front_door.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_live_answer.dart';
import 'package:lotti/features/front_agent/model/front_reference_links.dart';
import 'package:lotti/features/front_agent/model/front_task_draft.dart';
import 'package:lotti/features/front_agent/model/front_turn_failure.dart';
import 'package:lotti/features/front_agent/state/front_agent_providers.dart';
import 'package:lotti/features/front_agent/state/front_chat_category.dart';
import 'package:lotti/features/front_agent/state/front_chat_controller.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/state/front_journal_access_provider.dart';
import 'package:lotti/features/front_agent/state/front_mention_categories.dart';
import 'package:lotti/features/front_agent/ui/a2ui/front_reply_catalog.dart';
import 'package:lotti/features/front_agent/ui/a2ui/front_reply_surfaces.dart';
import 'package:lotti/features/front_agent/ui/front_ask_options_row.dart';
import 'package:lotti/features/front_agent/ui/front_category_chip.dart';
import 'package:lotti/features/front_agent/ui/front_chat_drawer.dart';
import 'package:lotti/features/front_agent/ui/front_chat_header.dart';
import 'package:lotti/features/front_agent/ui/front_chat_voice.dart';
import 'package:lotti/features/front_agent/ui/front_companion_figure.dart';
import 'package:lotti/features/front_agent/ui/front_door_card.dart';
import 'package:lotti/features/front_agent/ui/front_door_wizards.dart';
import 'package:lotti/features/front_agent/ui/front_entity_preview_card.dart';
import 'package:lotti/features/front_agent/ui/front_starter_prompts.dart';
import 'package:lotti/features/tasks/util/task_navigation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/color.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/utils/device_datetime.dart';
import 'package:lotti/utils/goal_routes.dart';
import 'package:lotti/widgets/markdown_link_utils.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:material_ui/material_ui.dart';

/// A task's page, as [internalRouteFromMarkdownUrl] gives it: `/tasks/<id>`.
final RegExp _taskRoute = RegExp(r'^/tasks/([^/?]+)$');

/// The companion's chat: one of the user's conversations with her, under
/// her one-row header, in the shared [AgentChatView] — and her drawer
/// ([FrontChatDrawer]): slid over the thread on a phone, beside it on a
/// desktop window. Beside it, her card is docked under the drawer rather than
/// floated over the thread, so it covers nothing of the conversation.
///
/// What differs from a goal's or a person's chat is what hangs off a
/// message: under a routed turn, the doors it was taken through and what
/// came back, attributed to each owner; under her latest clarifying
/// question, the choices as chips. A day divider sits between messages of
/// different days.
class FrontChatPane extends ConsumerStatefulWidget {
  const FrontChatPane({
    required this.onClose,
    this.listWidth,
    this.keyboardUp = false,
    super.key,
  });

  /// The share of a wide panel the drawer beside the conversation takes:
  /// room for a preview that says something, the conversation keeping the
  /// rest. Over a phone's thread the drawer is as wide as that at most.
  static const double listShare = 0.38;

  /// The height the drawer beside the conversation keeps above her docked
  /// card: its search, new chat and four settings rows, and three
  /// conversations — a tap target each. A window too short for that and her
  /// collapsed card floats her over the thread instead.
  static const double drawerKeptHeight = TapTargets.minimum * 9;

  final VoidCallback onClose;

  /// The width of the drawer kept beside the conversation, on a window wide
  /// enough for both; null where the drawer slides over the conversation.
  final double? listWidth;

  /// Whether the on-screen keyboard is up, as her surface sees it above the
  /// dialog that hides the inset: the drawer's settings step aside for it.
  final bool keyboardUp;

  @override
  ConsumerState<FrontChatPane> createState() => _FrontChatPaneState();
}

class _FrontChatPaneState extends ConsumerState<FrontChatPane>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drawer = AnimationController(
    vsync: this,
    duration: MotionDurations.medium2,
  );

  /// The header's drawer toggle: focus goes back to it as the drawer closes.
  final _toggleFocus = FocusNode(debugLabel: 'front-chat-drawer-toggle');

  /// The drawer's own scope: focus moves into it as it opens.
  final _drawerFocus = FocusScopeNode(debugLabel: 'front-chat-drawer');

  @override
  void dispose() {
    _drawer.dispose();
    _toggleFocus.dispose();
    _drawerFocus.dispose();
    super.dispose();
  }

  /// Slides the drawer in or out — at once where the platform asks for
  /// reduced motion — and moves focus with it.
  void _follow(bool open) {
    // Read now: under reduced motion the drawer, and its focus with it, is
    // gone by the next frame.
    final hadFocus = _drawerFocus.hasFocus;
    if (MediaQuery.disableAnimationsOf(context)) {
      _drawer.value = open ? 1 : 0;
    } else {
      open ? _drawer.forward() : _drawer.reverse();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (open) {
        _drawerFocus.requestFocus();
      } else if (hadFocus) {
        _toggleFocus.requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final onClose = widget.onClose;
    final listWidth = widget.listWidth;
    final beside = listWidth != null;
    // Beside the conversation the drawer is always there: it never opens
    // over it.
    final listOpen = !beside && ref.watch(frontConversationListOpenProvider);
    // Her reply to a spoken turn is spoken back, drawer open or not.
    FrontVoice.listenForSpokenReply(ref, context);
    final inboxOnly = ref.watch(frontInboxFilterProvider);
    // What was being said belongs to the conversation it was said in:
    // leaving it for another lets it go, rather than sending it into
    // wherever the user went. Opening the drawer is not leaving: the thread
    // stays under it, and the take goes on (decision 5).
    void letHerGo(Object? previous, Object? next) {
      if (previous == next) return;
      // Only on leaving one: a conversation resolving as the surface opens
      // is where the user already is.
      final recorder = ref.read(chatRecorderControllerProvider);
      if (previous != null &&
          (recorder.status == ChatRecorderStatus.recording ||
              recorder.status == ChatRecorderStatus.processing)) {
        ref.read(chatRecorderControllerProvider.notifier).cancel().ignore();
      }
    }

    ref
      ..listen<String?>(
        frontActiveConversationProvider.select((active) => active.value),
        letHerGo,
      )
      // Followed beside the conversation too, where nothing shows it: a
      // window that narrows again finds the drawer where its state says.
      ..listen<bool>(
        frontConversationListOpenProvider,
        (_, open) => _follow(open),
      );
    // The drawer is a layer over the conversation, and the inbox a view of
    // it: back — the system gesture, the Escape key — closes the drawer,
    // then leaves the inbox, before it closes the sheet.
    return PopScope(
      canPop: !listOpen && !inboxOnly,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (listOpen) {
          ref.read(frontConversationListOpenProvider.notifier).close();
        } else {
          ref.read(frontInboxFilterProvider.notifier).clear();
        }
      },
      child: beside
          ? LayoutBuilder(
              builder: (context, panel) {
                // Docked only where the drawer keeps its rows and a few
                // conversations above her; a shorter window floats her over the
                // thread, as a narrower one does.
                final dockRoom =
                    panel.maxHeight - FrontChatPane.drawerKeptHeight;
                final docked = dockRoom >= CompanionCardForm.docked.smallHeight;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // A step off the conversation's ground: the drawer is the
                    // sheet's sidebar, not more of the thread.
                    ColoredBox(
                      color: tokens.colors.background.level02,
                      child: SizedBox(
                        width: listWidth,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: FrontChatDrawer(
                                beside: true,
                                keyboardUp: widget.keyboardUp,
                              ),
                            ),
                            // Expanded, she still leaves the drawer its room.
                            if (docked)
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: dockRoom,
                                ),
                                child: _DockedCompanion(onClose: onClose),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const DesignSystemDivider(
                      orientation: DesignSystemDividerOrientation.vertical,
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          FrontChatHeader(onClose: onClose, listBeside: true),
                          Expanded(
                            child: FrontChatThreadView(
                              onClose: onClose,
                              cardDocked: docked,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            )
          : LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  // Always built, under the drawer too: opening it never
                  // takes the conversation off the screen or rebuilds it.
                  ExcludeFocus(
                    excluding: listOpen,
                    child: Column(
                      children: [
                        FrontChatHeader(
                          onClose: onClose,
                          drawerFocusNode: _toggleFocus,
                        ),
                        Expanded(child: FrontChatThreadView(onClose: onClose)),
                      ],
                    ),
                  ),
                  _DrawerLayer(
                    animation: _drawer,
                    focusNode: _drawerFocus,
                    keyboardUp: widget.keyboardUp,
                    // Room beside it for the scrim, a tap target wide, and
                    // never wider than it is beside a wide panel's thread.
                    width: math.min(
                      constraints.maxWidth - TapTargets.minimum,
                      kDetailContentMaxWidth * FrontChatPane.listShare,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// The drawer over a phone's thread: the shared scrim, which closes it,
/// and the drawer slid in from the leading edge, a labelled modal region
/// that keeps focus and assistive technology to itself while it is open.
/// Built only while it shows, so it opens each time on everything.
class _DrawerLayer extends ConsumerWidget {
  const _DrawerLayer({
    required this.animation,
    required this.focusNode,
    required this.keyboardUp,
    required this.width,
  });

  final Animation<double> animation;
  final FocusScopeNode focusNode;
  final bool keyboardUp;
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    void close() =>
        ref.read(frontConversationListOpenProvider.notifier).close();
    final drawer = Semantics(
      scopesRoute: true,
      namesRoute: true,
      explicitChildNodes: true,
      label: messages.queryChats,
      child: FocusScope(
        node: focusNode,
        child: Material(
          color: tokens.colors.background.level02,
          child: FrontChatDrawer(keyboardUp: keyboardUp),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: animation,
      child: drawer,
      builder: (context, drawer) {
        if (animation.isDismissed) return const SizedBox.shrink();
        final shown = MotionCurves.standard.transform(animation.value);
        return BlockSemantics(
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: shown,
                  child: Semantics(
                    key: FrontChatPaneKeys.scrim,
                    container: true,
                    button: true,
                    label: messages.frontChatDrawerClose,
                    onTap: close,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      excludeFromSemantics: true,
                      onTap: close,
                      child: ColoredBox(
                        color: ModalUtils.getModalBarrierColor(
                          isDark:
                              Theme.of(context).brightness == Brightness.dark,
                          context: context,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              PositionedDirectional(
                start: -width * (1 - shown),
                top: 0,
                bottom: 0,
                width: width,
                child: drawer!,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Which conversation her card shows for, or null for none: only while the
/// header's face has it shown ([frontCompanionCardShownProvider]), and never
/// with the character off, nor in the inbox, which gathers every
/// conversation. Watches what it reads.
String? _companionCardFor(WidgetRef ref) =>
    ref.watch(frontCompanionCardShownProvider) &&
        !ref.watch(frontInboxFilterProvider) &&
        (ref.watch(configFlagProvider(enableCompanionFlag)).value ?? false)
    ? ref.watch(frontActiveConversationProvider).value
    : null;

/// Her settings are a page of the app: she closes first.
VoidCallback _openCompanionSettings(VoidCallback onClose) => () {
  onClose();
  beamToNamed('/settings/companion');
};

/// Her card docked under the conversations beside a desktop's thread
/// ([CompanionCardForm.docked]), as wide as they are, collapsed until the
/// user expands it: it covers nothing of the conversation. Hidden from its
/// menu, it leaves her face in the header at the top, which brings it back.
class _DockedCompanion extends ConsumerWidget {
  const _DockedCompanion({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = context.designTokens.spacing;
    final cardFor = _companionCardFor(ref);
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : MotionDurations.short4,
      curve: MotionCurves.standard,
      alignment: Alignment.bottomCenter,
      child: cardFor == null
          ? const SizedBox.shrink()
          : Padding(
              padding: EdgeInsets.only(
                left: spacing.step5,
                right: spacing.step5,
                bottom: spacing.step5,
              ),
              child: FrontCompanionCard(
                conversationId: cardFor,
                form: CompanionCardForm.docked,
                onCustomize: _openCompanionSettings(onClose),
              ),
            ),
    );
  }
}

/// Stable keys for the pane's own parts.
@visibleForTesting
abstract final class FrontChatPaneKeys {
  static const Key scrim = Key('front-chat-drawer-scrim');
}

/// One conversation's thread and the field under it — or, while the inbox is
/// on, every turn still waiting on the user. In the pane under her header;
/// while the header's face has it shown ([frontCompanionCardShownProvider]),
/// her glass card floats over the thread ([FrontCompanionCard]), fading in
/// and out where the user left it — unless [cardDocked].
class FrontChatThreadView extends ConsumerStatefulWidget {
  const FrontChatThreadView({
    required this.onClose,
    this.cardDocked = false,
    super.key,
  });

  /// Her card is docked beside the thread (a desktop window's sidebar), so
  /// nothing floats over it.
  final bool cardDocked;

  /// Closes her surface. Everything that leaves her for a page goes through
  /// this, never `maybePop`: while the list or the inbox is open, back is
  /// theirs ([PopScope] clears them), and the page would open behind her.
  /// A task is the exception: it opens on top of her, and back returns here.
  final VoidCallback onClose;

  @override
  ConsumerState<FrontChatThreadView> createState() =>
      _FrontChatThreadViewState();
}

class _FrontChatThreadViewState extends ConsumerState<FrontChatThreadView> {
  /// What the shown thread was loaded for: the inbox, or one conversation.
  /// Another conversation picked is a change of subject, not a reload: its
  /// thread is not the one on screen.
  (bool, String?)? _shownFor;

  @override
  Widget build(BuildContext context) {
    final onClose = widget.onClose;
    final messages = context.messages;
    final threadAsync = ref.watch(frontChatThreadProvider);
    // The inbox is the same thread, filtered to the turns with a door still
    // waiting on the user (decision 7).
    final inboxOnly = ref.watch(frontInboxFilterProvider);
    final conversationId = ref.watch(frontActiveConversationProvider).value;
    final subject = (inboxOnly, inboxOnly ? null : conversationId);
    if (threadAsync.hasValue &&
        !threadAsync.isLoading &&
        !threadAsync.hasError) {
      _shownFor = subject;
    }
    // Read through `.value`: a reload keeps the shown thread on screen
    // (stay while reload). Only a first load, or another conversation
    // picked, shows the shell — the composer already sends to the one
    // picked, so the last one's words must not stand in for it — and a
    // failed load of the one picked shows its error.
    final stored = _shownFor == subject ? threadAsync.value : null;
    // Her answer while she writes it is the thread's last message, under
    // the id her stored reply will have, which then takes its place. Not in
    // the inbox, which shows only turns that wait on the user.
    final thread = stored == null || inboxOnly
        ? stored
        : frontThreadWithLive(stored, ref.watch(frontLiveAnswerProvider));
    // Cards a lookup found may stand before she has written a word; she
    // is still thinking until she has.
    final writing =
        !identical(thread, stored) &&
        (thread?.messages.lastOrNull?.text.isNotEmpty ?? false);
    // She copies dates as her tools give them (ISO); on screen each is in
    // the device's own format, as a due date is everywhere else.
    String deviceDays(String text) =>
        replaceIsoDays(text, (day) => deviceDateLabel(context, day));
    final history = switch (thread) {
      null when threadAsync.hasError => AsyncError<List<AgentChatMessage>>(
        threadAsync.error!,
        threadAsync.stackTrace ?? StackTrace.empty,
      ),
      null => const AsyncLoading<List<AgentChatMessage>>(),
      final t => AsyncData([
        for (final m in t.messages)
          if (m.role == AgentChatRole.agent)
            AgentChatMessage(
              id: m.id,
              role: m.role,
              text: deviceDays(m.text),
              createdAt: m.createdAt,
              runKey: m.runKey,
            )
          else
            m,
      ]),
    };
    final composer = ref.watch(frontChatControllerProvider);
    final mentions = ref.watch(frontMentionCategoriesProvider);
    // The category the open conversation is narrowed to; none in the inbox,
    // which is every conversation at once.
    final scope = inboxOnly ? null : ref.watch(frontChatCategoryProvider);
    // Kept across a reread (`.value`): an answer is not taken off the screen
    // while its sources' visibility is checked again.
    final journalAccess = ref.watch(frontJournalAccessProvider).value;
    final controller = ref.read(frontChatControllerProvider.notifier);
    final latestId = thread?.messages.lastOrNull?.id;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final inboxIds = thread?.inboxMessageIds ?? const <String>{};
    final cardFor = widget.cardDocked ? null : _companionCardFor(ref);
    final cardForm = isDesktopLayout(context)
        ? CompanionCardForm.desktop
        : CompanionCardForm.phone;
    // Room for her wherever she sits: an inset that came and went with her
    // position would shift the thread under a drag.
    final cardInset = cardFor == null
        ? 0.0
        : ref.watch(
                companionCardControllerProvider(
                  cardForm,
                ).select((p) => p.height),
              ) +
              context.designTokens.spacing.step5;
    final shown = inboxOnly
        ? history.whenData(
            (messages) => [
              for (final message in messages)
                if (inboxIds.contains(message.id)) message,
            ],
          )
        : history;
    // A link in her words or in an answer: a task she names opens on top of
    // her, so back comes back to this conversation; another page in the app
    // closes her and goes there; anything else is opened the way every
    // agent's links are.
    void openLink(String url, String title) {
      final route = internalRouteFromMarkdownUrl(url);
      if (route == null) {
        handleMarkdownLinkTap(url, title).ignore();
        return;
      }
      if (_taskRoute.firstMatch(route)?.group(1) case final taskId?) {
        pushTaskDetailPage(context, taskId, rootNavigator: true);
        return;
      }
      onClose();
      beamToNamed(route);
    }

    // The Daily OS day surface, showing [day]: the planned one, not
    // whichever was picked there last. A page of the app, so she closes
    // first.
    void openDay(DateTime day) {
      ref.read(dailyOsNextSelectedDateProvider.notifier).select(day);
      onClose();
      beamToNamed('/calendar');
    }

    // A preview card's entity: a task opens on top of her and a project
    // closes her, as when she names either; an event's page, a person's and
    // a day's are the app's, so she closes first.
    void openMade(FrontEntityReference made) {
      switch (made.kind) {
        case FrontEntityKind.task:
          openLink(frontReferenceUrl(FrontDestinationKind.task, made.id), '');
        case FrontEntityKind.project:
          openLink(
            frontReferenceUrl(FrontDestinationKind.project, made.id),
            '',
          );
        case FrontEntityKind.event:
          onClose();
          beamToNamed('/events/${made.id}');
        case FrontEntityKind.person:
          onClose();
          beamToNamed('/people/${made.id}');
        case FrontEntityKind.dayPlan:
          if (DateTime.tryParse(made.id) case final day?) openDay(day);
      }
    }

    final eventsEnabled =
        ref.watch(configFlagProvider(enableEventsFlag)).value ?? false;
    final actions = FrontDoorActions(
      onOpenLink: (url) => openLink(url, ''),
      onFile: controller.fileUnderOwner,
      onDecline: controller.decline,
      onUndoDecline: controller.undoDecline,
      onTakeBack: controller.takeBack,
      onMakeTask: (doorId, choices) => FrontVoice.makeTask(
        ref,
        context,
        conversationId,
        doorId,
        choices: choices,
      ),
      // The task as she read it, and a coding prompt written from the words.
      onMakePrompt: (doorId, choices) => FrontVoice.makeTask(
        ref,
        context,
        conversationId,
        doorId,
        choices: choices,
        codingPrompt: true,
      ),
      // Only where events are on: one made where they are off would be an
      // event the user has no page to find it on.
      onMakeEvent: eventsEnabled ? controller.makeEvent : null,
      onSaveNote: controller.saveAsNote,
      // What a door wrote lives on its own page: leave the sheet, then go.
      onOpen: (door) {
        if (door.record.outcome case FrontDoorDayPlanned(:final day)) {
          openDay(day);
          return;
        }
        final path = switch (door.record.outcome) {
          FrontDoorFiled(:final entryId) => '/journal/$entryId',
          FrontDoorTaskCreated(:final taskId) => '/tasks/$taskId',
          FrontDoorEventCreated(:final eventId) => '/events/$eventId',
          FrontDoorProjectCreated(:final projectId) => '/projects/$projectId',
          _ => null,
        };
        if (path == null) return;
        onClose();
        beamToNamed(path);
      },
      // The goal wizard opens with the words as its intention; nothing is
      // written by opening it, and the item keeps waiting.
      onStartGoal: (door) {
        // Leave the sheet, then go: the wizard is a page, not a modal.
        onClose();
        beamToNamed(goalCreatePathWith(intention: door.record.text));
      },
      // The project form opens with the words as its title; a project it
      // creates settles the item.
      onNewProject: (door) => controller.newProject(
        door.doorId,
        () => ref.read(frontNewProjectProvider)(context, door.record.text),
      ),
      // A change to today opens the Daily OS planning with the words given:
      // refining today's plan, or planning the day when there is none. The
      // plan changes only when the user accepts there; then the door
      // settles.
      onPlanDay: (door) => controller.planDay(
        door.doorId,
        () => ref.read(frontDayPlannerProvider)(context, door.record.text),
      ),
      // A source a journal answer cites opens on its own page.
      onOpenEvidence: (evidence) {
        final id = evidence.source.id;
        openLink(switch (evidence.kind) {
          QuerySourceKind.task => '/tasks/$id',
          QuerySourceKind.project => '/projects/$id',
          _ => '/journal/$id',
        }, '');
      },
    );

    return FrontReplySurfaces(
      surfaces: thread?.surfaces ?? const {},
      logger: ref.watch(domainLoggerProvider),
      // A reply she offered and the user tapped is their next turn, in its
      // own words — as a chip under a clarifying question is.
      onQuickReply: controller.sendText,
      child: AgentChatView(
        agentId: frontAgentId,
        threadOverlay: AnimatedSwitcher(
          duration: MotionDurations.short4,
          child: cardFor == null
              ? const SizedBox.shrink()
              : FrontCompanionCard(
                  conversationId: cardFor,
                  form: cardForm,
                  onCustomize: _openCompanionSettings(onClose),
                ),
        ),
        threadBottomInset: cardInset,
        agentName: messages.frontChatTitle,
        // Each conversation keeps its own scroll position.
        conversationId: inboxOnly
            ? 'front-chat-inbox'
            : 'front-chat:${conversationId ?? ''}',
        history: shown,
        // A conversation with her, not a log: her words as prose, the user's
        // in a soft bubble; what was said goes out as it stops.
        conversational: true,
        // One reading column for the thread and the field under it, so the
        // field's edges line up with the messages on a wide window.
        contentMaxWidth: kProseMeasureWidth,
        voiceFirst: true,
        // The conversation's category, picked where the words are typed; `@`
        // still names one for a single question.
        composerLeading: mentions.isEmpty ? null : const FrontCategoryChip(),
        mentionOptions: [
          for (final category in mentions)
            DesignSystemChatInputMention(
              label: category.name,
              color: colorFromCssHex(category.color),
            ),
        ],
        // A conversation not begun opens on what she can do, in the middle
        // of where the thread will be. No figure of her: her card, or her
        // face in the header, already shows her.
        emptyState: inboxOnly
            ? null
            : Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(context.designTokens.spacing.step5),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: kProseMeasureWidth,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          messages.frontChatEmpty,
                          textAlign: TextAlign.center,
                          style: context
                              .designTokens
                              .typography
                              .styles
                              .body
                              .bodyMedium
                              .copyWith(
                                color: context
                                    .designTokens
                                    .colors
                                    .text
                                    .mediumEmphasis,
                              ),
                        ),
                        SizedBox(height: context.designTokens.spacing.step5),
                        // A first move, a tap away.
                        // Not over words already typed: a send empties the
                        // field, and a starter would take them with it.
                        FrontStarterPrompts(
                          enabled:
                              !composer.isSending &&
                              composer.draft.trim().isEmpty,
                          onChosen: controller.sendText,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        emptyMessage: inboxOnly
            ? messages.frontChatInboxEmpty
            : messages.frontChatEmpty,
        // What the conversation is narrowed to is said where the words go.
        composerHint: scope == null
            ? messages.frontChatPlaceholder
            : messages.frontChatPlaceholderScoped(scope.name),
        sendingLabel: messages.frontChatResponding,
        draft: composer.draft,
        isSending: composer.isSending,
        // Her answer is appearing: nothing says she is still thinking.
        activity: writing ? const SizedBox.shrink() : null,
        hasFailedTurn: composer.failedMessage != null,
        failedTurnLabel: switch (composer.failure) {
          FrontTurnFailure.rateLimit => messages.frontChatFailedRateLimit,
          FrontTurnFailure.timeout => messages.frontChatFailedTimeout,
          FrontTurnFailure.network => messages.frontChatFailedNetwork,
          FrontTurnFailure.authentication =>
            messages.frontChatFailedAuthentication,
          // The provider's own words say which account and what to do.
          FrontTurnFailure.outOfCredit || FrontTurnFailure.provider =>
            agentTurnFailureLabel(messages, composer.failureCause) ??
                messages.frontChatFailedProvider,
          FrontTurnFailure.noModel => messages.frontChatFailedNoModel,
          FrontTurnFailure.noAnswer => messages.frontChatFailedNoAnswer,
          FrontTurnFailure.unknown || null => null,
        },
        onDraftChanged: controller.updateDraft,
        onSend: controller.send,
        // A spoken question gets a spoken answer, whichever of her views —
        // chat or stage — it was said in and is sent from.
        onSendSpoken: controller.sendSpoken,
        draftSpoken: composer.draftSpoken,
        onDraftSpoken: controller.markDraftSpoken,
        // Her ears are the Settings default's transcription slot, the words
        // as heard: never a discovered on-device engine, never a correction
        // pass that keeps the question waiting.
        resolveTranscriptionTarget: ref.watch(
          settingsDefaultDictationTargetProvider,
        ),
        onLinkTap: (_, url, title) => openLink(url, title),
        // Her reply is an A2UI surface of her reply catalog: her words, the
        // tasks she listed as preview cards, the charts and closed-task cards
        // where she placed them, replies to tap — then what her turn's doors
        // made, as preview cards. A reply of words alone is drawn as usual.
        replyBodyBuilder: (context, message, prose) {
          final surface = FrontReplySurfaces.surfaceOf(context, message.id);
          final previews = thread?.entityPreviewsByMessageId[message.id];
          if (surface == null && previews == null) return null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: context.designTokens.spacing.step4,
            children: [
              if (surface == null)
                prose(message.text)
              else
                FrontReplyScope(
                  surface: surface,
                  prose: (markdown) => prose(deviceDays(markdown)),
                  onOpen: openMade,
                  onOpenTask: (id) => openLink(
                    frontReferenceUrl(FrontDestinationKind.task, id),
                    '',
                  ),
                  // A task a door made is not drawn twice.
                  shownIds: {...?previews?.map((preview) => preview.id)},
                  // Not in the inbox: it gathers every conversation, and a
                  // tap would answer in the one picked, not the reply's own.
                  canReply:
                      !inboxOnly &&
                      !composer.isSending &&
                      message.id == latestId,
                  child: A2uiSurface(key: ObjectKey(surface), surface: surface),
                ),
              if (previews != null)
                FrontEntityPreviewList(
                  key: ValueKey('front-entity-previews-${message.id}'),
                  references: previews,
                  // What her turn made is where its cover and its coding
                  // prompt arrive, seen before the task is opened.
                  showsGenerated: true,
                  // A prompt being written is said only of a task a coding
                  // prompt was asked for here: a design or research prompt
                  // started on its page reports the same way.
                  codingPromptTaskIds: {
                    for (final door
                        in thread?.doorsCarriedBy(message.id) ??
                            const <FrontDoorEntry>[])
                      if (door.record.outcome case FrontDoorTaskCreated(
                        :final taskId,
                        :final extras,
                      ) when extras.contains(FrontTaskExtra.codingPrompt))
                        taskId,
                  },
                  onOpen: openMade,
                ),
            ],
          );
        },
        onRetry: controller.retry,
        attachmentBuilder: (context, message) {
          if (thread == null) return null;
          final isHers = message.role == AgentChatRole.agent;
          // The doors ride her reply, as the stack of cards under her bubble;
          // until she has replied they sit under the user's.
          final doors = thread.doorsCarriedBy(message.id);
          final card = doors == null || doors.isEmpty
              ? null
              : Consumer(
                  builder: (context, ref, _) => FrontDoorCard(
                    key: ValueKey('front-doors-${message.id}'),
                    doors: doors,
                    actions: actions,
                    busyDoorIds: composer.busyDoorIds,
                    failedDoorIds: composer.failedDoorIds,
                    // The waiting items a cover can be drawn for, by the
                    // category each one's task would land in — its own,
                    // or its followed task's. Known a moment after it is
                    // asked: the chip is offered once it is.
                    coverArtDoorIds: {
                      for (final door in doors)
                        if (door.record.outcome is FrontDoorInbox)
                          if (ref
                                  .watch(
                                    frontCoverArtAvailableProvider((
                                      categoryId: door.record.task?.categoryId,
                                      followsUpTaskId:
                                          door.record.task?.followsUpTaskId,
                                    )),
                                  )
                                  .value ??
                              false)
                            door.doorId,
                    },
                    journalAccess: journalAccess,
                  ),
                );
          // Chips only under her latest question: an older one has been
          // answered, or walked away from, and its options would send a reply
          // to a question nobody is asking any more.
          final options = isHers && message.id == latestId
              ? thread.optionsByMessageId[message.id]
              : null;
          final chips = options == null || options.isEmpty
              ? null
              : FrontAskOptionsRow(
                  key: ValueKey('front-options-${message.id}'),
                  options: options,
                  enabled: !composer.isSending,
                  onChosen: (option) => controller.sendText(option.label),
                );
          if (card != null && chips != null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                card,
                SizedBox(height: context.designTokens.spacing.step2),
                chips,
              ],
            );
          }
          return card ?? chips;
        },
        dividerBuilder: (context, message, previous) {
          if (previous != null &&
              _sameDay(previous.createdAt, message.createdAt)) {
            return null;
          }
          return DesignSystemDivider(
            label: _dayLabel(context, message.createdAt, locale),
          );
        },
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  /// Today and yesterday by name, every other day by date.
  static String _dayLabel(BuildContext context, DateTime at, String locale) {
    final day = at.toLocal();
    final today = clock.now();
    if (_sameDay(day, today)) return context.messages.calendarTodayLabel;
    if (_sameDay(day, today.subtract(const Duration(days: 1)))) {
      return context.messages.frontChatYesterday;
    }
    return DateFormat.yMMMMEEEEd(locale).format(day);
  }
}
