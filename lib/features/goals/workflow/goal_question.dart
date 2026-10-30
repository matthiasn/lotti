/// The goal agent's own question to the user (ADR 0146).
///
/// Every other word the agent writes into the goal chat answers something the
/// user typed. A question is the one exception: on an automatic wake, after
/// the user said something worth following up, the agent may ask one short
/// question — and raise a banner pointing at it. Both are rationed here rather
/// than in prose: the tool is offered only when [goalQuestionAllowed] holds,
/// so "do not nag" is a fact of the wire, not a hope about the model.
library;

import 'package:clock/clock.dart';
import 'package:lotti/classes/agents/agent_config.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/agents/util/text_utils.dart';
import 'package:lotti/features/goals/workflow/goal_agent_contract.dart';
import 'package:lotti/features/nudges/logic/nudge_private_copy.dart';
import 'package:uuid/uuid.dart';

/// `operationId` prefix marking a chat message as the agent's own question.
///
/// A reply carries the id of the user turn it answers; a reply WITHOUT one is
/// read as a legacy answer to the nearest unanswered user turn. A question
/// answers nothing, so it carries this marker instead — never an id a user
/// turn could have — and the pairing leaves it alone.
const goalQuestionOperationPrefix = 'goal-question:';

String goalQuestionOperationId(String runKey) =>
    '$goalQuestionOperationPrefix$runKey';

bool isGoalQuestionOperationId(String? operationId) =>
    operationId != null && operationId.startsWith(goalQuestionOperationPrefix);

/// Longest question the chat accepts: one short question, not a briefing.
const goalQuestionMaxLength = 280;

/// Provenance key and value marking a banner raised with a question.
const goalNudgeTriggerKey = 'trigger';
const goalNudgeQuestionTrigger = 'question';

/// Provenance key linking a question banner to the chat message it points at.
const goalNudgeQuestionMessageKey = 'questionMessageId';

/// The banner the model asked for with its question: its words, which may
/// name what the user wrote, and how it looks.
typedef GoalQuestionBanner = ({
  String headline,
  String? tagline,
  NudgeTone tone,
  NudgeBannerAnimation animation,
  NudgeBannerAccent accent,
});

/// The words a question's banner shows while the user hides private entries:
/// code-owned and localised, safe wherever the banner is seen (ADR 0147).
typedef GoalQuestionBannerCopy = ({String headline, String cta});

/// One validated `ask_goal_question` call.
class GoalQuestionRequest {
  const GoalQuestionRequest({required this.question, this.banner});

  final String question;

  /// The banner raised with the question, when the model asked for one.
  final GoalQuestionBanner? banner;
}

/// A banner's copy and presets from `create_goal_ad`'s arguments, or the
/// reason it is not one. A question's banner keeps its words apart from its
/// brief — see [persistGoalQuestion].
({NudgeBrief? brief, String? error}) parseGoalNudgeBrief(
  Map<String, dynamic> args, {
  required String toolName,
}) {
  final headline = _trimmed(args['headline']);
  final tone = NudgeTone.values
      .where((value) => value.name == args['tone'])
      .firstOrNull;
  final animation = NudgeBannerAnimation.values
      .where((value) => value.name == args['animation'])
      .firstOrNull;
  if (headline.isEmpty || tone == null || animation == null) {
    return (
      brief: null,
      error:
          'Error: $toolName needs a non-empty headline, tone (one '
          'of ${goalNudgeToneNames.join('|')}) and animation (one of '
          '${goalBannerAnimationNames.join('|')}).',
    );
  }
  final accent =
      NudgeBannerAccent.values
          .where((value) => value.name == args['accent'])
          .firstOrNull ??
      NudgeBannerAccent.calm;
  final tagline = _trimmed(args['tagline']);
  final cta = _trimmed(args['cta']);
  return (
    brief: NudgeBrief(
      headline: headline,
      tone: tone,
      animation: animation,
      accent: accent,
      tagline: tagline.isEmpty ? null : tagline,
      cta: cta.isEmpty ? null : cta,
    ),
    error: null,
  );
}

