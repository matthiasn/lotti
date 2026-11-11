import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_chat_projection.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:lotti/features/front_agent/model/front_logged_time_chart.dart';
import 'package:lotti/features/front_agent/model/front_pull_requests.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';
import 'package:lotti/features/front_agent/state/front_chat_thread_provider.dart';
import 'package:lotti/features/front_agent/state/front_stage_pointing.dart';
import 'package:lotti/features/front_agent/state/front_voice_providers.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/tts/model/tts_playback_state.dart';
import 'package:lotti/features/tts/state/tts_playback_controller.dart';

import '../../tts/test_utils.dart';

void main() {
  final at = DateTime(2026, 11, 7, 9);

  AgentChatMessage message(
    String id,
    AgentChatRole role,
    String text, {
    int second = 0,
  }) => AgentChatMessage(
    id: id,
    role: role,
    text: text,
    createdAt: at.add(Duration(seconds: second)),
  );

  const list = 'Two are due today:';
  const oneLink = 'Only [Count the hatchlings](lotti://task/t1) is due.';

  /// The surface of a reply that lists two tasks under her words.
  FrontReplySurface listed(String id) => FrontReplySurface.compose(
    surfaceId: id,
    components: const [
      {'component': 'Text', 'text': list},
      {
        'component': 'TaskCards',
        'items': [
          {'kind': 'task', 'id': 't1', 'title': 'Count the hatchlings'},
          {'kind': 'task', 'id': 't2', 'title': 'Check the nest cameras'},
        ],
      },
    ],
  );

  /// A thread whose replies of [list] draw their cards; other replies draw
  /// only their words.
  FrontChatThread thread(List<AgentChatMessage> messages) => FrontChatThread(
    messages: messages,
    surfacesByMessageId: {
      for (final m in messages)
        if (m.text == list) m.id: listed(m.id),
    },
  );

  /// The surface of reply a1 charting [chart] under its words.
  Map<String, FrontReplySurface> charting({
    FrontLoggedTimeChart? loggedTime,
    FrontPullRequestChart? pullRequests,
  }) => {
    'a1': FrontReplySurface.compose(
      surfaceId: 'a1',
      components: const [
        {'component': 'Text', 'text': 'Here.'},
        {'component': 'LoggedTimeChart'},
        {'component': 'PullRequestChart'},
      ],
      loggedTime: loggedTime,
      pullRequests: pullRequests,
    ),
  };

  group('frontLatestReplyHasVisual', () {
    test('her reply to the latest turn lists tasks', () {
      expect(
        frontLatestReplyHasVisual(
          thread([
            message('u1', AgentChatRole.user, 'What is due?'),
            message('a1', AgentChatRole.agent, list, second: 1),
          ]),
        ),
        isTrue,
      );
    });

    test('her reply to the latest turn charts logged time; an earlier '
        "reply's chart is not the one she is saying", () {
      const chart = FrontLoggedTimeChart(
        range: InsightsRange(startDay: 20396, endDayExclusive: 20401),
        categoryIds: {},
      );
      final turns = [
        message('u1', AgentChatRole.user, 'Time this week?'),
        message('a1', AgentChatRole.agent, '12h this week.', second: 1),
      ];
      expect(
        frontLatestReplyHasVisual(
          FrontChatThread(
            messages: turns,
            surfacesByMessageId: charting(loggedTime: chart),
          ),
        ),
        isTrue,
      );
      expect(
        frontLatestReplyHasVisual(
          FrontChatThread(
            messages: [
              ...turns,
              message('u2', AgentChatRole.user, 'Thanks', second: 2),
              message('a2', AgentChatRole.agent, 'Any time.', second: 3),
            ],
            surfacesByMessageId: charting(loggedTime: chart),
          ),
        ),
        isFalse,
      );
    });

    test('her reply to the latest turn charts pull requests', () {
      const chart = FrontPullRequestChart(
        range: InsightsRange(startDay: 20396, endDayExclusive: 20410),
        categoryIds: {},
      );
      final turns = [
        message('u1', AgentChatRole.user, 'PRs in two weeks?'),
        message('a1', AgentChatRole.agent, 'You created 12.', second: 1),
      ];
      expect(
        frontLatestReplyHasVisual(
          FrontChatThread(
            messages: turns,
            surfacesByMessageId: charting(pullRequests: chart),
          ),
        ),
        isTrue,
      );
      expect(frontLatestReplyHasVisual(thread(turns)), isFalse);
    });

    test('a single task link is not a list', () {
      expect(
        frontLatestReplyHasVisual(
          thread([
            message('u1', AgentChatRole.user, 'What is due?'),
            message('a1', AgentChatRole.agent, oneLink, second: 1),
          ]),
        ),
        isFalse,
      );
    });

    test('a list in an earlier reply is not the one she is saying', () {
      expect(
        frontLatestReplyHasVisual(
          thread([
            message('u1', AgentChatRole.user, 'What is due?'),
            message('a1', AgentChatRole.agent, list, second: 1),
            message('u2', AgentChatRole.user, 'Thanks', second: 2),
            message('a2', AgentChatRole.agent, 'Any time.', second: 3),
          ]),
        ),
        isFalse,
      );
    });

    test('no turn, or no reply yet, lists nothing', () {
      expect(frontLatestReplyHasVisual(FrontChatThread.empty), isFalse);
      expect(
        frontLatestReplyHasVisual(
          thread([
            message('a0', AgentChatRole.agent, list),
            message('u1', AgentChatRole.user, 'What is due?', second: 1),
          ]),
        ),
        isFalse,
      );
    });
  });

  test('replies to tap alone are nothing to point at', () {
    expect(
      frontLatestReplyHasVisual(
        FrontChatThread(
          messages: [
            message('u1', AgentChatRole.user, 'Time?'),
            message('a1', AgentChatRole.agent, 'Break it down?', second: 1),
          ],
          surfacesByMessageId: {
            'a1': FrontReplySurface.compose(
              surfaceId: 'a1',
              components: const [
                {'component': 'Text', 'text': 'Break it down?'},
                {
                  'component': 'QuickReplies',
                  'options': ['Yes'],
                },
              ],
            ),
          },
        ),
      ),
      isFalse,
    );
  });

  group('frontStagePointsProvider', () {
    /// Whether she points in conversation c-1 once its thread has loaded,
    /// with the voice at [status] for [sourceId] and [reply] her answer.
    Future<bool> points({
      required TtsPlaybackStatus status,
      String sourceId = 'front-chat:c-1',
      String reply = list,
    }) async {
      final container = ProviderContainer(
        overrides: [
          ttsPlaybackControllerProvider.overrideWith(
            () => FixedTtsPlayback(
              TtsPlaybackState(status: status, sourceId: sourceId),
            ),
          ),
          frontChatThreadProvider.overrideWith(
            (ref) async => thread([
              message('u1', AgentChatRole.user, 'What is due?'),
              message('a1', AgentChatRole.agent, reply, second: 1),
            ]),
          ),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(frontStagePointsProvider('c-1'), (_, _) {});
      addTearDown(sub.close);
      await container.read(frontChatThreadProvider.future);
      return sub.read();
    }

    test('points while her voice says a reply that lists tasks', () async {
      expect(frontVoiceSourceId('c-1'), 'front-chat:c-1');
      expect(await points(status: TtsPlaybackStatus.playing), isTrue);
    });

    test('not while she says a reply without a list', () async {
      expect(
        await points(status: TtsPlaybackStatus.playing, reply: oneLink),
        isFalse,
      );
    });

    test('never while she prepares, is silent, or speaks elsewhere', () async {
      expect(await points(status: TtsPlaybackStatus.synthesizing), isFalse);
      expect(await points(status: TtsPlaybackStatus.idle), isFalse);
      expect(
        await points(
          status: TtsPlaybackStatus.playing,
          sourceId: 'front-chat:c-2',
        ),
        isFalse,
      );
    });
  });
}
