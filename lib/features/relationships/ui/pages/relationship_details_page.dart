import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/state/agent_query_providers.dart';
import 'package:lotti/features/design_system/components/layout/detail_content_width.dart';
import 'package:lotti/features/design_system/components/spinners/design_system_spinner.dart';
import 'package:lotti/features/design_system/components/toasts/design_system_toast.dart';
import 'package:lotti/features/design_system/components/toasts/toast_messenger.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/model/person_name.dart';
import 'package:lotti/features/relationships/model/person_timeline.dart';
import 'package:lotti/features/relationships/model/relationship_agent_identity.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/person_photo_timeline_trigger.dart';
import 'package:lotti/features/relationships/state/relationship_agent_providers.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/features/relationships/ui/model/people_list_model.dart';
import 'package:lotti/features/relationships/ui/widgets/paused_reminder_callout.dart';
import 'package:lotti/features/relationships/ui/widgets/person_avatar_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/person_brief_card.dart';
import 'package:lotti/features/relationships/ui/widgets/person_contact_row.dart';
import 'package:lotti/features/relationships/ui/widgets/person_create_menu.dart';
import 'package:lotti/features/relationships/ui/widgets/person_header.dart';
import 'package:lotti/features/relationships/ui/widgets/person_note_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/person_task_actions.dart';
import 'package:lotti/features/relationships/ui/widgets/person_timeline_view.dart';
import 'package:lotti/features/relationships/ui/widgets/post_interaction_prompt.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_action_bar.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_briefing_card.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_chat_sheet.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/image_import.dart';
import 'package:lotti/providers/service_providers.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/modal/confirmation_modal.dart';
import 'package:material_ui/material_ui.dart';

/// One person's page (design panel 2026-10-15): who they are, what to know
/// before you talk, and everything that happened and will happen, in time
/// order — one story rather than a stack of cards.
///
/// The hero and the header block with the cadence pills, the person's
/// labelled ways to reach them, then *Before you talk* — the user's own
/// notes for next time over the agent's briefing — then the notes pinned
/// *About* them, then their timeline (ADR 0138): check-ins, notes, voice
/// notes, photos, tasks and meetings on one rail. The sticky bar captures —
/// *Speak*, *Log check-in*, and **+** for everything else.
///
/// On the desktop split the same page fills the detail pane, on one centred
/// reading column. Deleting cascades through the repository, the agent and
/// the reminder (the same three legs as before).
class RelationshipDetailsPage extends ConsumerStatefulWidget {
  const RelationshipDetailsPage({required this.relationshipId, super.key});

  final String relationshipId;

  @override
  ConsumerState<RelationshipDetailsPage> createState() =>
      _RelationshipDetailsPageState();
}