/// The question in [args], or the reason it was refused.
({GoalQuestionRequest? request, String? error}) parseGoalQuestion(
  Map<String, dynamic> args,
) {
  final question = _trimmed(args['question']);
  if (question.isEmpty) {
    return (
      request: null,
      error: 'Error: ask_goal_question needs a non-empty question.',
    );
  }
  if (question.length > goalQuestionMaxLength) {
    return (
      request: null,
      error:
          'Error: the question is ${question.length} characters; ask one '
          'short question of at most $goalQuestionMaxLength.',
    );
  }
  final rawBanner = args['banner'];
  if (rawBanner == null) {
    return (request: GoalQuestionRequest(question: question), error: null);
  }
  if (rawBanner is! Map<String, dynamic>) {
    return (
      request: null,
      error: 'Error: banner must be an object, or omitted.',
    );
  }
  final headline = _trimmed(rawBanner['headline']);
  final tone = NudgeTone.values
      .where((value) => value.name == rawBanner['tone'])
      .firstOrNull;
  final animation = NudgeBannerAnimation.values
      .where((value) => value.name == rawBanner['animation'])
      .firstOrNull;
  if (headline.isEmpty || tone == null || animation == null) {
    return (
      request: null,
      error:
          'Error: ${GoalAgentToolNames.askGoalQuestion}.banner needs a '
          'non-empty headline, a tone (one of '
          '${goalQuestionBannerToneNames.join('|')}) and an animation (one of '
          '${goalBannerAnimationNames.join('|')}).',
    );
  }
  if (tone == NudgeTone.roast) {
    // A question is an invitation to talk; a roast is for the user who asks.
    return (
      request: null,
      error: 'Error: a question banner never roasts; pick another tone.',
    );
  }
  final accent =
      NudgeBannerAccent.values
          .where((value) => value.name == rawBanner['accent'])
          .firstOrNull ??
      NudgeBannerAccent.calm;
  final tagline = _trimmed(rawBanner['tagline']);
  return (
    request: GoalQuestionRequest(
      question: question,
      banner: (
        headline: headline,
        tagline: tagline.isEmpty ? null : tagline,
        tone: tone,
        animation: animation,
        accent: accent,
      ),
    ),
    error: null,
  );
}

/// The agent's latest question in the goal chat: when it was asked, and
/// whether the user has written anything since.
typedef GoalOpenQuestion = ({DateTime askedAt, bool answered});

/// Whether this wake may ask a question.
///
/// Only on an automatic wake (a chat turn answers instead), only when the user
/// has said something the standing report has not answered yet — the question
/// follows up their words, never a number — and never while the last question
/// waits for an answer, nor twice in one local day.
bool goalQuestionAllowed({
  required bool interactive,
  required int newCheckIns,
  required GoalOpenQuestion? latest,
  DateTime? now,
}) {
  if (interactive || newCheckIns <= 0) return false;
  if (latest == null) return true;
  if (!latest.answered) return false;
  final today = (now ?? clock.now()).toLocal();
  final asked = latest.askedAt.toLocal();
  return !(asked.year == today.year &&
      asked.month == today.month &&
      asked.day == today.day);
}

/// Stable ids of the question a run asks, so a retried wake overwrites its
/// question instead of asking twice.
String goalQuestionMessageId(String agentId, String runKey) => const Uuid().v5(
  Namespace.url.value,
  'lotti://goal-agent/$agentId/$runKey/question',
);

String _goalQuestionPayloadId(String agentId, String runKey) => const Uuid().v5(
  Namespace.url.value,
  'lotti://goal-agent/$agentId/$runKey/question-payload',
);

/// The id of the day's question banner: one per goal, spec and period, the
/// question's own daily ceiling.
String goalQuestionNudgeId({
  required String agentId,
  required String periodKey,
  required String specVersionId,
}) => 'goal_nudge:$agentId:$periodKey:$goalNudgeQuestionTrigger:$specVersionId';

