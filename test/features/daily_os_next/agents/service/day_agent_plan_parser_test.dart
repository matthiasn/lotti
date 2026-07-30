import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_service.dart'
    show DayAgentCaptureException;
import 'package:lotti/features/daily_os_next/agents/service/day_agent_plan_parser.dart';

void main() {
  final day = DateTime(2026, 3, 16);

  Map<String, dynamic> rawBlock({
    String categoryId = 'cat-1',
    String title = 'Deep work',
    int startHour = 9,
    int endHour = 10,
    String? reason = 'morning focus',
    String? taskId,
    String? type,
  }) {
    return <String, dynamic>{
      'categoryId': categoryId,
      'title': title,
      'start': DateTime(2026, 3, 16, startHour).toIso8601String(),
      'end': DateTime(2026, 3, 16, endHour).toIso8601String(),
      'reason': ?reason,
      'taskId': ?taskId,
      'type': ?type,
    };
  }

  PlannedBlock parse(
    Map<String, dynamic>? raw, {
    Set<String> allowedCategoryIds = const {'cat-1'},
    Map<String, String?> decidedTaskIds = const {},
    Map<String, String?> allowedExistingTaskIds = const {},
    DateTime? earliestDraftStart,
    Map<String, PlannedBlock> baselineBlocks = const {},
  }) {
    return parsePlannedBlock(
      raw: raw,
      day: day,
      allowedCategoryIds: allowedCategoryIds,
      decidedTaskIds: decidedTaskIds,
      allowedExistingTaskIds: allowedExistingTaskIds,
      earliestDraftStart: earliestDraftStart,
      baselineBlocks: baselineBlocks,
    );
  }

  group('parsePlannedBlock', () {
    test('parses a valid ai block with reason and generates an id', () {
      final block = parse(rawBlock());

      expect(block.categoryId, 'cat-1');
      expect(block.title, 'Deep work');
      expect(block.type, PlannedBlockType.ai);
      expect(block.reason, 'morning focus');
      expect(block.id, isNotEmpty);
      expect(block.startTime, DateTime(2026, 3, 16, 9));
      expect(block.endTime, DateTime(2026, 3, 16, 10));
    });

    test('rejects non-map input, unknown category, and inverted times', () {
      expect(
        () => parsePlannedBlock(
          raw: 'nope',
          day: day,
          allowedCategoryIds: const {},
          decidedTaskIds: const <String, String?>{},
          allowedExistingTaskIds: const <String, String?>{},
        ),
        throwsA(isA<DayAgentCaptureException>()),
      );
      expect(
        () => parse(rawBlock(categoryId: 'unknown')),
        throwsA(isA<DayAgentCaptureException>()),
      );
      expect(
        () => parse(rawBlock(startHour: 11)),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    test('rejects blocks outside the day window', () {
      final raw = rawBlock()
        ..['end'] = DateTime(2026, 3, 17, 1).toIso8601String();
      expect(() => parse(raw), throwsA(isA<DayAgentCaptureException>()));
    });

    test('rejects ai blocks without a reason', () {
      expect(
        () => parse(rawBlock(reason: null)),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });

    group('committed blocks assert user approval', () {
      test('rejects a freshly invented committed block', () {
        // Future-dated on purpose: the past-start guard already caught the
        // backdated case, which made this look covered. It was not — a
        // forward-dated committed block persisted and projected to the UI as
        // work the user had agreed to. Observed in 4 of 9 archived eval runs,
        // always a single 09:00 block on bindingDirective.
        expect(
          () => parse(rawBlock()..['state'] = 'committed'),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('may not be created as committed'),
            ),
          ),
        );
      });

      test('rejects it even with no past-start guard in play at all', () {
        // A future-day draft passes earliestDraftStart: null, so the past-start
        // guard is inert. The commitment rule has to stand on its own.
        expect(
          () => parse(rawBlock()..['state'] = 'committed'),
          throwsA(isA<DayAgentCaptureException>()),
        );
      });

      test('still repeats an already-committed baseline block', () {
        // The one legitimate use, and the reason `committed` stays in the tool
        // schema: a re-draft over an agreed plan must be able to carry the
        // user's approved blocks forward without downgrading them.
        final block = parse(
          rawBlock()
            ..['state'] = 'committed'
            ..['id'] = 'block-existing',
          baselineBlocks: {
            'block-existing': _baselineBlock(
              id: 'block-existing',
              start: DateTime(2026, 3, 16, 9),
              state: PlannedBlockState.committed,
            ),
          },
        );

        expect(block.state, PlannedBlockState.committed);
        expect(block.id, 'block-existing');
      });

      test('returns the baseline verbatim, ignoring what the model wrote', () {
        // Matching id, start and state proves the block existed and was
        // approved. It says nothing about the fields written around them, so
        // rebuilding from the model's payload would let a re-draft rewrite
        // approved work under the user's prior consent — the same defect as
        // inventing a committed block, wearing a real block's id.
        final baseline = _baselineBlock(
          id: 'block-existing',
          start: DateTime(2026, 3, 16, 9),
          state: PlannedBlockState.committed,
        );

        final block = parse(
          rawBlock(
              title: 'Rewritten title',
              endHour: 12,
              reason: 'different reason',
            )
            ..['state'] = 'committed'
            ..['id'] = 'block-existing'
            ..['taskId'] = 'task-smuggled'
            ..['note'] = 'smuggled note',
          decidedTaskIds: const {'task-smuggled': 'cat-1'},
          baselineBlocks: {'block-existing': baseline},
        );

        expect(block, baseline);
        expect(block.title, 'block-existing');
        expect(block.endTime, DateTime(2026, 3, 16, 10));
        expect(block.taskId, isNull);
        expect(block.note, isNull);
      });

      test('will not promote a drafted baseline block to committed', () {
        // Matching an id is not approval. The baseline block was drafted, so
        // calling it committed invents the user's verdict just as much as a
        // brand-new block would.
        expect(
          () => parse(
            rawBlock()
              ..['state'] = 'committed'
              ..['id'] = 'block-existing',
            baselineBlocks: {
              'block-existing': _baselineBlock(
                id: 'block-existing',
                start: DateTime(2026, 3, 16, 9),
                state: PlannedBlockState.drafted,
              ),
            },
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('may not be created as committed'),
            ),
          ),
        );
      });

      test('will not move a committed baseline block to a new time', () {
        // Same id, same state, different start: that is rescheduling approved
        // work, which goes through an approved diff, not a redraft.
        expect(
          () => parse(
            rawBlock(startHour: 11, endHour: 12)
              ..['state'] = 'committed'
              ..['id'] = 'block-existing',
            baselineBlocks: {
              'block-existing': _baselineBlock(
                id: 'block-existing',
                start: DateTime(2026, 3, 16, 9),
                state: PlannedBlockState.committed,
              ),
            },
          ),
          throwsA(isA<DayAgentCaptureException>()),
        );
      });

      test('leaves the other states alone', () {
        // Only commitment is the user's to grant. History states stay
        // governed by the past-start rule, not by this one.
        for (final state in ['drafted', 'inProgress', 'completed', 'dropped']) {
          expect(
            parse(rawBlock()..['state'] = state).startTime,
            DateTime(2026, 3, 16, 9),
            reason: 'state=$state must still parse',
          );
        }
      });
    });

    group('earliestDraftStart guard', () {
      final earliest = DateTime(2026, 3, 16, 14);

      test('rejects past-starting drafted ai, manual, and buffer blocks', () {
        // Every agent-invented type is guarded — models were observed live
        // relabelling a past-starting block `buffer` to slip through an
        // ai/manual-only guard.
        for (final type in ['ai', 'manual', 'buffer']) {
          expect(
            () => parse(
              rawBlock(type: type),
              earliestDraftStart: earliest,
            ),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('must not start before current time'),
              ),
            ),
            reason: 'type=$type must be rejected',
          );
        }
      });

      test('exempts only states that record what already happened', () {
        // History a re-draft legitimately carries forward. These are records,
        // not plans, so they are allowed to sit in the past.
        for (final state in ['inProgress', 'completed', 'dropped']) {
          final block = parse(
            rawBlock()..['state'] = state,
            earliestDraftStart: earliest,
          );
          expect(block.startTime, DateTime(2026, 3, 16, 9), reason: state);
        }
      });

      test('guards committed blocks, not just drafted ones', () {
        // `committed` is a plan the user agreed to, not a record of something
        // that happened — and writing a new block as committed was the
        // remaining way to place work before the current time, the same
        // probing as relabelling a block `buffer`, one field over.
        expect(
          () => parse(
            rawBlock()..['state'] = 'committed',
            earliestDraftStart: earliest,
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('must not start before current time'),
            ),
          ),
        );
      });

      test('carries forward a committed baseline block unchanged', () {
        // A legacy `agreed` plan can hold committed blocks the user already
        // approved. Once one has started, a redraft must still be able to
        // include it — rejecting the whole draft for faithfully repeating
        // what is already on the plan would punish the correct behaviour.
        final block = parse(
          rawBlock()
            ..['state'] = 'committed'
            ..['id'] = 'block-existing',
          earliestDraftStart: earliest,
          baselineBlocks: {
            'block-existing': _baselineBlock(
              id: 'block-existing',
              start: DateTime(2026, 3, 16, 9),
              state: PlannedBlockState.committed,
            ),
          },
        );

        expect(block.id, 'block-existing');
        expect(block.startTime, DateTime(2026, 3, 16, 9));
      });

      test('will not let a baseline id move approved work into the past', () {
        // The exemption keys on id *and* start, so reusing a known id with a
        // new time is still newly planning the past.
        expect(
          () => parse(
            rawBlock()
              ..['state'] = 'committed'
              ..['id'] = 'block-existing',
            earliestDraftStart: earliest,
            baselineBlocks: {
              'block-existing': _baselineBlock(
                id: 'block-existing',
                start: DateTime(2026, 3, 16, 11),
                state: PlannedBlockState.committed,
              ),
            },
          ),
          throwsA(
            isA<DayAgentCaptureException>().having(
              (e) => e.message,
              'message',
              contains('must not start before current time'),
            ),
          ),
        );
      });

      test('will not let a baseline id adopt a new plan state in the past', () {
        // The attack the id+start match alone allowed: reuse a known 09:00
        // block id and drop a brand-new committed block into that slot,
        // rewriting approved work without the refinement approval that
        // normally gates it.
        expect(
          () => parse(
            rawBlock()
              ..['state'] = 'committed'
              ..['id'] = 'block-existing',
            earliestDraftStart: earliest,
            baselineBlocks: {
              'block-existing': _baselineBlock(
                id: 'block-existing',
                start: DateTime(2026, 3, 16, 9),
                state: PlannedBlockState.drafted,
              ),
            },
          ),
          throwsA(isA<DayAgentCaptureException>()),
        );
      });

      test('a cal block is refused outright, guard or no guard', () {
        // `cal` means "imported calendar event" and this agent is shown none,
        // so the type can only ever assert an import that never happened —
        // and the plan editor then refuses to let the user edit the result.
        for (final earliestStart in [earliest, null]) {
          expect(
            () => parse(
              rawBlock(type: 'cal'),
              earliestDraftStart: earliestStart,
            ),
            throwsA(
              isA<DayAgentCaptureException>().having(
                (e) => e.message,
                'message',
                contains('none are available to this agent'),
              ),
            ),
            reason: 'earliestDraftStart=$earliestStart',
          );
        }
      });

      test('accepts drafted blocks starting at or after the boundary', () {
        final atBoundary = parse(
          rawBlock(startHour: 14, endHour: 15, type: 'buffer'),
          earliestDraftStart: earliest,
        );
        expect(atBoundary.startTime, earliest);

        final after = parse(
          rawBlock(startHour: 15, endHour: 16),
          earliestDraftStart: earliest,
        );
        expect(after.startTime, DateTime(2026, 3, 16, 15));
      });
    });

    test('rejects task ids that are neither decided nor existing', () {
      expect(
        () => parse(rawBlock(taskId: 'task-x')),
        throwsA(isA<DayAgentCaptureException>()),
      );
      final block = parse(
        rawBlock(taskId: 'task-x'),
        decidedTaskIds: const {'task-x': 'cat-1'},
      );
      expect(block.taskId, 'task-x');
    });

    test(
      "files a task-backed block under its task category, not the model's",
      () {
        // The two were validated independently — the block's category had to be
        // allowed, and the task had to be allowed — but never against each
        // other, so a block could carry a task from one area and bill its time
        // to another. `plannedMinutesByCategory` and every rollup built on it
        // read this field.
        final block = parse(
          rawBlock(taskId: 'task-ops'),
          allowedCategoryIds: const {'cat-1', 'cat-ops'},
          decidedTaskIds: const {'task-ops': 'cat-ops'},
        );

        expect(block.categoryId, 'cat-ops');
      },
    );

    test('reads the category from either allow-set', () {
      final block = parse(
        rawBlock(taskId: 'task-existing'),
        allowedCategoryIds: const {'cat-1', 'cat-ops'},
        allowedExistingTaskIds: const {'task-existing': 'cat-ops'},
      );

      expect(block.categoryId, 'cat-ops');
    });

    test('leaves a block with no task on the category the model chose', () {
      // Buffers, breaks and manual blocks have no task to inherit from, so
      // the model's choice stands.
      final block = parse(rawBlock(type: 'buffer', reason: null));

      expect(block.categoryId, 'cat-1');
      expect(block.taskId, isNull);
    });

    test('falls back to the model category when the task has none', () {
      // An uncategorised task cannot dictate a category, and nulling the
      // block's would drop it out of every per-category rollup.
      final block = parse(
        rawBlock(taskId: 'task-loose'),
        decidedTaskIds: const {'task-loose': null},
      );

      expect(block.categoryId, 'cat-1');
    });
  });

  group('earliestPlannableStart / advertisedPlanningStart', () {
    final planDate = DateTime(2026, 7, 26);

    test('a future plan day is unconstrained on both', () {
      final now = DateTime(2026, 7, 25, 15);
      expect(earliestPlannableStart(planDate: planDate, now: now), isNull);
      expect(advertisedPlanningStart(planDate: planDate, now: now), isNull);
    });

    test('the enforced threshold is the raw instant', () {
      final now = DateTime(2026, 7, 26, 15, 0, 0, 5, 877);
      expect(earliestPlannableStart(planDate: planDate, now: now), now);
    });

    test('the advertised start clears the instant that caused the '
        'rejections', () {
      // The measured failure, exactly: the prompt rendered
      // 15:00:00.005877, every sampled model sensibly started the day at
      // 15:00:00.000, and the guard rejected all 6/6 by under six
      // milliseconds. The advertised value must be strictly later than the
      // instant the model reads, or it reproduces that.
      final now = DateTime(2026, 7, 26, 15, 0, 0, 5, 877);
      final advertised = advertisedPlanningStart(planDate: planDate, now: now);

      expect(advertised, DateTime(2026, 7, 26, 15, 5));
      expect(advertised!.isAfter(now), isTrue);
    });

    test('never advertises an instant already lost to the guard', () {
      // Property: for any moment of the plan day, what the prompt promises is
      // strictly later than what the write path enforces. Landing exactly on
      // the boundary is not enough — the guard runs a moment later still.
      for (var minute = 0; minute < 60; minute++) {
        for (final second in [0, 30, 59]) {
          final now = DateTime(2026, 7, 26, 9, minute, second);
          final enforced = earliestPlannableStart(planDate: planDate, now: now);
          final advertised = advertisedPlanningStart(
            planDate: planDate,
            now: now,
          );

          expect(
            advertised!.isAfter(enforced!),
            isTrue,
            reason: 'advertised $advertised must be after enforced $enforced',
          );
        }
      }
    });

    test('closes the window rather than advertising tomorrow', () {
      // The same bug at the other end of the day: walking forward for headroom
      // runs past midnight, and `parsePlannedBlock` rejects anything outside
      // the plan day — so advertising it would steer the model straight into
      // the rejection this function exists to prevent.
      for (final now in [
        DateTime(2026, 7, 26, 23, 56),
        DateTime(2026, 7, 26, 23, 58),
        DateTime(2026, 7, 26, 23, 59, 59),
      ]) {
        expect(
          advertisedPlanningStart(planDate: planDate, now: now),
          isNull,
          reason: 'must not advertise a slot outside the plan day at $now',
        );
        expect(
          planningWindowClosed(planDate: planDate, now: now),
          isTrue,
          reason: 'closed is not the same as unconstrained',
        );
      }
    });

    test('still advertises the last usable slot of the day', () {
      // 23:55-00:00 is a legal five-minute block, so the window is not closed
      // yet. Closing it early would silently drop the tail of the day.
      final now = DateTime(2026, 7, 26, 23, 50);

      expect(
        advertisedPlanningStart(planDate: planDate, now: now),
        DateTime(2026, 7, 26, 23, 55),
      );
      expect(planningWindowClosed(planDate: planDate, now: now), isFalse);
    });

    test('a closed window is distinguishable from an unconstrained day', () {
      // Both leave advertisedPlanningStart null. Collapsing them would let a
      // wake at 23:58 plan freely from this morning.
      expect(
        planningWindowClosed(
          planDate: planDate,
          now: DateTime(2026, 7, 25, 23, 58),
        ),
        isFalse,
        reason: 'a future plan day is unconstrained, not closed',
      );
    });

    test('uses calendar arithmetic for the day boundary, not +24h', () {
      // On a DST day, local midnight + 24h is 01:00 or 23:00, not the next
      // midnight — which would either advertise into tomorrow or close the
      // window an hour early. Asserted through the observable behaviour: the
      // last usable slot of the day is the same on a transition day as on an
      // ordinary one.
      for (final day in [
        DateTime(2026, 3, 29), // European spring forward
        DateTime(2026, 10, 25), // European fall back
        DateTime(2026, 7, 26), // ordinary day, as a control
      ]) {
        final lastSlot = DateTime(day.year, day.month, day.day, 23, 50);
        expect(
          advertisedPlanningStart(planDate: day, now: lastSlot),
          DateTime(day.year, day.month, day.day, 23, 55),
          reason: 'last usable slot must not move on $day',
        );
        expect(
          advertisedPlanningStart(
            planDate: day,
            now: DateTime(day.year, day.month, day.day, 23, 58),
          ),
          isNull,
          reason: 'window must still close before midnight on $day',
        );
      }
    });
  });

  group('remainingWorkingMinutes', () {
    final planDate = DateTime(2026, 7, 26);

    int? minutes({
      required DateTime now,
      int capacityMinutes = 480,
      String start = '09:00',
      String end = '17:00',
    }) => remainingWorkingMinutes(
      planDate: planDate,
      now: now,
      capacityMinutes: capacityMinutes,
      workingHoursStart: start,
      workingHoursEnd: end,
    );

    test('an untouched future day is bounded by capacity', () {
      // 09:00-17:00 is 480 minutes and capacity is 480, so neither binds
      // harder than the other.
      expect(minutes(now: DateTime(2026, 7, 25, 20)), 480);
    });

    test('the clock binds once the day is underway', () {
      // The measured case: drafting at 15:00 leaves 115 minutes to 17:00, not
      // the 480 of capacity the planning defaults advertise. Models were
      // scheduling against the wrong one and running to 17:45.
      expect(minutes(now: DateTime(2026, 7, 26, 15)), 115);
    });

    test('counts from the advertised start, not the raw instant', () {
      // Must agree with what the model is told to build from, or the budget
      // describes minutes it is not allowed to use.
      expect(minutes(now: DateTime(2026, 7, 26, 15, 0, 0, 5, 877)), 115);
    });

    test('capacity binds when it is smaller than the clock', () {
      expect(minutes(now: DateTime(2026, 7, 25, 20), capacityMinutes: 90), 90);
    });

    test('a finished working day is zero, not negative or absent', () {
      // A real answer the model can act on: nothing more fits inside working
      // hours today.
      expect(minutes(now: DateTime(2026, 7, 26, 18)), 0);
    });

    test('says nothing when the window is closed', () {
      // `closed` already carries that instruction; a second number saying the
      // same thing invites the model to reconcile two signals.
      expect(minutes(now: DateTime(2026, 7, 26, 23, 58)), isNull);
    });

    test('says nothing rather than guessing at malformed hours', () {
      // These are free-text config nothing else parses. A fallback would have
      // the model plan against a budget the user never set.
      expect(minutes(now: DateTime(2026, 7, 26, 10), end: 'half five'), isNull);
      expect(minutes(now: DateTime(2026, 7, 26, 10), end: '25:00'), isNull);
      expect(minutes(now: DateTime(2026, 7, 26, 10), start: ''), isNull);
    });

    test('a start before working hours does not buy extra minutes', () {
      // 07:00 is inside the plan day but outside working hours, so the budget
      // still runs from 09:00.
      expect(minutes(now: DateTime(2026, 7, 26, 7)), 480);
    });
  });

  group('validateDraftWorkingHours', () {
    PlannedBlock block({
      required DateTime start,
      required DateTime end,
      PlannedBlockState state = PlannedBlockState.drafted,
    }) => PlannedBlock(
      id: 'block',
      categoryId: 'cat-1',
      startTime: start,
      endTime: end,
      title: 'Bounded work',
      state: state,
    );

    void validate(
      PlannedBlock planned, {
      String start = '09:00',
      String end = '17:00',
    }) => validateDraftWorkingHours(
      blocks: [planned],
      planDate: day,
      workingHoursStart: start,
      workingHoursEnd: end,
    );

    test('accepts active work exactly on both configured boundaries', () {
      expect(
        () => validate(
          block(
            start: DateTime(2026, 3, 16, 9),
            end: DateTime(2026, 3, 16, 17),
          ),
        ),
        returnsNormally,
      );
    });

    test('rejects active work before or after the configured window', () {
      expect(
        () => validate(
          block(
            start: DateTime(2026, 3, 16, 8, 55),
            end: DateTime(2026, 3, 16, 10),
          ),
        ),
        throwsA(
          isA<DayAgentCaptureException>().having(
            (error) => error.message,
            'message',
            allOf(contains('starts before'), contains('09:00')),
          ),
        ),
      );
      expect(
        () => validate(
          block(
            start: DateTime(2026, 3, 16, 16),
            end: DateTime(2026, 3, 16, 17, 5),
          ),
        ),
        throwsA(
          isA<DayAgentCaptureException>().having(
            (error) => error.message,
            'message',
            allOf(contains('ends after'), contains('17:00')),
          ),
        ),
      );
    });

    test('does not police dropped history or invent malformed bounds', () {
      expect(
        () => validate(
          block(
            start: DateTime(2026, 3, 16, 7),
            end: DateTime(2026, 3, 16, 19),
            state: PlannedBlockState.dropped,
          ),
        ),
        returnsNormally,
      );
      expect(
        () => validate(
          block(
            start: DateTime(2026, 3, 16, 7),
            end: DateTime(2026, 3, 16, 19),
          ),
          start: 'morning',
          end: 'five-ish',
        ),
        returnsNormally,
      );
    });
  });

  // ── Block-category invariants ────────────────────────────────────────────
  // A block naming a task is filed under that task's category. The defect this
  // replaces existed because the two were checked independently, and the fix
  // was then shipped at one of the two doors, so the rule is worth stating as
  // an invariant rather than as a handful of cases.
  group('Glados categoryForPlannedBlock', () {
    glados.Glados<_CategoryPick>(
      glados.any.categoryPick,
      glados.ExploreConfig(numRuns: 300),
    ).test('a task-backed block always lands on its task category', (pick) {
      final resolved = categoryForPlannedBlock(
        taskId: pick.taskId,
        fallback: pick.fallback,
        taskCategoryIds: pick.taskCategoryIds,
      );

      if (pick.taskId == null) {
        // Nothing to inherit from: buffers and breaks keep what was chosen.
        expect(resolved, pick.fallback);
        return;
      }
      // The queried id is generated independently of the map, so a task
      // *missing* from it — a deleted or out-of-scope reference — is a case
      // this actually reaches rather than one assumed away.
      final known = pick.taskCategoryIds[pick.taskId];
      expect(resolved, known ?? pick.fallback);
    }, tags: 'glados');

    glados.Glados<_CategoryPick>(
      glados.any.categoryPick,
      glados.ExploreConfig(numRuns: 300),
    ).test('a missing key behaves exactly like a key mapped to null', (pick) {
      final taskId = pick.taskId;
      if (taskId == null) return;

      final withNullValue = categoryForPlannedBlock(
        taskId: taskId,
        fallback: pick.fallback,
        taskCategoryIds: {taskId: null},
      );
      final withNoKey = categoryForPlannedBlock(
        taskId: taskId,
        fallback: pick.fallback,
        taskCategoryIds: const {},
      );

      expect(withNullValue, withNoKey);
      expect(withNoKey, pick.fallback);
    }, tags: 'glados');

    glados.Glados<_CategoryPick>(
      glados.any.categoryPick,
      glados.ExploreConfig(numRuns: 300),
    ).test('the result is never null and never invents a category', (pick) {
      final resolved = categoryForPlannedBlock(
        taskId: pick.taskId,
        fallback: pick.fallback,
        taskCategoryIds: pick.taskCategoryIds,
      );

      expect(
        resolved == pick.fallback ||
            pick.taskCategoryIds.values.contains(resolved),
        isTrue,
        reason: '$resolved came from neither the fallback nor the task map',
      );
    }, tags: 'glados');
  });

  // ── Planning-window invariants ───────────────────────────────────────────
  // Every defect found in these functions has been a boundary: one second of
  // headroom just before a five-minute mark, a walk running past midnight, a
  // DST day where +24h is not the next midnight.
  //
  // Coverage is split deliberately. Minutes of a day are a *small finite*
  // domain — 1,440 of them — so they are swept exhaustively; sampling would
  // leave most of them unvisited on any given seed. Glados then explores what
  // is not finite: sub-minute offsets, capacities, and their combinations.
  group('planning window', () {
    final planDate = DateTime(2026, 7, 26);

    test('every minute of the day upholds the window invariants', () {
      for (var minuteOfDay = 0; minuteOfDay < 24 * 60; minuteOfDay++) {
        final now = DateTime(
          planDate.year,
          planDate.month,
          planDate.day,
          minuteOfDay ~/ 60,
          minuteOfDay % 60,
        );
        final enforced = earliestPlannableStart(planDate: planDate, now: now);
        final advertised = advertisedPlanningStart(
          planDate: planDate,
          now: now,
        );
        final closed = planningWindowClosed(planDate: planDate, now: now);

        // Plannable or closed, never both and never neither. Collapsing them
        // would let a 23:58 wake read as unconstrained and plan from this
        // morning.
        expect(
          advertised != null,
          isNot(closed),
          reason: 'ambiguous window at $now',
        );
        if (advertised == null) continue;

        expect(
          advertised.difference(enforced!) >= minimumPlanningHeadroom,
          isTrue,
          reason: 'advertised $advertised is not clear of $enforced',
        );
        // Whole boundary, not just the minute field: 10:05:59 is not aligned.
        expect(localDay(advertised), localDay(planDate), reason: '$now');
        expect(advertised.minute % advertisedStartGranularity.inMinutes, 0);
        expect(advertised.second, 0, reason: '$now');
        expect(advertised.millisecond, 0, reason: '$now');
        expect(advertised.microsecond, 0, reason: '$now');
      }
    });

    test('the configured headroom clears the worst observed wake latency', () {
      // Independent of the implementation constant on purpose: asserting the
      // gap against `minimumPlanningHeadroom` alone would let the constant and
      // the test weaken together. 152s is the slowest wake measured in the
      // 48-cell matrix.
      expect(
        minimumPlanningHeadroom,
        greaterThan(const Duration(seconds: 152)),
      );
    });

    glados.Glados<_WindowScenario>(
      glados.any.windowScenario,
      glados.ExploreConfig(numRuns: 300),
    ).test('sub-minute offsets never break alignment or the headroom', (
      scenario,
    ) {
      final now = scenario.instantOn(planDate);
      final enforced = earliestPlannableStart(planDate: planDate, now: now);
      final advertised = advertisedPlanningStart(planDate: planDate, now: now);
      if (advertised == null) {
        expect(planningWindowClosed(planDate: planDate, now: now), isTrue);
        return;
      }

      expect(
        advertised.difference(enforced!) >= minimumPlanningHeadroom,
        isTrue,
        reason: 'advertised $advertised is not clear of $enforced',
      );
      expect(localDay(advertised), localDay(planDate));
      expect(advertised.minute % advertisedStartGranularity.inMinutes, 0);
      expect(advertised.second, 0);
      expect(advertised.millisecond, 0);
      expect(advertised.microsecond, 0);
    }, tags: 'glados');

    glados.Glados<_WindowScenario>(
      glados.any.windowScenario,
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'the budget is bounded by capacity and by the clock it may use',
      (
        scenario,
      ) {
        const dayEnd = 17 * 60;
        final now = scenario.instantOn(planDate);
        final minutes = remainingWorkingMinutes(
          planDate: planDate,
          now: now,
          capacityMinutes: scenario.capacityMinutes,
          workingHoursStart: '09:00',
          workingHoursEnd: '17:00',
        );
        if (minutes == null) {
          expect(planningWindowClosed(planDate: planDate, now: now), isTrue);
          return;
        }

        expect(minutes, greaterThanOrEqualTo(0));
        expect(minutes, lessThanOrEqualTo(scenario.capacityMinutes));

        // Bounded by the clock the model was actually told it may use, for this
        // scenario's own capacity — not by the length of the working day. A
        // regression returning 480 at 16:00 on a 960-minute capacity has to
        // fail here.
        final advertised = advertisedPlanningStart(
          planDate: planDate,
          now: now,
        );
        final startMinutes = advertised == null
            ? 9 * 60
            : (advertised.hour * 60 + advertised.minute).clamp(9 * 60, dayEnd);
        expect(minutes, lessThanOrEqualTo(dayEnd - startMinutes));
      },
      tags: 'glados',
    );
  });

  group('selectIndices', () {
    test('returns the full range when indices are omitted', () {
      expect(selectIndices(itemIndices: null, itemCount: 3), [0, 1, 2]);
    });

    test('deduplicates, sorts, and bounds-checks explicit indices', () {
      expect(
        selectIndices(itemIndices: [2, 0, 2], itemCount: 3),
        [0, 2],
      );
      expect(
        () => selectIndices(itemIndices: [3], itemCount: 3),
        throwsA(isA<DayAgentCaptureException>()),
      );
    });
  });

  group('day id helpers', () {
    test('dateFromDayId parses only dayplan-prefixed ids', () {
      expect(dateFromDayId('dayplan-2026-03-16'), DateTime(2026, 3, 16));
      expect(dateFromDayId('2026-03-16'), isNull);
    });

    test('dayIdFromPlanEntityId strips the agent plan prefix', () {
      expect(
        dayIdFromPlanEntityId('day_agent_plan:dayplan-2026-03-16'),
        'dayplan-2026-03-16',
      );
      expect(dayIdFromPlanEntityId('dayplan-x'), 'dayplan-x');
    });
  });

  group('categoryAllowed', () {
    test('null or empty allow-set permits everything', () {
      expect(categoryAllowed('cat-1', null), isTrue);
      expect(categoryAllowed('cat-1', const {}), isTrue);
      expect(categoryAllowed('cat-1', const {'cat-1'}), isTrue);
      expect(categoryAllowed('cat-2', const {'cat-1'}), isFalse);
      expect(categoryAllowed(null, const {'cat-1'}), isFalse);
    });
  });

  group('blankToNull', () {
    test('maps blank and null to null and trims the rest', () {
      expect(blankToNull('  '), isNull);
      expect(blankToNull(null), isNull);
      expect(blankToNull(' x '), 'x');
    });
  });
}

