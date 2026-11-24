import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/categories/state/categories_list_controller.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/model/front_task_draft.dart';
import 'package:lotti/features/front_agent/model/front_turn_failure.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/features/front_agent/service/front_filing_service.dart';
import 'package:lotti/features/front_agent/state/front_agent_providers.dart';
import 'package:lotti/features/front_agent/state/front_chat_category.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_conversation_providers.dart';
import 'package:lotti/features/front_agent/state/front_draft_pages.dart';
import 'package:lotti/features/front_agent/state/front_inbox_filter.dart';
import 'package:lotti/features/front_agent/state/front_mention_categories.dart';
import 'package:lotti/features/front_agent/state/front_voice_providers.dart';

@immutable
class FrontChatComposerState {
  const FrontChatComposerState({
    this.draft = '',
    this.draftSpoken = false,
    this.isSending = false,
    this.sendingMessageId,
    this.editingMessageId,
    this.asideDrafts = const [],
    this.draftPage = 0,
    this.failedMessage,
    this.failedMessageId,
    this.failedConversationId,
    this.failedCategoryIds = const {},
    this.failedReplaces,
    this.failure,
    this.failureCause,
    this.busyDoorIds = const {},
    this.failedDoorIds = const {},
  });

  final String draft;

  /// Whether [draft] came from what was said, so it goes out as a spoken
  /// turn from whichever view sends it — her chat or her stage.
  final bool draftSpoken;
  final bool isSending;

  /// The turn on its way, once it is durable: what Stop stops, and the one
  /// message of the thread she is working on.
  final String? sendingMessageId;

  /// The stopped turn whose words [draft] was taken from: the draft, sent,
  /// takes its place in the thread.
  final String? editingMessageId;

  /// The box's other pages — what was typed there when the words of a
  /// stopped turn were taken back into it — which the user can flip to.
  final List<FrontDraftPage> asideDrafts;

  /// Where among [asideDrafts] the page in the box sits.
  final int draftPage;

  /// Every page of the box, the one in it — [draft] — included.
  FrontDraftPages get draftPages => FrontDraftPages.of(
    current: FrontDraftPage(draft, editingMessageId: editingMessageId),
    aside: asideDrafts,
    index: draftPage,
  );

  /// Doors whose action — filing, declining, a chip — is in flight.
  final Set<String> busyDoorIds;

  /// Doors whose last action did not go through; cleared by the next one.
  final Set<String> failedDoorIds;

  /// The text of the turn that did not send, offered for a retry.
  final String? failedMessage;

  /// The durable id of that turn when it was persisted before failing, so a
  /// retry re-wakes the same turn instead of writing a duplicate.
  final String? failedMessageId;

  /// The conversation the failed turn was typed in, so a retry lands there
  /// even after the user opened another one.
  final String? failedConversationId;

  /// The categories the failed turn was scoped to, so a retry carries the
  /// scope it was typed under, whatever is picked since.
  final Set<String> failedCategoryIds;

  /// The stopped turn the failed turn was edited from, so a retry that has
  /// to write it again still takes that turn's place.
  final String? failedReplaces;

  /// Why that turn did not go through, so the chat can say what to do.
  final FrontTurnFailure? failure;

  /// The exception behind [failure], in memory only, for the chat to relay
  /// the provider's own words (an empty balance names where to top up).
  final Object? failureCause;

  /// A copy never carries the send failure: an edit to the draft and the
  /// start of a send both clear it, and a failure is only ever set whole.
  /// The doors' state rides along untouched.
  ///
  /// An empty draft is never spoken, nor an edit: emptying the field, or a
  /// send, clears [draftSpoken] and [editingMessageId] with it.
  FrontChatComposerState copyWith({
    String? draft,
    bool? draftSpoken,
    bool? isSending,
    String? sendingMessageId,
    String? editingMessageId,
    List<FrontDraftPage>? asideDrafts,
    int? draftPage,
    Set<String>? busyDoorIds,
    Set<String>? failedDoorIds,
  }) => FrontChatComposerState(
    draft: draft ?? this.draft,
    draftSpoken:
        (draft ?? this.draft).isNotEmpty && (draftSpoken ?? this.draftSpoken),
    isSending: isSending ?? this.isSending,
    sendingMessageId: sendingMessageId ?? this.sendingMessageId,
    editingMessageId: (draft ?? this.draft).isEmpty
        ? null
        : editingMessageId ?? this.editingMessageId,
    asideDrafts: asideDrafts ?? this.asideDrafts,
    draftPage: draftPage ?? this.draftPage,
    busyDoorIds: busyDoorIds ?? this.busyDoorIds,
    failedDoorIds: failedDoorIds ?? this.failedDoorIds,
  );