/// Whether [nudge] was raised with a question rather than by the goal's
/// status — the rules that retire and block status banners pass it by.
bool isGoalQuestionNudge(GoalNudgeEntity nudge) =>
    nudge.provenance[goalNudgeTriggerKey] == goalNudgeQuestionTrigger;

/// Writes [request] into the goal chat as the agent's own message, and its
/// banner when [raiseBanner] says one may still be raised. Runs inside the
/// wake's output transaction.
///
/// The message is the reply carrier the chat already renders —
/// `reply_to_user`, kind action — marked by [goalQuestionOperationId] so it
/// is never paired as the answer to a user turn.
Future<void> persistGoalQuestion(
  AgentSyncService syncService, {
  required GoalQuestionRequest request,
  required String agentId,
  required String runKey,
  required String threadId,
  required String periodKey,
  required String specVersionId,
  required DateTime now,
  required Duration bannerLifetime,
  required bool raiseBanner,
  required Set<String> existingNudgeIds,
  required String Function(NudgeBrief brief) briefDigest,
  required GoalQuestionBannerCopy Function() bannerCopy,
}) async {
  final messageId = goalQuestionMessageId(agentId, runKey);
  final payloadId = _goalQuestionPayloadId(agentId, runKey);
  await syncService.upsertEntity(
    AgentDomainEntity.agentMessagePayload(
      id: payloadId,
      agentId: agentId,
      createdAt: now,
      vectorClock: null,
      content: <String, Object?>{
        'text': sanitizeAgentReportText(request.question, stripBareIds: true),
      },
    ),
  );
  await syncService.upsertEntity(
    AgentDomainEntity.agentMessage(
      id: messageId,
      agentId: agentId,
      threadId: threadId,
      kind: AgentMessageKind.action,
      createdAt: now,
      vectorClock: null,
      contentEntryId: payloadId,
      metadata: AgentMessageMetadata(
        runKey: runKey,
        toolName: AgentConversationToolNames.replyToUser,
        operationId: goalQuestionOperationId(runKey),
      ),
    ),
  );

  final banner = request.banner;
  if (banner == null || !raiseBanner) return;
  final nudgeId = goalQuestionNudgeId(
    agentId: agentId,
    periodKey: periodKey,
    specVersionId: specVersionId,
  );
  if (existingNudgeIds.contains(nudgeId)) return;
  // The brief holds words safe anywhere; the model's, which may name what
  // the user wrote, ride in provenance and are shown only while the user
  // shows private entries (`nudgeDisplayBrief`). Whatever reads the brief
  // without knowing that — history, ratings, an alert — shows the safe ones.
  final copy = bannerCopy();
  final brief = NudgeBrief(
    headline: copy.headline,
    cta: copy.cta,
    tone: banner.tone,
    animation: banner.animation,
    accent: banner.accent,
  );
  final privateTagline = banner.tagline;
  await syncService.upsertEntity(
    AgentDomainEntity.goalNudge(
      id: nudgeId,
      agentId: agentId,
      status: NudgeStatus.active,
      brief: brief,
      briefDigest: briefDigest(brief),
      createdAt: now.toUtc(),
      updatedAt: now.toUtc(),
      vectorClock: null,
      runKey: runKey,
      threadId: threadId,
      staleAt: now.toUtc().add(bannerLifetime),
      activatedAt: now.toUtc(),
      // No facts digest: the banner is about what the user said, not the
      // numbers, so new evidence does not make it stale (Phase A's sweep
      // reads the digest) — it ends at its deadline or when they answer.
      provenance: {
        'specVersionId': specVersionId,
        goalNudgeTriggerKey: goalNudgeQuestionTrigger,
        goalNudgeQuestionMessageKey: messageId,
        nudgePrivateHeadlineKey: sanitizeAgentReportText(
          banner.headline,
          stripBareIds: true,
        ),
        if (privateTagline != null)
          nudgePrivateTaglineKey: sanitizeAgentReportText(
            privateTagline,
            stripBareIds: true,
          ),
      },
    ),
  );
}

String _trimmed(Object? value) => value is String ? value.trim() : '';