PlannedBlock _baselineBlock({
  required String id,
  required DateTime start,
  required PlannedBlockState state,
}) => PlannedBlock(
  id: id,
  categoryId: 'cat-1',
  startTime: start,
  endTime: start.add(const Duration(hours: 1)),
  title: id,
  state: state,
);

/// One generated moment of a plan day, plus the capacity in force.
///
/// `now` is built from the parts rather than generated as a `DateTime` so the
/// exploration lands on the boundaries that have actually broken this code:
/// the minute before a five-minute mark, the last minutes before midnight, and
/// sub-second offsets past the hour.
class _WindowScenario {
  _WindowScenario(this.hour, this.minute, this.second, this.capacityMinutes);

  final int hour;
  final int minute;
  final int second;
  final int capacityMinutes;

  DateTime instantOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute, second);

  @override
  String toString() =>
      '_WindowScenario($hour:$minute:$second, cap $capacityMinutes)';
}

extension _AnyPlanningWindow on glados.Any {
  glados.Generator<_WindowScenario> get windowScenario =>
      glados.CombinableAny(this).combine4(
        glados.AnyUtils(this).choose(_hours),
        glados.AnyUtils(this).choose(_minutes),
        glados.AnyUtils(this).choose(const [0, 1, 30, 59]),
        glados.AnyUtils(this).choose(const [15, 60, 240, 480, 960]),
        _WindowScenario.new,
      );
}