  /// A copy with [pages] in the box — like [copyWith], no send failure
  /// carried, and the words shown are typed, not spoken.
  FrontChatComposerState withDraftPages(FrontDraftPages pages) =>
      FrontChatComposerState(
        draft: pages.current.text,
        isSending: isSending,
        sendingMessageId: sendingMessageId,
        editingMessageId: pages.current.text.isEmpty
            ? null
            : pages.current.editingMessageId,
        asideDrafts: pages.aside,
        draftPage: pages.index,
        busyDoorIds: busyDoorIds,
        failedDoorIds: failedDoorIds,
      );

  /// The state after a send settled, with the doors' state kept. A draft
  /// put back after a failure stays the edit of [editingMessageId]; the
  /// pages set [aside] come before it, and with nothing in the box the last
  /// of them is what it shows.
  FrontChatComposerState settled({
    String draft = '',
    String? editingMessageId,
    List<FrontDraftPage> aside = const [],
    String? failedMessage,
    String? failedMessageId,
    String? failedConversationId,
    Set<String> failedCategoryIds = const {},
    String? failedReplaces,
    FrontTurnFailure? failure,
    Object? failureCause,
  }) {
    final pages = FrontDraftPages.settle([
      ...aside,
      FrontDraftPage(draft, editingMessageId: editingMessageId),
    ]);
    return FrontChatComposerState(
      draft: pages.current.text,
      editingMessageId: pages.current.text.isEmpty
          ? null
          : pages.current.editingMessageId,
      asideDrafts: pages.aside,
      draftPage: pages.index,
      failedMessage: failedMessage,
      failedMessageId: failedMessageId,
      failedConversationId: failedConversationId,
      failedCategoryIds: failedCategoryIds,
      failedReplaces: failedMessage == null ? null : failedReplaces,
      failure: failedMessage == null
          ? null
          : failure ?? FrontTurnFailure.unknown,
      failureCause: failedMessage == null ? null : failureCause,
      busyDoorIds: busyDoorIds,
      failedDoorIds: failedDoorIds,
    );
  }
}

/// Keep-alive: a draft survives closing and reopening the sheet (the goal
/// and person chat controllers' shape). There is one front agent, so there
/// is one composer, whichever conversation is open.
final frontChatControllerProvider =
    NotifierProvider<FrontChatController, FrontChatComposerState>(
      FrontChatController.new,
      name: 'frontChatControllerProvider',
    );

class FrontChatController extends Notifier<FrontChatComposerState> {
  @override
  FrontChatComposerState build() => const FrontChatComposerState();

  void updateDraft(String value) {
    state = state.copyWith(draft: value);
  }

  /// What was said landed in the draft: it goes out as a spoken turn.
  void markDraftSpoken() {
    state = state.copyWith(draftSpoken: true);
  }

  /// Takes the words of stopped turn [messageId] back into the box; sent,
  /// they take its place in the thread. What the box already held is not
  /// lost: it stays a page of its own, a flip away ([showDraftPage]).
  void edit(String messageId, String text) {
    state = state.withDraftPages(
      state.draftPages.adding(
        FrontDraftPage(text, editingMessageId: messageId),
      ),
    );
  }

  /// Puts page [index] of the box in it; see [FrontDraftPages.showing].
  void showDraftPage(int index) {
    state = state.withDraftPages(state.draftPages.showing(index));
  }

  /// Sends the draft.
  Future<void> send() =>
      sendText(state.draft, replaces: state.editingMessageId);

  /// Stops the turn on its way — or [turnId], a turn still waiting on her
  /// that this device did not send, or no longer remembers sending: she
  /// does not answer it, the thread shows it stopped, and its words can be
  /// taken back into the box to send again. The send then settles as one
  /// that went through. Nothing to stop until the turn is durable.
  Future<void> stop([String? turnId]) async {
    final messageId = turnId ?? state.sendingMessageId;
    if (messageId == null) return;
    final ours = messageId == state.sendingMessageId;
    try {
      await ref
          .read(frontChatServiceProvider)
          .stopMessage(messageId: messageId);
    } on Object {
      // Not recorded: the turn goes on — its answer still spoken if it was
      // asked aloud — and Stop can be pressed again.
      return;
    }
    // No answer is coming to speak — if the one stopped was the one asked.
    if (ours) ref.read(frontSpokenTurnProvider.notifier).settle();
  }

