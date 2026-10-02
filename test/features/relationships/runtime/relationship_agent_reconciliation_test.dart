import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/relationship_data.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/relationships/runtime/relationship_agent_reconciliation.dart';

void main() {
  final base = DateTime(2026, 9);
  DateTime at(int hour) => base.add(Duration(hours: hour));

  RelationshipData person({bool important = true, DateTime? markedAt}) =>
      RelationshipData(
        title: 'Anna',
        important: important,
        importantSince: markedAt,
        status: RelationshipStatus.active(
          id: 'status-1',
          createdAt: base,
          utcOffset: 0,
        ),
      );

  AgentIdentityEntity agent({
    AgentLifecycle lifecycle = AgentLifecycle.active,
    DateTime? stoppedAt,
    AgentLifecycle? stoppedTo,
    DateTime? resumedAt,
    DateTime? lifecycleAt,
  }) =>
      AgentDomainEntity.agent(
            id: 'relationship_agent:person-1',
            agentId: 'relationship_agent:person-1',
            kind: 'relationship_agent',
            displayName: 'Anna',
            lifecycle: lifecycle,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'state',
            config: const AgentConfig(),
            createdAt: base,
            updatedAt: base,
            vectorClock: null,
            lifecycleUpdatedAt: lifecycleAt,
            userStoppedAt: stoppedAt,
            userStopLifecycle: stoppedTo,
            userResumedAt: resumedAt,
          )
          as AgentIdentityEntity;

  group('worked examples', () {
    test('an important person with no agent gets one', () {
      expect(
        reconcileRelationshipAgent(
          person: person(markedAt: at(1)),
          identity: null,
          deletedAt: null,
        ),
        RelationshipAgentReconciliation.create,
      );
    });

    test('an agent the system destroyed comes back — the reaper that once '
        'reaped a person not yet synced left exactly this', () {
      expect(
        reconcileRelationshipAgent(
          person: person(markedAt: at(1)),
          identity: agent(lifecycle: AgentLifecycle.destroyed),
          deletedAt: null,
        ),
        RelationshipAgentReconciliation.activate,
      );
    });

    test("the user's destroy after the mark keeps the agent destroyed", () {
      expect(
        reconcileRelationshipAgent(
          person: person(markedAt: at(1)),
          identity: agent(
            lifecycle: AgentLifecycle.destroyed,
            stoppedAt: at(2),
            stoppedTo: AgentLifecycle.destroyed,
          ),
          deletedAt: null,
        ),
        RelationshipAgentReconciliation.none,
      );
    });

    test('marking the person again after that brings it back', () {
      expect(
        reconcileRelationshipAgent(
          person: person(markedAt: at(3)),
          identity: agent(
            lifecycle: AgentLifecycle.destroyed,
            stoppedAt: at(2),
            stoppedTo: AgentLifecycle.destroyed,
          ),
          deletedAt: null,
        ),
        RelationshipAgentReconciliation.activate,
      );
    });

    test('a resume after the stop counts as asking again', () {
      expect(
        reconcileRelationshipAgent(
          person: person(markedAt: at(1)),
          identity: agent(
            lifecycle: AgentLifecycle.dormant,
            stoppedAt: at(2),
            stoppedTo: AgentLifecycle.dormant,
            resumedAt: at(3),
          ),
          deletedAt: null,
        ),
        RelationshipAgentReconciliation.activate,
      );
    });

    test('a person marked before the stamp existed reads as asked at the '
        'beginning: any recorded stop wins', () {
      expect(
        reconcileRelationshipAgent(
          person: person(),
          identity: agent(stoppedAt: at(0), stoppedTo: AgentLifecycle.dormant),
          deletedAt: null,
        ),
        RelationshipAgentReconciliation.pause,
      );
    });

    test(
      "a stop recorded with a lifecycle that is not a stop — a writer's bug "
      '— is not acted on: the pass neither creates nor stops anything',
      () {
        expect(
          reconcileRelationshipAgent(
            person: person(markedAt: at(1)),
            identity: agent(
              stoppedAt: at(2),
              stoppedTo: AgentLifecycle.created,
            ),
            deletedAt: null,
          ),
          RelationshipAgentReconciliation.none,
        );
      },
    );

    test("an unimportant person's agent is left as it is", () {
      expect(
        reconcileRelationshipAgent(
          person: person(important: false, markedAt: at(1)),
          identity: agent(lifecycle: AgentLifecycle.destroyed),
          deletedAt: null,
        ),
        RelationshipAgentReconciliation.none,
      );
    });

    test('a delete older than the mark is created again; a newer one, or '
        'one with no mark to compare, is not', () {
      RelationshipAgentReconciliation decide(DateTime? markedAt) =>
          reconcileRelationshipAgent(
            person: person(markedAt: markedAt),
            identity: null,
            deletedAt: at(2),
          );
      expect(decide(at(3)), RelationshipAgentReconciliation.create);
      expect(decide(at(1)), RelationshipAgentReconciliation.none);
      expect(decide(null), RelationshipAgentReconciliation.none);
    });

    test('an open conflict holds back creation and activation but not a '
        'stop, judged by the newest mark it holds', () {
      final conflict = [person(markedAt: at(1))];
      expect(
        reconcileRelationshipAgent(
          person: person(markedAt: at(1)),
          identity: null,
          deletedAt: null,
          conflicting: conflict,
        ),
        RelationshipAgentReconciliation.none,
      );
      expect(
        reconcileRelationshipAgent(
          person: person(markedAt: at(1)),
          identity: agent(lifecycle: AgentLifecycle.destroyed),
          deletedAt: null,
          conflicting: conflict,
        ),
        RelationshipAgentReconciliation.none,
      );
      expect(
        reconcileRelationshipAgent(
          person: person(markedAt: at(1)),
          identity: agent(stoppedAt: at(2), stoppedTo: AgentLifecycle.dormant),
          deletedAt: null,
          conflicting: conflict,
        ),
        RelationshipAgentReconciliation.pause,
      );
      // A conflicting version marked after the stop outweighs it.
      expect(
        reconcileRelationshipAgent(
          person: person(markedAt: at(1)),
          identity: agent(stoppedAt: at(2), stoppedTo: AgentLifecycle.dormant),
          deletedAt: null,
          conflicting: [person(markedAt: at(3))],
        ),
        RelationshipAgentReconciliation.none,
      );
    });
  });

  group(
    'markStampAfter — a mark lands past every decision the device holds',
    () {
      final now = at(5);
      const tick = Duration(microseconds: 1);

      test('nothing held, or nothing the clock has not passed: the clock', () {
        expect(markStampAfter(now, identity: null, deletedAt: null), now);
        expect(
          markStampAfter(
            now,
            identity: agent(
              stoppedAt: at(1),
              resumedAt: at(2),
              lifecycleAt: at(3),
            ),
            deletedAt: at(3),
            previousMark: at(4),
          ),
          now,
        );
      });

      test('a decision stamped ahead of the clock: a microsecond past it', () {
        final cases = <String, DateTime>{
          'stop': markStampAfter(
            now,
            identity: agent(stoppedAt: at(9)),
            deletedAt: null,
          ),
          'resume': markStampAfter(
            now,
            identity: agent(resumedAt: at(9)),
            deletedAt: null,
          ),
          'lifecycle': markStampAfter(
            now,
            identity: agent(lifecycleAt: at(9)),
            deletedAt: null,
          ),
          'delete': markStampAfter(now, identity: null, deletedAt: at(9)),
          'previous mark': markStampAfter(
            now,
            identity: null,
            deletedAt: null,
            previousMark: at(9),
          ),
        };
        for (final MapEntry(key: name, value: stamp) in cases.entries) {
          expect(stamp, at(9).add(tick), reason: name);
        }
      });

      test('the latest of several ahead of the clock decides', () {
        expect(
          markStampAfter(
            now,
            identity: agent(stoppedAt: at(7), resumedAt: at(8)),
            deletedAt: at(9),
            previousMark: at(6),
          ),
          at(9).add(tick),
        );
      });

      test(
        'the stop arrived from a device whose clock runs ahead; marking the '
        'person again here brings the agent back, where a plain clock stamp '
        'would leave it stopped until this clock caught up',
        () {
          final stopped = agent(
            lifecycle: AgentLifecycle.destroyed,
            stoppedAt: at(9),
            stoppedTo: AgentLifecycle.destroyed,
          );
          // The bug the stamp prevents: the mark reads as older than the stop.
          expect(
            reconcileRelationshipAgent(
              person: person(markedAt: now),
              identity: stopped,
              deletedAt: null,
            ),
            RelationshipAgentReconciliation.none,
          );
          expect(
            reconcileRelationshipAgent(
              person: person(
                markedAt: markStampAfter(
                  now,
                  identity: stopped,
                  deletedAt: null,
                ),
              ),
              identity: stopped,
              deletedAt: null,
            ),
            RelationshipAgentReconciliation.activate,
          );
        },
      );

      test(
        "over this device's delete, the new mark creates the agent again",
        () {
          expect(
            reconcileRelationshipAgent(
              person: person(
                markedAt: markStampAfter(now, identity: null, deletedAt: at(9)),
              ),
              identity: null,
              deletedAt: at(9),
            ),
            RelationshipAgentReconciliation.create,
          );
        },
      );

      glados.Glados3<int, int, int>(
        glados.any.intInRange(-1, 12),
        glados.any.intInRange(-1, 12),
        glados.any.intInRange(-1, 12),
      ).test(
        'never before the clock, and after every stamp it was given',
        (int stopHour, int deleteHour, int markHour) {
          DateTime? stamp(int hour) => hour < 0 ? null : at(hour);
          // The resume and the lifecycle stamp share the stop's hour: every
          // identity stamp is held to the same bound.
          final held = [stamp(stopHour), stamp(deleteHour), stamp(markHour)];
          final stamped = markStampAfter(
            now,
            identity: agent(
              stoppedAt: stamp(stopHour),
              resumedAt: stamp(stopHour),
              lifecycleAt: stamp(stopHour),
            ),
            deletedAt: stamp(deleteHour),
            previousMark: stamp(markHour),
          );
          expect(stamped.isBefore(now), isFalse);
          for (final decision in held.whereType<DateTime>()) {
            expect(stamped.isAfter(decision), isTrue);
          }
        },
        tags: 'glados',
      );
    },
  );

  group('properties', () {
    const lifecycles = [
      AgentLifecycle.active,
      AgentLifecycle.dormant,
      AgentLifecycle.destroyed,
    ];
    const stops = [AgentLifecycle.dormant, AgentLifecycle.destroyed];
    // -1 is "no stamp"; 0..5 are hours.
    DateTime? stamp(int hour) => hour < 0 ? null : at(hour);

    AgentLifecycle apply(
      RelationshipAgentReconciliation decision,
      AgentLifecycle current,
    ) => switch (decision) {
      RelationshipAgentReconciliation.none => current,
      RelationshipAgentReconciliation.create ||
      RelationshipAgentReconciliation.activate => AgentLifecycle.active,
      RelationshipAgentReconciliation.pause => AgentLifecycle.dormant,
      RelationshipAgentReconciliation.destroy => AgentLifecycle.destroyed,
    };

    glados.Glados3(
      glados.any.list(glados.any.intInRange(-1, 6)),
      glados.any.intInRange(0, 3),
      glados.any.bool,
    ).test(
      "the user's latest word wins, and a second pass changes nothing",
      (stamps, lifecycleIndex, important) {
        // stamps: mark, stop, resume, conflict mark (padded with "none").
        final s = [...stamps, -1, -1, -1, -1];
        final markedAt = stamp(s[0]);
        final stoppedAt = stamp(s[1]);
        final resumedAt = stamp(s[2]);
        final conflicting = s[3] < 0
            ? const <RelationshipData>[]
            : [person(important: important, markedAt: stamp(s[3]))];
        final stoppedTo = stops[s[1].abs() % 2];
        final current = lifecycles[lifecycleIndex];
        final holder = agent(
          lifecycle: current,
          stoppedAt: stoppedAt,
          stoppedTo: stoppedTo,
          resumedAt: resumedAt,
        );
        final who = person(important: important, markedAt: markedAt);
        final decision = reconcileRelationshipAgent(
          person: who,
          identity: holder,
          deletedAt: null,
          conflicting: conflicting,
        );
        final after = apply(decision, current);
        final asks = [
          markedAt,
          resumedAt,
          ...conflicting.map(
            (c) => c.importantSince,
          ),
        ].whereType<DateTime>();
        final stopIsLatest = stoppedAt != null && asks.every(stoppedAt.isAfter);
        final reason =
            'mark $markedAt stop $stoppedAt->$stoppedTo resume $resumedAt '
            'conflict ${conflicting.isNotEmpty} important $important '
            'from $current: $decision';

        if (stopIsLatest) {
          expect(after, stoppedTo, reason: reason);
        } else if (important && conflicting.isEmpty) {
          expect(after, AgentLifecycle.active, reason: reason);
        } else {
          // Nothing asks for a change the pass may make: it only ever
          // moves toward a stop the user made last.
          expect(
            decision,
            anyOf(
              RelationshipAgentReconciliation.none,
              RelationshipAgentReconciliation.pause,
              RelationshipAgentReconciliation.destroy,
            ),
            reason: reason,
          );
        }
        expect(
          reconcileRelationshipAgent(
            person: who,
            identity: holder.copyWith(lifecycle: after),
            deletedAt: null,
            conflicting: conflicting,
          ),
          RelationshipAgentReconciliation.none,
          reason: 'second pass after $reason',
        );
      },
      tags: 'glados',
    );

    glados.Glados2(
      glados.any.intInRange(0, 3),
      glados.any.intInRange(-1, 6),
    ).test(
      'an open conflict never creates or activates',
      (lifecycleIndex, markHour) {
        final decisions = [
          reconcileRelationshipAgent(
            person: person(markedAt: stamp(markHour)),
            identity: agent(lifecycle: lifecycles[lifecycleIndex]),
            deletedAt: null,
            conflicting: [person(markedAt: stamp(markHour))],
          ),
          reconcileRelationshipAgent(
            person: person(markedAt: stamp(markHour)),
            identity: null,
            deletedAt: null,
            conflicting: [person()],
          ),
        ];
        for (final decision in decisions) {
          expect(
            decision,
            isNot(
              anyOf(
                RelationshipAgentReconciliation.create,
                RelationshipAgentReconciliation.activate,
              ),
            ),
          );
        }
      },
      tags: 'glados',
    );
  });
}