final List<int> _hours = List<int>.generate(24, (i) => i);
final List<int> _minutes = List<int>.generate(60, (i) => i);

/// One generated block/task category pairing.
class _CategoryPick {
  _CategoryPick(this.taskId, this.fallback, this.mappedTaskId, this.mapped);

  /// The id the block references.
  final String? taskId;
  final String fallback;

  /// The id the map knows about — generated *independently* of [taskId], so
  /// the unknown-task case is actually reached rather than assumed away.
  final String? mappedTaskId;
  final String? mapped;

  Map<String, String?> get taskCategoryIds =>
      mappedTaskId == null ? const {} : {mappedTaskId!: mapped};

  @override
  String toString() =>
      '_CategoryPick(query $taskId, map {$mappedTaskId: $mapped}, '
      'else $fallback)';
}

extension _AnyCategoryPick on glados.Any {
  glados.Generator<_CategoryPick> get categoryPick =>
      glados.CombinableAny(this).combine4(
        glados.AnyUtils(this).choose(const [null, 'task-a', 'task-b']),
        glados.AnyUtils(this).choose(const ['cat-fallback', 'cat-work']),
        // Independently chosen, so the map often does not contain the queried
        // id at all.
        glados.AnyUtils(this).choose(const [null, 'task-a', 'task-c']),
        glados.AnyUtils(this).choose(const [null, 'cat-ops', 'cat-work']),
        _CategoryPick.new,
      );
}