  void _sending(String messageId) {
    state = state.copyWith(sendingMessageId: messageId);
  }

  /// Sends the draft the user spoke — a transcript — so her reply is spoken
  /// back.
  Future<void> sendSpoken() =>
      sendText(state.draft, spoken: true, replaces: state.editingMessageId);

  /// Sends [text] as the user's next turn — the draft, or the label of a
  /// chip the user tapped under a clarifying question. A [spoken] turn's
  /// reply is spoken back; any other turn's only written. The turn carries
  /// the category its conversation is scoped to ([frontChatCategoryOf]), and
  /// the stopped turn it [replaces] when it was edited from one.
  Future<void> sendText(
    String text, {
    bool spoken = false,
    String? replaces,
  }) async {
    final message = text.trim();
    if (state.isSending || message.isEmpty) return;
    // A send is a new turn, and its conversation is where it lands.
    ref.read(frontInboxFilterProvider.notifier).clear();
    // The words leave the box as they are sent — her thread shows them
    // straight away — and come back only if the send fails. Its other pages
    // wait aside until the send settles.
    final rest = state.asideDrafts;
    final sentFrom = _open;
    state = state.copyWith(
      isSending: true,
      draft: '',
      asideDrafts: const [],
      draftPage: 0,
    );
    String? conversationId;
    var categoryIds = const <String>{};
    try {
      final landing = conversationId = await _landingConversation();
      categoryIds = _categoryIdsOf(landing);
      final pick = ref.read(frontChatCategoryPickProvider);
      // Marked before the turn is written: her reply can land before the
      // send returns.
      final voice = ref.read(frontSpokenTurnProvider.notifier);
      spoken ? voice.spoke(landing) : voice.settle();
      // The identity is created on first use, with the narrow default
      // allow-list (decision 4).
      await ref.read(frontAgentServiceProvider).getOrCreate();
      await ref
          .read(frontChatServiceProvider)
          .sendMessage(
            text: message,
            conversationId: landing,
            categoryIds: categoryIds,
            replaces: replaces,
            onAppended: _sending,
          );
      await _unarchive(landing);
      // Listened before the index reloads, so the reload is seen.
      _expirePickOnceStored(landing, pick);
      _reproject();
      // What the user typed while it was on its way stays in the box.
      state = state.settled(
        draft: state.draft,
        editingMessageId: state.editingMessageId,
        aside: _asideAfterSend(sentFrom, rest),
      );
    } on FrontChatTurnException catch (error) {
      // No answer is coming for a turn that did not go through.
      ref.read(frontSpokenTurnProvider.notifier).settle();
      _reproject();
      state = state.settled(
        draft: state.draft,
        editingMessageId: state.editingMessageId,
        aside: _asideAfterSend(
          sentFrom,
          rest,
          FrontDraftPage(message, editingMessageId: replaces),
        ),
        failedMessage: message,
        failedMessageId: error.messageId,
        failedConversationId: conversationId,
        failedCategoryIds: categoryIds,
        failedReplaces: replaces,
        failure: error.failure,
        failureCause: error.cause,
      );
    } catch (_) {
      ref.read(frontSpokenTurnProvider.notifier).settle();
      state = state.settled(
        draft: state.draft,
        editingMessageId: state.editingMessageId,
        aside: _asideAfterSend(
          sentFrom,
          rest,
          FrontDraftPage(message, editingMessageId: replaces),
        ),
        failedMessage: message,
        failedConversationId: conversationId,
        failedCategoryIds: categoryIds,
        failedReplaces: replaces,
      );
    }
  }

  /// The categories a turn sent in [conversationId] carries: the one the
  /// composer's chip shows, as a set of one, or none for "Everything".
  /// While the categories are still loading nothing can be checked, so the
  /// scope goes out as it stands rather than being dropped — her workflow
  /// never widens to one she may not see.
  Set<String> _categoryIdsOf(String conversationId) {
    final pick = ref.read(frontChatCategoryPickProvider);
    final conversation = ref
        .read(frontConversationsProvider)
        .value
        ?.byId(conversationId);
    if (!ref.read(categoriesStreamProvider).hasValue) {
      return {
        ?frontChatCategoryIdOf(
          conversationId,
          pick: pick,
          conversation: conversation,
        ),
      };
    }
    return {
      ?frontChatCategoryOf(
        conversationId,
        pick: pick,
        conversation: conversation,
        options: ref.read(frontMentionCategoriesProvider),
      )?.id,
    };
  }

