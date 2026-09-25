part of 'goal_chat_service_test.dart';

// Model conformance with `specs/tla/GoalChatReply.tla`: one message typed on
// the author device and synced to a peer. Each device is a real agent
// database, sync service, wake orchestrator and scheduled-wake manager
// (`WakeDevice`) whose pre-scan maintenance is the real
// `GoalChatService.restoreOldestPendingMessage`; the author sends through
// the real `GoalChatService.sendMessage`; every wake runs the real goal
// router (`goalAgentWakeRunnersProvider`), which hands a message it has to
// answer to a scripted workflow whose run the trace commits or fails. The
// recovery record's lease is the real one, not taken as given as the model
// does.
//
// Time moves in minutes. The model's unit is ten of them: the grace is three
// (`goalChatRecoveryGrace`, thirty minutes) and a run commits within one (the
// ten-minute run cap). Sync delivers to a running device within a minute,
// inside the model's bound and below half the lease's settle.
// The checked configurations have no crash and no device paused past the
// run cap; neither has this trace (the README's residuals).

enum _ChatOp { tick, deliver, commit, fail, poll, die }

class _ChatStep {
  const _ChatStep(this.op, this.device, this.arg);

  factory _ChatStep.decode(int code) {
    const weighted = [
      _ChatOp.tick,
      _ChatOp.tick,
      _ChatOp.tick,
      _ChatOp.deliver,
      _ChatOp.deliver,
      _ChatOp.commit,
      _ChatOp.fail,
      _ChatOp.fail,
      _ChatOp.poll,
      _ChatOp.poll,
      _ChatOp.poll,
      _ChatOp.die,
    ];
    return _ChatStep(
      weighted[code % weighted.length],
      (code ~/ weighted.length) % 2,
      code ~/ (weighted.length * 2),
    );
  }

  final _ChatOp op;
  final int device;

  /// Picks the message to deliver, the run, or how many minutes pass.
  final int arg;

  @override
  String toString() => '${op.name}(d$device, $arg)';
}

extension _AnyChatTrace on glados.Any {
  glados.Generator<List<_ChatStep>> get chatTrace => glados.ListAnys(this)
      .listWithLengthInRange(1, 30, glados.IntAnys(this).intInRange(0, 12 * 32))
      .map((codes) => [for (final code in codes) _ChatStep.decode(code)]);
}

/// A goal wake that answers a message: held until the trace commits it —
/// writing the reply as `GoalAgentWorkflow` does — or fails it.
typedef _ChatRun = ({
  WakeDevice device,
  String runKey,
  String threadId,
  String messageId,
  DateTime startedAt,
  Completer<WakeResult> result,
});

class _ScriptedGoalWorkflow extends Fake implements GoalAgentWorkflow {
  _ScriptedGoalWorkflow(this.device, this.running);

  final WakeDevice device;
  final List<_ChatRun> running;

  @override
  Future<WakeResult> executeUserMessage({
    required AgentIdentityEntity agentIdentity,
    required String runKey,
    required Set<String> triggerTokens,
    required String threadId,
    required String messageId,
  }) {
    final result = Completer<WakeResult>();
    running.add((
      device: device,
      runKey: runKey,
      threadId: threadId,
      messageId: messageId,
      startedAt: clock.now(),
      result: result,
    ));
    return result.future;
  }
}

const _chatGoalId = 'goal-chat';
final _chatStart = DateTime(2026, 8, 8, 9);

class _ChatBench {
  _ChatBench(this.async) {
    for (final host in ['hA', 'hB']) {
      devices.add(
        WakeDevice(
          network.join(host),
          holdSteps: false,
          leaseDuration: const Duration(minutes: 30),
          requiresLease: (record) =>
              isGoalChatRecoveryWorkspace(record.workspaceKey),
          beforeCheck: (device) =>
              _chatService(device).restoreOldestPendingMessage(_chatGoalId),
          executor: _executor,
        ),
      );
    }
  }