class _RelationshipDetailsPageState
    extends ConsumerState<RelationshipDetailsPage> {
  PersonTimelineFilter _filter = PersonTimelineFilter.all;

  String get relationshipId => widget.relationshipId;

  @override
  void didUpdateWidget(RelationshipDetailsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The desktop split keeps this state when another person is picked: a
    // filter chosen for one person's history is not a choice about theirs.
    if (oldWidget.relationshipId != relationshipId) {
      _filter = PersonTimelineFilter.all;
    }
  }

  Future<void> _handleDelete(
    BuildContext context,
    RelationshipEntry relationship,
  ) async {
    final confirmed = await showConfirmationModal(
      context: context,
      title: context.messages.relationshipDeleteConfirmTitle(
        relationship.data.title,
      ),
      message: context.messages.relationshipDeleteConfirmMessage,
      confirmLabel: context.messages.deleteButton,
    );
    if (!confirmed || !context.mounted) return;

    final logger = ref.read(domainLoggerProvider);
    try {
      final deleted = await ref
          .read(relationshipRepositoryProvider)
          .deleteRelationship(relationship.id);
      if (deleted) {
        // The cascade's agent leg (ADR 0059 Decision 7): contained —
        // the person is gone either way, and a failed agent teardown is
        // repaired by runtime maintenance, not by failing this delete.
        unawaited(() async {
          try {
            await ref
                .read(relationshipAgentServiceProvider)
                .handleRelationshipDeleted(relationship.id);
          } catch (_) {
            // Logged by the service layer where possible; never surfaced.
          }
        }());
        // The cascade's reminder leg (ADR 0037 §5): an alarm armed weeks
        // ago would otherwise still fire, naming someone the user deleted.
        // Destroying the agent stops Phase A from clearing it later, so
        // this cannot be left to the next tick.
        //
        // Guarded like the agent leg, and for the same reason: `ref.read`
        // itself throws once this widget is disposed, and the await above is
        // long enough for that to happen. Unguarded it would surface as
        // "could not delete" for a delete that succeeded.
        unawaited(() async {
          try {
            await ref
                .read(relationshipReminderServiceProvider)
                .clearFor(relationship.id);
          } catch (_) {
            // clearFor is non-throwing by contract; this guards the read.
          }
        }());
      }
      if (!context.mounted) return;
      if (deleted) {
        beamToNamed('/people');
      } else {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.relationshipErrorDeleteFailed,
        );
      }
    } catch (e, s) {
      logger.error(
        LogDomain.general,
        e,
        stackTrace: s,
        subDomain: 'RelationshipDetailsPage',
        message: 'Failed to delete relationship',
      );
      if (context.mounted) {
        context.showToast(
          tone: DesignSystemToastTone.error,
          title: context.messages.relationshipErrorDeleteFailed,
        );
      }
    }
  }

  /// Leaves the page. On a phone the page was pushed and pops; on the
  /// desktop split it is the detail pane, and leaving means clearing the
  /// selection so the list stands alone again.
  /// The page's two ways into the composer. A call or message just placed
  /// to this person is logged as that — channel, start and minutes — exactly
  /// as the offer under the name would, because reaching for the big button
  /// instead of the offer is the same intent. Otherwise the composer starts
  /// from how the two of you last connected ([latest]) rather than always
  /// from *In person*: for someone you phone every week, the chip is then
  /// already right.
  Future<void> _openComposer(
    BuildContext context, {
    required CheckInEntry? latest,
    bool startSpeaking = false,
  }) async {
    await openCheckInForPerson(
      context: context,
      ref: ref,
      relationshipId: relationshipId,
      fallbackInteractionType: latest?.data.interactionType,
      startSpeaking: startSpeaking,
    );
  }

  void _back(BuildContext context) {
    if (isDesktopLayout(context)) {
      beamToNamed('/people');
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final detailAsync = ref.watch(
      relationshipDetailControllerProvider(relationshipId),
    );
    // Keep the last rendered detail during background reloads.
    final detail = detailAsync.value;

    if (detail == null) {
      // Resolved-null means the person is gone (deleted here or on another
      // device) — that is not an error, so say so instead of alarming.
      final body = detailAsync.isLoading
          ? const DesignSystemSpinner()
          : Text(
              detailAsync.hasError
                  ? context.messages.commonError
                  : context.messages.relationshipNotFound,
              style: tokens.typography.styles.body.bodyMedium.copyWith(
                color: tokens.colors.text.mediumEmphasis,
              ),
            );
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: body),
      );
    }

    final relationship = detail.relationship;
    final checkIns = detail.checkIns;
    final latest = checkIns.firstOrNull;
    final item = (relationship: relationship, lastCheckIn: latest);
    final categoryId = relationship.meta.categoryId;
    final categoryName = categoryId == null
        ? null
        : getIt<EntitiesCacheService>().getCategoryById(categoryId)?.name;

    // The health band is not read here: it belongs to the briefing card,
    // which is the only surface that can date it ("Thriving · as of 3 h
    // ago"). An undated copy of the same word in the header said the fact
    // twice and said it less truthfully, so the page no longer watches the
    // report at all.
    //
    // Whether an agent *can be talked to* is a different question from
    // whether reminders are on, and the hero needs the first one. Unmarking
    // a person, or making them dormant, stops the cadence but deliberately
    // keeps the agent and its conversation (`RelationshipAgentService`),
    // so gating the chat on enrolment would remove the only ordinary way
    // back into a chat that still exists. Once an identity row exists it
    // is the chat pane's own question — an ACTIVE relationship agent — and
    // enrolment no longer counts: pausing or destroying keeps the row (for
    // audit, and `ensureAgentForRelationship` preserves the lifecycle on
    // re-enrolment), so an enrolled person with a destroyed agent is a
    // persistent state, and a button there led to the pane's unavailable
    // screen. Only while no row exists yet — an enrolled person whose agent
    // has not named itself — does enrolment stand in for it.
    final agentId = relationshipAgentIdFor(relationshipId);
    final identity = ref.watch(agentIdentityProvider(agentId)).value;
    final hasAgent = identity == null
        ? isEnrolled(relationship)
        : usableRelationshipAgent(identity) != null;
    final personName = relationship.shortName;
    final now = clock.now();
    final upcoming = buildPersonTimeline(
      now: now,
      checkIns: const [],
      entries: detail.timelineEntries,
      tasks: const [],
    ).sections.where((s) => s.kind == PersonTimelineSectionKind.upcoming);
    final nextMeeting = upcoming.isEmpty
        ? null
        : upcoming.first.items.whereType<TimelineMeeting>().firstOrNull;
    final timeline = buildPersonTimeline(
      now: now,
      checkIns: checkIns,
      entries: detail.timelineEntries,
      tasks: detail.linkedTasks,
      checkInEntries: detail.checkInEntries,
      filter: _filter,
    );
    final tasks = PersonTaskActions(
      relationshipId: relationshipId,
      linkedTaskIds: {for (final task in detail.linkedTasks) task.meta.id},
      personName: personName,
      categoryId: categoryId,
    );
    final actions = (
      openCheckIn: (CheckInEntry checkIn) => beamToNamed(
        '/people/$relationshipId/check-ins/${checkIn.meta.id}',
      ),
      openNote: (JournalEntry note) => showPersonNoteSheet(
        context: context,
        person: relationship,
        note: note,
      ),
      openEntry: (JournalEntity entry) =>
          beamToNamed('/journal/${entry.meta.id}'),
      openTask: (Task task) => beamToNamed('/tasks/${task.meta.id}'),
      unlinkTask: (Task task) => tasks.unlinkTask(context, ref, task),
    );

    Future<void> create() async {
      final choice = await showPersonCreateMenu(
        context: context,
        personName: personName,
      );
      if (choice == null || !context.mounted) return;
      switch (choice) {
        case PersonCreateChoice.note:
          await showPersonNoteSheet(context: context, person: relationship);
        case PersonCreateChoice.task:
          await tasks.pickTask(context, ref);
        case PersonCreateChoice.photos:
          final trigger = ref.read(personPhotoTimelineTriggerProvider);
          await importImagesForPlatform(
            context,
            linkedId: relationshipId,
            categoryId: categoryId,
            analysisTrigger: trigger,
            // A photo the journal already holds is linked, not created, so
            // the trigger's analysis never runs for it; it still belongs on
            // the timeline, through the same logged link.
            onExisting: (entryId) => trigger.putOnTimeline(
              personId: relationshipId,
              entryId: entryId,
            ),
          );
        case PersonCreateChoice.checkIn:
          await _openComposer(context, latest: latest);
      }
    }

    final gap = SizedBox(height: tokens.spacing.sectionGap);
    final whoBlock = <Widget>[
      PersonHeaderBlock(
        item: item,
        categoryName: categoryName,
        // The verbs first, then the reminders control, as one row.
        actions: PersonContactRow(
          relationship: relationship,
          trailing: personHeaderPills(
            context,
            item,
          ),
        ),
      ),
      gap,
      // Under the person's name: the reminder the user just tapped says it
      // is paused, and until when.
      PausedReminderCallout(
        relationshipId: relationshipId,
        bottomGap: tokens.spacing.sectionGap,
      ),
      // Renders nothing until the user comes back from a call placed on
      // this page; then it is the most time-sensitive thing here, so it
      // sits where they land.
      PostInteractionPrompt(
        relationshipId: relationshipId,
        bottomGap: tokens.spacing.sectionGap,
      ),
    ];
    final nextTime = PersonBriefCard.sourceOf(checkIns);
    final hasNotes = PersonBriefCard.hasContent(nextTime);
    // What to know before you talk: one card whose headline is the user's
    // own note to bring up — never under the agent's tint, so their words
    // read as theirs — with what to avoid and the next meeting under it;
    // then the agent's briefing, then what they pinned About the person.
    final showMeeting = nextMeeting != null;
    List<Widget> briefing({required bool compact}) => [
      if (hasNotes || (showMeeting && compact)) ...[
        PersonBriefCard(
          source: nextTime,
          // On a wide pane the timeline's own Upcoming row sits right beside
          // this rail and says it already.
          meeting: compact ? nextMeeting : null,
          now: now,
          onOpenSource: hasNotes ? () => actions.openCheckIn(nextTime!) : null,
          onOpenMeeting: nextMeeting == null
              ? null
              : () => actions.openEntry(nextMeeting.event),
        ),
        SizedBox(height: tokens.spacing.step4),
      ],
      // Always present: an unenrolled person gets the offer that explains
      // what reminders turn on.
      RelationshipBriefingCard(
        relationship: relationship,
        checkIns: checkIns,
        folded: compact && hasNotes,
      ),
      // On a phone the folded rows under the card are one list of doors,
      // not sections of their own: they sit a step apart, not a section gap.
      if (timeline.pinned.isNotEmpty) ...[
        if (compact) SizedBox(height: tokens.spacing.step3) else gap,
        PersonAboutSection(
          personName: personName,
          pinned: timeline.pinned,
          onOpen: actions.openNote,
          compact: compact,
        ),
      ],
      gap,
    ];

    final bar = RelationshipActionBar(
      personName: personName,
      onSpeak: () => unawaited(
        _openComposer(context, latest: latest, startSpeaking: true),
      ),
      onAdd: () => unawaited(create()),
    );

    return Scaffold(
      backgroundColor: tokens.colors.background.level01,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bottomInset = MediaQuery.paddingOf(context).bottom;
          // A pane as wide as a desktop window gets a rail: what to know
          // before you talk stays beside the history, scrolling on its own,
          // instead of above it and gone once the reader scrolls (design
          // panel 2026-10-15). Flex shares of the pane, so no width of its
          // own is invented.
          final wide = constraints.maxWidth >= kDesktopBreakpoint;
          Widget pageBody(BuildContext context, BoxConstraints constraints) {
            final bottomInset = MediaQuery.paddingOf(context).bottom;
            final insets = detailContentInsets(
              context,
              availableWidth: constraints.maxWidth,
            );
            final rowInset = tokens.spacing.step3;
            return CustomScrollView(
              slivers: [
                PersonHeroAppBar(
                  relationship: relationship,
                  contentInset: insets.left,
                  onBack: () => _back(context),
                  // Desktop: the side sheet over this page. A phone pushes
                  // the conversation as its own page.
                  onTalkToAgent: () => isDesktopLayout(context)
                      ? showRelationshipChatSheet(
                          context,
                          relationshipId: relationshipId,
                        )
                      : beamToNamed('/people/$relationshipId/chat'),
                  onDelete: () => _handleDelete(context, relationship),
                  hasAgent: hasAgent,
                  onAvatarTap: () => showPersonAvatarSheet(
                    context: context,
                    relationship: relationship,
                  ),
                ),
                SliverPadding(
                  padding: insets,
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      ...whoBlock,
                      if (!wide) ...briefing(compact: true),
                    ]),
                  ),
                ),
                // The timeline grows without bound and renders lazily in its
                // own sliver. It is outdented by its rows' own inset, so a
                // row's tile sits on the page's text edge and its hover fill
                // reaches into the gutter.
                SliverPadding(
                  padding: insets.copyWith(
                    left: math.max(0, insets.left - rowInset),
                    right: math.max(0, insets.right - rowInset),
                  ),
                  sliver: PersonTimelineSliver(
                    timeline: timeline,
                    personName: personName,
                    filter: _filter,
                    onFilter: (filter) => setState(() => _filter = filter),
                    actions: actions,
                    now: now,
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: bottomInset + tokens.spacing.sectionGap,
                  ),
                ),
              ],
            );
          }

          // The page — hero, header, timeline — with the capture bar docked
          // under it: its own Scaffold, so on a wide pane the bar sits on the
          // timeline's column, centred over the history it adds to, and
          // never covers the rail. extendBody so the glass strip's
          // BackdropFilter has content underneath to blur; the Scaffold
          // reserves the bar's height as the body's bottom inset, which the
          // trailing spacer consumes.
          Widget page(BoxConstraints constraints) => Scaffold(
            backgroundColor: tokens.colors.background.level01,
            extendBody: true,
            bottomNavigationBar: bar,
            // A LayoutBuilder for two reasons: MediaQuery.paddingOf below it
            // reads this Scaffold's value, and the column is centred within
            // the width the page actually has.
            body: LayoutBuilder(
              builder: pageBody,
            ),
          );

          if (!wide) return page(constraints);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: LayoutBuilder(
                  builder: (context, constraints) => page(constraints),
                ),
              ),
              Expanded(
                flex: 2,
                child: DecoratedBox(
                  key: const ValueKey('person-rail'),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: tokens.colors.decorative.level01),
                    ),
                  ),
                  child: SingleChildScrollView(
                    // The page column's own gutter, so the two columns
                    // share one rhythm.
                    padding: EdgeInsets.fromLTRB(
                      tokens.spacing.step5,
                      MediaQuery.paddingOf(context).top + tokens.spacing.step5,
                      tokens.spacing.step5,
                      bottomInset + tokens.spacing.sectionGap,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: briefing(compact: false),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