  /// A pick sent in [conversationId] is the conversation's own scope once
  /// the index has reloaded after the send, so [sent] is dropped there and
  /// the stored scope speaks: the turn that carries it, or a newer one from
  /// another device in another category, which wins as the newest turn
  /// does. A pick made since is the user's newer word and is kept.
  ///
  /// Listened before [_reproject] invalidates the index, with no await
  /// between: the first index settled after it is read after the turn was
  /// written, never one that misses it.
  void _expirePickOnceStored(
    String conversationId,
    FrontChatCategoryPick? sent,
  ) {
    if (sent == null || sent.conversationId != conversationId) return;
    ProviderSubscription<AsyncValue<FrontConversationIndex>>? subscription;
    subscription = ref.listen(frontConversationsProvider, (_, next) {
      if (next.isLoading || !next.hasValue) return;
      subscription?.close();
      if (identical(ref.read(frontChatCategoryPickProvider), sent)) {
        ref.read(frontChatCategoryPickProvider.notifier).reset();
      }
    });
  }

  /// The pages beside the box once a send from [sentFrom] settles: [rest],
  /// set aside as it started, then [back] — the words a failure puts back,
  /// still the edit they were — then the pages made while it was on its
  /// way. Nothing said is lost: whatever was typed since stays in the box,
  /// the words that did not go a page back.
  ///
  /// When the user has moved to another conversation since, those pages go
  /// to the one they were typed in — parked, before any typed there during
  /// the send — and the box shown is left as it is.
  List<FrontDraftPage> _asideAfterSend(
    String? sentFrom,
    List<FrontDraftPage> rest, [
    FrontDraftPage? back,
  ]) {
    if (sentFrom != null && sentFrom != _open) {
      _drafts[sentFrom] = FrontDraftPages.settle([
        ...rest,
        ?back,
        ...?_drafts[sentFrom]?.pages,
      ]);
      return state.asideDrafts;
    }
    return [...rest, ?back, ...state.asideDrafts];
  }

  /// Talking in an archived conversation brings it back: it is in use. Best
  /// effort — the turn is sent, so a failure here must not offer a retry
  /// that would write it twice.
  Future<void> _unarchive(String conversationId) async {
    final sentIn = ref
        .read(frontConversationsProvider)
        .value
        ?.byId(conversationId);
    if (!(sentIn?.archived ?? false)) return;
    try {
      await ref
          .read(frontConversationServiceProvider)
          .archive(conversationId, archived: false);
    } catch (_) {
      // Still archived; the next send tries again.
    }
  }

  Future<void> retry() async {
    final failed = state.failedMessage;
    final messageId = state.failedMessageId;
    final typedIn = state.failedConversationId;
    final scopedTo = state.failedCategoryIds;
    final replaces = state.failedReplaces;
    if (failed == null || state.isSending) return;
    final retriedFrom = _open;
    state = state.copyWith(isSending: true);
    try {
      final service = ref.read(frontChatServiceProvider);
      if (messageId == null) {
        final conversationId = typedIn ?? await _landingConversation();
        await ref.read(frontAgentServiceProvider).getOrCreate();
        await service.sendMessage(
          text: failed,
          conversationId: conversationId,
          categoryIds: scopedTo,
          replaces: replaces,
          onAppended: _sending,
        );
      } else {
        _sending(messageId);
        await service.retryMessage(messageId: messageId);
      }
      _reproject();
      if (retriedFrom != null && retriedFrom != _open) {
        // Opened another conversation meanwhile: the page leaves the one
        // it was retried from, parked, and the box shown stays as it is.
        if (_drafts[retriedFrom] case final parked?) {
          final sent = _sentPage(parked.pages, failed, replaces);
          _drafts[retriedFrom] = FrontDraftPages.settle([
            for (var i = 0; i < parked.pages.length; i++)
              if (i != sent) parked.pages[i],
          ]);
        }
        state = state.copyWith(isSending: false);
      } else {
        state = _settledWithout(failed, replaces);
      }
    } on FrontChatTurnException catch (error) {
      _reproject();
      // The box as it is now: the words are on the failure, and whatever
      // was typed while it was retried stays.
      state = state.settled(
        draft: state.draft,
        editingMessageId: state.editingMessageId,
        aside: state.asideDrafts,
        failedMessage: failed,
        failedMessageId: error.messageId ?? messageId,
        failedConversationId: typedIn,
        failedCategoryIds: scopedTo,
        failedReplaces: replaces,
        failure: error.failure,
        failureCause: error.cause,
      );
    } catch (_) {
      state = state.settled(
        draft: state.draft,
        editingMessageId: state.editingMessageId,
        aside: state.asideDrafts,
        failedMessage: failed,
        failedMessageId: messageId,
        failedConversationId: typedIn,
        failedCategoryIds: scopedTo,
        failedReplaces: replaces,
      );
    }
  }