  final FakeAsync async;
  final network = ReplicaNetwork();
  final devices = <WakeDevice>[];
  final running = <_ChatRun>[];
  final _containers = <ProviderContainer>[];

  /// Ghost of the model's `replies`: replies committed, on any device.
  int replies = 0;
  int fails = 0;
  int deaths = 0;

  static const _runCap = Duration(minutes: 10);

  /// Within the model's unit, and short enough for the lease this trace
  /// runs for real: its settle (three minutes) must exceed twice the delay,
  /// or crossing claims both survive (`ScheduledWakeLease.tla`).
  static const _maxDelay = Duration(minutes: 1);

  GoalChatService _chatService(WakeDevice device) {
    final notifications = MockUpdateNotifications();
    when(() => notifications.notifyUiOnly(any())).thenReturn(null);
    return GoalChatService(
      repository: device.replica.repository,
      syncService: device.replica.syncService,
      orchestrator: device.orchestrator,
      notifications: notifications,
    );
  }

  /// The wiring's executor (`wireWakeExecutor`): the identity's kind picks
  /// the runner — the real goal router — and a failed result fails the run.
  WakeExecutor _executor(WakeDevice device) {
    final container = ProviderContainer(
      overrides: [
        goalChatHistoryServiceProvider.overrideWithValue(
          GoalChatHistoryService(device.replica.repository),
        ),
        goalAgentWorkflowProvider.overrideWithValue(
          _ScriptedGoalWorkflow(device, running),
        ),
      ],
    );
    _containers.add(container);
    return (agentId, runKey, triggers, threadId) async {
      final identity = await device.replica.repository.getEntity(agentId);
      if (identity is! AgentIdentityEntity) return null;
      final runner = container.read(
        goalAgentWakeRunnersProvider,
      )[identity.kind]!;
      final result = await runner(
        agentIdentity: identity,
        runKey: runKey,
        triggerTokens: triggers,
        threadId: threadId,
      );
      if (!result.success) {
        throw WakeFailedException(
          kind: identity.kind,
          reason: result.error ?? 'wake failed',
        );
      }
      return const {};
    };
  }

  void settle() {
    for (var i = 0; i < 4; i++) {
      async
        ..flushMicrotasks()
        ..elapse(Duration.zero);
    }
  }

  /// Both devices hold the goal; the author types the message.
  void setUp() {
    final identity = AgentDomainEntity.agent(
      id: _chatGoalId,
      agentId: _chatGoalId,
      kind: AgentKinds.goalAgent,
      displayName: 'Goal',
      lifecycle: AgentLifecycle.active,
      mode: AgentInteractionMode.autonomous,
      allowedCategoryIds: const {},
      currentStateId: '$_chatGoalId:state',
      config: const AgentConfig(),
      createdAt: DateTime(2026, 8),
      updatedAt: DateTime(2026, 8),
      vectorClock: const VectorClock({'seed': 1}),
    );
    for (final device in devices) {
      unawaited(device.replica.repository.upsertEntity(identity));
    }
    settle();
    unawaited(
      _chatService(devices.first)
          .sendMessage(agentId: _chatGoalId, text: 'How am I doing?')
          // The UI shows a failed turn; recovery is the record's business.
          .catchError((Object _) {}),
    );
    settle();
  }

  void commit(_ChatRun run) {
    running.remove(run);
    replies++;
    const agentId = _chatGoalId;
    final now = clock.now();
    final payloadId = '${goalAgentReplyMessageId(agentId, run.runKey)}-body';
    final sync = run.device.replica.syncService;
    unawaited(
      sync
          .upsertEntity(
            AgentDomainEntity.agentMessagePayload(
              id: payloadId,
              agentId: agentId,
              createdAt: now,
              vectorClock: null,
              content: const <String, Object?>{'text': 'On track.'},
            ),
          )
          .then(
            (_) => sync.upsertEntity(
              AgentDomainEntity.agentMessage(
                id: goalAgentReplyMessageId(agentId, run.runKey),
                agentId: agentId,
                threadId: run.threadId,
                kind: AgentMessageKind.action,
                createdAt: now,
                vectorClock: null,
                contentEntryId: payloadId,
                metadata: AgentMessageMetadata(
                  runKey: run.runKey,
                  toolName: AgentConversationToolNames.replyToUser,
                  operationId: run.messageId,
                ),
              ),
            ),
          )
          .then((_) => run.result.complete(const WakeResult(success: true))),
    );
    settle();
  }

  List<_ChatRun> _runsOn(WakeDevice device) =>
      running.where((run) => run.device == device).toList();

  void deliver(WakeDevice device, int index) {
    unawaited(device.replica.receive(index));
    settle();
  }

  /// One minute, as the model's `Tick` allows it: a run is past the run cap
  /// only committed, and a write waits at most the sync delay for a running
  /// device.
  void minute() {
    final now = clock.now();
    for (final run in [...running]) {
      if (!run.startedAt.add(_runCap).isAfter(now)) commit(run);
    }
    for (final device in devices) {
      if (device.status != DeviceStatus.up) continue;
      for (final index in network.pendingFor(device.replica)) {
        if (!network.sentAt[index].add(_maxDelay).isAfter(now)) {
          deliver(device, index);
        }
      }
    }
    async.elapse(const Duration(minutes: 1));
    settle();
  }

  void run(_ChatStep step) {
    final device = devices[step.device];
    final up = device.status == DeviceStatus.up;
    switch (step.op) {
      case _ChatOp.tick:
        for (var i = 0; i <= step.arg % 10; i++) {
          minute();
        }
      case _ChatOp.deliver:
        final pending = network.pendingFor(device.replica);
        if (up && pending.isNotEmpty) {
          deliver(device, pending[step.arg % pending.length]);
        }
      case _ChatOp.commit:
        final mine = _runsOn(device);
        if (up && mine.isNotEmpty) commit(mine[step.arg % mine.length]);
      case _ChatOp.fail:
        final mine = _runsOn(device);
        if (!up || mine.isEmpty || fails >= 1) break;
        fails++;
        final run = mine[step.arg % mine.length];
        running.remove(run);
        run.result.complete(
          const WakeResult(success: false, error: 'inference failed'),
        );
      case _ChatOp.poll:
        if (up) device.manager.requestCheck();
      case _ChatOp.die:
        if (!up || deaths >= 1) break;
        deaths++;
        device.die();
        running.removeWhere((run) => run.device == device);
    }
    settle();
  }

  void check(Object trace) {
    expect(replies, lessThanOrEqualTo(1), reason: 'AtMostOneReply: $trace');
  }

  /// Every write delivered, every run committed, for four hours — the
  /// hourly scans included. While a device lives, the message is answered
  /// (`Answered`).
  void drain(Object trace) {
    for (var i = 0; i < 240; i++) {
      for (final device in devices) {
        if (device.status != DeviceStatus.up) continue;
        for (final index in network.pendingFor(device.replica)) {
          deliver(device, index);
        }
      }
      [...running].forEach(commit);
      async.elapse(const Duration(minutes: 1));
      settle();
      check(trace);
    }
    expect(replies, 1, reason: 'Answered: $trace');
  }

  void close() {
    for (final device in devices) {
      if (device.status != DeviceStatus.dead) device.die();
    }
    for (final container in _containers) {
      container.dispose();
    }
    unawaited(network.close());
    settle();
  }
}

void _registerChatModelConformance() {
  group('model conformance with specs/tla/GoalChatReply.tla', () {
    glados.Glados(
      glados.any.chatTrace,
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'generated deliveries, commits, a failed run and a death answer the '
      'message exactly once',
      (trace) {
        fakeAsync((async) {
          withClock(async.getClock(_chatStart), () {
            final bench = _ChatBench(async);
            try {
              bench.setUp();
              for (final step in trace) {
                bench
                  ..run(step)
                  ..check(trace);
              }
              bench.drain(trace);
            } finally {
              bench.close();
            }
          });
        });
      },
      tags: 'glados',
    );
  });
}