  /// The state once a retry of [failed] went through: the page it was put
  /// back on — the last with its words and edit, never another that only
  /// shares its words — leaves the box, and the box shows the page before
  /// it if it was in it. Anything typed while the retry ran stays.
  FrontChatComposerState _settledWithout(String failed, String? replaces) {
    final pages = state.draftPages;
    final sent = _sentPage(pages.pages, failed, replaces);
    final others = [
      for (var i = 0; i < pages.pages.length; i++)
        if (i != sent && i != pages.index) pages.pages[i],
    ];
    return sent == pages.index
        ? state.settled(aside: others)
        : state.settled(
            draft: state.draft,
            editingMessageId: state.editingMessageId,
            aside: others,
          );
  }

  /// Where in [pages] the retry of [failed] was put back: the last page
  /// with its words and edit, never another that only shares its words;
  /// -1 for none.
  static int _sentPage(
    List<FrontDraftPage> pages,
    String failed,
    String? replaces,
  ) => pages.lastIndexWhere(
    (page) => page.text.trim() == failed && page.editingMessageId == replaces,
  );

  /// The conversation a send lands in: the active one, pinned, so a newer
  /// conversation arriving from another device does not take the surface
  /// out from under the reply.
  Future<String> _landingConversation() async {
    final id = await ref.read(frontActiveConversationProvider.future);
    ref.read(frontPickedConversationProvider.notifier).picked = id;
    return id;
  }

  /// Re-reads what a write changed: the shown thread, the inbox it counts
  /// from, and the conversation list.
  void _reproject() => ref
    ..invalidate(frontChatThreadProvider)
    ..invalidate(frontAllChatsThreadProvider)
    ..invalidate(frontConversationsProvider);

  /// The conversation on the surface now: the one picked — read first,
  /// since the resolved one is async and lags a pick — else the one
  /// resolved for "where I left off".
  String? get _open {
    final picker = ref.read(frontPickedConversationProvider.notifier);
    final picked = picker.picked;
    // A pick from another day, or of a conversation since deleted, is not
    // what the surface shows any more.
    final deleted =
        ref.read(frontConversationsProvider).value?.deletedIds ?? const {};
    return picked != null &&
            picker.pickedOn(clock.now()) &&
            !deleted.contains(picked)
        ? picked
        : ref.read(frontActiveConversationProvider).value;
  }

  /// The box's pages in the conversations the user switched away from, so
  /// a half-typed message — or an edit — stays with the conversation it
  /// was written for.
  final _drafts = <String, FrontDraftPages>{};

  /// Opens [conversationId]; the inbox filter, which spans them all, is
  /// left.
  void openConversation(String conversationId) => _switch(
    () => ref.read(frontPickedConversationProvider.notifier).picked =
        conversationId,
  );

  /// Whether [conversationId] is the one on the surface.
  bool isOpen(String conversationId) => _open == conversationId;

  /// A new, empty conversation — unless the open one is already new and
  /// empty, whose draft would otherwise be orphaned under an id nothing
  /// lists.
  void startConversation() {
    final open = _open;
    final index = ref.read(frontConversationsProvider).value;
    if (open != null && index != null && index.byId(open) == null) {
      ref.read(frontInboxFilterProvider.notifier).clear();
      return;
    }
    _switch(ref.read(frontPickedConversationProvider.notifier).startNew);
  }

  /// Switches the surface with [pick], parking the draft of the conversation
  /// left and taking up the one of the conversation opened. A category
  /// picked and not yet sent stays behind: the one opened is in the scope
  /// its own turns say.
  void _switch(void Function() pick) {
    ref.read(frontInboxFilterProvider.notifier).clear();
    final from = _open;
    final pages = state.draftPages;
    if (from != null && pages.pages.any((page) => page.text.isNotEmpty)) {
      _drafts[from] = pages;
    }
    pick();
    final to = ref.read(frontPickedConversationProvider);
    if (to != from) {
      state = state.withDraftPages(
        _drafts.remove(to) ?? FrontDraftPages.settle(const []),
      );
      ref.read(frontChatCategoryPickProvider.notifier).reset();
    }
  }

  Future<void> renameConversation(String conversationId, String title) async {
    await ref
        .read(frontConversationServiceProvider)
        .rename(
          conversationId,
          title,
        );
    _reproject();
  }

  Future<void> archiveConversation(
    String conversationId, {
    required bool archived,
  }) async {
    await ref
        .read(frontConversationServiceProvider)
        .archive(conversationId, archived: archived);
    // Archiving the open one puts it away, as deleting does.
    if (archived) _leave(conversationId);
    _reproject();
  }

  /// Deletes [conversationId]; when it was the open one, the surface goes
  /// back to where the user left off elsewhere.
  Future<void> deleteConversation(String conversationId) async {
    await ref.read(frontConversationServiceProvider).delete(conversationId);
    _leave(conversationId);
    _reproject();
  }

  /// When [conversationId] is the open one, the surface moves to a new,
  /// empty conversation: the next message must not land in some older one.
  void _leave(String conversationId) {
    if (_open == conversationId) {
      // Through the switch, so its draft is parked and an undo finds it.
      _switch(ref.read(frontPickedConversationProvider.notifier).startNew);
    }
  }

  /// Takes a change to today into the planning [plan] opens, and settles
  /// the door on the day it resolves — none, when nothing was accepted.
  /// The door is busy the whole time, so a second tap opens no second
  /// planning.
  Future<void> planDay(String doorId, Future<DateTime?> Function() plan) =>
      _doorAction(doorId, (filing) async {
        final day = await plan();
        if (day != null) await filing.markDayPlanned(doorId, day);
      });

  /// Makes a project of an inbox item through the form [create] opens, and
  /// settles the item on the project it resolves — none, when the form was
  /// closed. Busy the whole time, like [planDay].
  Future<void> newProject(
    String doorId,
    Future<String?> Function() create,
  ) => _doorAction(doorId, (filing) async {
    final projectId = await create();
    if (projectId != null) {
      await filing.markProjectCreated(doorId, projectId);
    }
  });

  /// Files the proposal under its task or project — the user's one tap
  /// (decision 1).
  Future<void> fileUnderOwner(String doorId) =>
      _doorAction(doorId, (filing) => filing.fileUnderOwner(doorId));

  /// Says no to what a waiting door offers: a proposal's words go to the
  /// inbox, an inbox item is left where it is.
  Future<void> decline(String doorId) =>
      _doorAction(doorId, (filing) => filing.decline(doorId));

  /// A left door waits again as what it was.
  Future<void> undoDecline(String doorId) =>
      _doorAction(doorId, (filing) => filing.undoDecline(doorId));

  /// Takes back what a door wrote: the entry, note or task.
  Future<void> takeBack(String doorId) =>
      _doorAction(doorId, (filing) => filing.takeBack(doorId));

  /// Makes a task of an inbox item, set up as the user [choices] — with a
  /// coding prompt written for it when [codingPrompt]; whether it was made,
  /// so the surface can say so aloud.
  Future<bool> makeTask(
    String doorId, {
    required FrontTaskChoices choices,
    bool codingPrompt = false,
  }) => _doorAction(
    doorId,
    (filing) => filing.makeTask(
      doorId,
      choices: choices,
      codingPrompt: codingPrompt,
    ),
  );

  /// Saves an inbox item as a note.
  Future<void> saveAsNote(String doorId) =>
      _doorAction(doorId, (filing) => filing.saveAsNote(doorId));

  /// Makes an event of an inbox item.
  Future<void> makeEvent(String doorId) =>
      _doorAction(doorId, (filing) => filing.makeEvent(doorId));

  /// Runs one action on a door: the door is busy meanwhile, the thread is
  /// re-projected after, and a failure is kept on the door until its next
  /// action. A door already busy takes no second tap. Answers whether the
  /// action went through.
  Future<bool> _doorAction(
    String doorId,
    Future<void> Function(FrontFilingService filing) action,
  ) async {
    if (state.busyDoorIds.contains(doorId)) return false;
    state = state.copyWith(
      busyDoorIds: {...state.busyDoorIds, doorId},
      failedDoorIds: {...state.failedDoorIds}..remove(doorId),
    );
    try {
      await action(ref.read(frontFilingServiceProvider));
      return true;
    } catch (_) {
      state = state.copyWith(failedDoorIds: {...state.failedDoorIds, doorId});
      return false;
    } finally {
      _reproject();
      state = state.copyWith(
        busyDoorIds: {...state.busyDoorIds}..remove(doorId),
      );
    }
  }
}
