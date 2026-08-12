import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/event_tool_definitions.dart';
import 'package:lotti/features/agents/tools/project_tool_definitions.dart';
import 'package:lotti/features/agents/ui/localized_change_summary.dart';
import 'package:lotti/features/tasks/model/directed_relation.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_de.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/l10n/app_localizations_ro.dart';

// `ChangeItem.humanSummary` is generated headlessly during a wake and persisted
// into a synced entity, so it is English forever on every device. These cover
// the render-time reconstruction that replaces it, the fallback for tools it
// does not know, and — crucially — that the output actually changes with the
// locale, which an English-only assertion cannot show.

void main() {
  // Due dates go through `DateFormat`, whose symbol data is normally loaded by
  // `GlobalMaterialLocalizations.delegate` inside a widget tree. These are pure
  // unit tests with no tree, so the locales under test are initialized here.
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('de');
  });

  final AppLocalizations en = AppLocalizationsEn();
  final AppLocalizations de = AppLocalizationsDe();
  final AppLocalizations ro = AppLocalizationsRo();

  String? summary(
    String toolName,
    Map<String, dynamic> args, {
    AppLocalizations? messages,
  }) => localizedChangeSummary(messages ?? en, toolName, args);

  group('metadata setters', () {
    test('each setter names its own field and value', () {
      expect(
        summary(TaskAgentToolNames.setTaskTitle, {'title': 'Ship it'}),
        'Set title to "Ship it"',
      );
      expect(
        summary(TaskAgentToolNames.updateTaskEstimate, {'minutes': 45}),
        'Set estimate to 45 minutes',
      );
      // Formatted for the reader rather than left as the wire string, so the
      // row matches the task header's own due-date rendering.
      expect(
        summary(TaskAgentToolNames.updateTaskDueDate, {
          'dueDate': '2026-08-01',
        }),
        'Set due date to Aug 1, 2026',
      );
      expect(
        summary(TaskAgentToolNames.updateTaskPriority, {'priority': 'high'}),
        'Set priority to high',
      );
      // Statuses render through the task UI's own localized labels, not the
      // wire vocabulary.
      expect(
        summary(TaskAgentToolNames.setTaskStatus, {'status': 'DONE'}),
        'Set status to Done',
      );
      expect(
        summary(TaskAgentToolNames.setTaskLanguage, {'languageCode': 'de'}),
        'Set language to "de"',
      );
    });

    test('a missing value degrades to a marker, never to "null"', () {
      // These args come from a model, so any key can be absent. Interpolating
      // a null would put the word "null" in front of the user.
      for (final tool in [
        TaskAgentToolNames.setTaskTitle,
        TaskAgentToolNames.updateTaskDueDate,
        TaskAgentToolNames.updateTaskPriority,
        TaskAgentToolNames.setTaskStatus,
        TaskAgentToolNames.setTaskLanguage,
        TaskAgentToolNames.createFollowUpTask,
      ]) {
        final text = summary(tool, const {});
        expect(text, isNotNull, reason: '$tool produced no summary');
        expect(text, contains('?'), reason: '$tool lost its placeholder');
        expect(text, isNot(contains('null')), reason: '$tool leaked a null');
      }
    });

    test('an estimate is pluralized, and a non-number falls back', () {
      // The estimate sentence is an ICU plural, so "1" must not read as
      // "1 minutes" — and a value that is not a number cannot fill a plural
      // slot in any language, so that one case defers to the persisted
      // summary instead of degrading in place.
      expect(
        summary(TaskAgentToolNames.updateTaskEstimate, {'minutes': 1}),
        'Set estimate to 1 minute',
      );
      expect(
        summary(TaskAgentToolNames.updateTaskEstimate, {'minutes': '90'}),
        'Set estimate to 90 minutes',
      );
      expect(
        summary(TaskAgentToolNames.updateTaskEstimate, {'minutes': 'soon'}),
        isNull,
      );
      expect(summary(TaskAgentToolNames.updateTaskEstimate, const {}), isNull);
    });

    test('a priority code renders as the task UI label, in the locale', () {
      // P0–P3 is wire vocabulary, accepted exactly as
      // TaskPriorityHandler.parsePriority accepts it; the task header shows
      // these as Urgent/High/Medium/Low, so the proposal must say the same
      // thing accepting it will display.
      expect(
        summary(TaskAgentToolNames.updateTaskPriority, {'priority': 'P0'}),
        'Set priority to Urgent',
      );
      expect(
        summary(TaskAgentToolNames.updateTaskPriority, {
          'priority': 'p2',
        }, messages: de),
        'Priorität auf Mittel setzen',
      );
      // Outside the vocabulary the value passes through verbatim.
      expect(
        summary(TaskAgentToolNames.updateTaskPriority, {'priority': 'P9'}),
        'Set priority to P9',
      );
    });

    test('the whole priority vocabulary maps onto the task UI labels', () {
      const labels = {
        'P0': 'Urgent',
        'P1': 'High',
        'P2': 'Medium',
        'P3': 'Low',
      };
      for (final MapEntry(key: code, value: label) in labels.entries) {
        expect(
          summary(TaskAgentToolNames.updateTaskPriority, {'priority': code}),
          'Set priority to $label',
          reason: code,
        );
      }
    });

    test('the whole project-status vocabulary maps onto the chip labels', () {
      const labels = {
        'open': 'Open',
        'active': 'Active',
        'monitoring': 'Monitoring',
        'on_hold': 'On Hold',
        'completed': 'Completed',
        'archived': 'Archived',
      };
      for (final MapEntry(key: wire, value: label) in labels.entries) {
        expect(
          summary(ProjectAgentToolNames.updateProjectStatus, {'status': wire}),
          'Update project status to $label',
          reason: wire,
        );
      }
    });
  });

  group('follow-up tasks', () {
    test('an unrelated follow-up states only the title', () {
      expect(
        summary(TaskAgentToolNames.createFollowUpTask, {'title': 'Write docs'}),
        'Create follow-up task: "Write docs"',
      );
    });

    test('a related follow-up adds the relationship as a full clause', () {
      expect(
        summary(TaskAgentToolNames.createFollowUpTask, {
          'title': 'Write docs',
          'relation': 'blocks',
        }),
        'Create follow-up task: "Write docs" — This task blocks the new task',
      );
    });

    test('every relation reads as its own whole sentence', () {
      // The follow-up does not exist yet, so its relation clause cannot borrow
      // the {target} templates — those slots decline differently per language.
      // Each direction must still be distinguishable from every other.
      final seen = <String>{};
      for (final relation in relationshipDirectedOptions) {
        final sentence = localizedNewTaskRelationSentence(en, relation);
        expect(
          seen.add(sentence),
          isTrue,
          reason: '${relation.wireName} duplicates another relation sentence',
        );
      }
      expect(seen, hasLength(relationshipDirectedOptions.length));
    });

    test('a case-language relation clause is grammatical, not glued', () {
      // Regression for the pronoun-in-{target} design this replaced: Romanian
      // rendered "Această sarcină blochează ea", which is ungrammatical — a
      // direct object needs the clitic "o", which cannot be substituted into
      // a template slot. The whole-sentence catalog entry is the fix.
      expect(
        summary(TaskAgentToolNames.createFollowUpTask, {
          'title': 'Scrie documentația',
          'relation': 'blocks',
        }, messages: ro),
        'Creați sarcină ulterioară: „Scrie documentația” — '
        'Această sarcină blochează sarcina nouă',
      );
      // German inverse relations put the object after a dative preposition,
      // where the old accusative pronoun was equally wrong; the authored
      // sentence flips to active voice instead.
      expect(
        summary(TaskAgentToolNames.createFollowUpTask, {
          'title': 'Docs schreiben',
          'relation': 'is_blocked_by',
        }, messages: de),
        'Folgeaufgabe erstellen: „Docs schreiben“ — '
        'Die neue Aufgabe blockiert diese Aufgabe',
      );
    });

    test('an unparseable relation degrades to the plain form', () {
      // A model can emit a relation outside the vocabulary; the title is still
      // worth showing.
      expect(
        summary(TaskAgentToolNames.createFollowUpTask, {
          'title': 'Write docs',
          'relation': 'entangles',
        }),
        'Create follow-up task: "Write docs"',
      );
    });
  });

  group('task relationships', () {
    test('every relation and direction has its own sentence', () {
      final seen = <String>{};
      for (final relation in relationshipDirectedOptions) {
        final sentence = localizedRelationSentence(en, relation, '"Target"');
        expect(
          sentence,
          contains('"Target"'),
          reason: '${relation.wireName} dropped its target',
        );
        expect(
          seen.add(sentence),
          isTrue,
          reason: '${relation.wireName} duplicates another relation sentence',
        );
      }
      // Eleven options: a symmetric plain link plus five types in both
      // directions. Two reading the same would make the proposal ambiguous
      // about which way the relationship runs.
      expect(seen, hasLength(relationshipDirectedOptions.length));
    });

    test(
      'a direction flip changes the sentence, not just the argument order',
      () {
        final blocks = relationshipDirectedOptions.firstWhere(
          (r) => r.type == EntryLinkType.blocks && !r.inverse,
        );
        final blockedBy = relationshipDirectedOptions.firstWhere(
          (r) => r.type == EntryLinkType.blocks && r.inverse,
        );

        expect(
          localizedRelationSentence(en, blocks, '"A"'),
          'This task blocks "A"',
        );
        expect(
          localizedRelationSentence(en, blockedBy, '"A"'),
          'This task is blocked by "A"',
        );
      },
    );

    test('a link proposal quotes the target title', () {
      expect(
        summary(TaskAgentToolNames.linkTask, {
          'relation': 'blocks',
          'targetTaskId': 't-1',
          'targetTitle': 'Ship the release',
        }),
        'This task blocks "Ship the release"',
      );
    });

    test('a link with no resolved title keeps the persisted wording', () {
      // The real task-agent path canonicalizes these args to relation +
      // targetTaskId so formatting-only repeats share a fingerprint, which
      // leaves the readable title only in the persisted summary. Rendering
      // `This task is blocked by "t-1"` would be a regression from
      // `... "Ship the migration"`, so this falls back instead.
      expect(
        summary(TaskAgentToolNames.linkTask, {
          'relation': 'is_blocked_by',
          'targetTaskId': 't-1',
        }),
        isNull,
      );
    });

    test('a link with no usable target defers to the persisted summary', () {
      // Returning null is the contract for "cannot rebuild this" — the caller
      // then shows the stored English rather than an empty row.
      expect(
        summary(TaskAgentToolNames.linkTask, {'relation': 'blocks'}),
        isNull,
      );
    });
  });

  group('time entries', () {
    test('a closed entry states both ends', () {
      expect(
        summary(TaskAgentToolNames.createTimeEntry, {
          'startTime': '2026-07-29T10:00:00',
          'endTime': '2026-07-29T11:30:00',
          'summary': 'Pairing',
        }),
        'Time entry 10:00–11:30: "Pairing"',
      );
    });

    test('an open entry states only its start', () {
      expect(
        summary(TaskAgentToolNames.createTimeEntry, {
          'startTime': '2026-07-29T10:00:00',
          'summary': 'Pairing',
        }),
        'Time entry from 10:00: "Pairing"',
      );
    });

    test('a present-but-invalid end never reads as a running timer', () {
      // The apply path distinguishes "endTime absent" (running timer) from
      // "endTime present but malformed" (a rejected completed session). A row
      // that rendered the second as "from 10:00" would describe a proposal
      // the handler will refuse as if accepting it started a timer.
      expect(
        summary(TaskAgentToolNames.createTimeEntry, {
          'startTime': '2026-07-29T10:00:00',
          'endTime': 42,
          'summary': 'Pairing',
        }),
        'Time entry 10:00–?: "Pairing"',
      );
      expect(
        summary(TaskAgentToolNames.createTimeEntry, {
          'startTime': '2026-07-29T10:00:00',
          'endTime': null,
          'summary': 'Pairing',
        }),
        'Time entry 10:00–?: "Pairing"',
      );
    });

    test('an update covers all four range-and-text combinations', () {
      const s = '2026-07-29T10:00:00';
      const e = '2026-07-29T11:30:00';

      expect(
        summary(TaskAgentToolNames.updateTimeEntry, const {}),
        'Update time entry',
      );
      expect(
        summary(TaskAgentToolNames.updateTimeEntry, const {
          'startTime': s,
          'endTime': e,
        }),
        'Update time entry 10:00–11:30',
      );
      expect(
        summary(TaskAgentToolNames.updateTimeEntry, const {
          'summary': 'Revised',
        }),
        'Revise time entry text: "Revised"',
      );
      expect(
        summary(TaskAgentToolNames.updateTimeEntry, const {
          'startTime': s,
          'endTime': e,
          'summary': 'Revised',
        }),
        'Update time entry 10:00–11:30: "Revised"',
      );
    });

    test('a one-ended update says which end it sets', () {
      const s = '2026-07-29T10:00:00';
      const e = '2026-07-29T11:30:00';

      expect(
        summary(TaskAgentToolNames.updateTimeEntry, const {'startTime': s}),
        'Update time entry from 10:00',
      );
      expect(
        summary(TaskAgentToolNames.updateTimeEntry, const {'endTime': e}),
        'Update time entry until 11:30',
      );
    });

    test('an unparseable timestamp is shown verbatim rather than dropped', () {
      // Losing the value entirely would make two different proposals read
      // identically; showing the raw string at least stays truthful.
      expect(
        summary(TaskAgentToolNames.updateTimeEntry, const {
          'startTime': 'yesterday',
        }),
        'Update time entry from yesterday',
      );
    });

    test('the running timer names its new text', () {
      expect(
        summary(TaskAgentToolNames.updateRunningTimer, {
          'summary': '  Drafting  ',
        }),
        'Update running timer text: "Drafting"',
      );
    });
  });

  group('project and event agents', () {
    test('next steps are counted, and singular reads as singular', () {
      expect(
        summary(ProjectAgentToolNames.recommendNextSteps, {
          'steps': ['a'],
        }),
        'Recommend 1 next step',
      );
      expect(
        summary(ProjectAgentToolNames.recommendNextSteps, {
          'steps': ['a', 'b', 'c'],
        }),
        'Recommend 3 next steps',
      );
    });

    test('an empty step list drops the count rather than saying zero', () {
      expect(
        summary(ProjectAgentToolNames.recommendNextSteps, {
          'steps': <String>[],
        }),
        'Recommend next steps',
      );
      expect(
        summary(ProjectAgentToolNames.recommendNextSteps, const {}),
        'Recommend next steps',
      );
    });

    test('project status and task creation name their subject', () {
      expect(
        summary(ProjectAgentToolNames.updateProjectStatus, {
          'status': 'active',
        }),
        'Update project status to Active',
      );
      expect(
        summary(ProjectAgentToolNames.createTask, {'title': 'Draft the ADR'}),
        'Create task: Draft the ADR',
      );
      // A missing title degrades to the marker like every other missing
      // value — not to an English word inside a translated sentence.
      expect(
        summary(ProjectAgentToolNames.createTask, const {}),
        'Create task: ?',
      );
    });

    test('a project status alias shows the status accepting it will set', () {
      // The apply path collapses aliases into the six ProjectStatus variants,
      // so "blocked" actually sets On Hold. Displaying the raw alias would
      // describe a status the proposal cannot produce — in any language.
      expect(
        summary(ProjectAgentToolNames.updateProjectStatus, {
          'status': 'blocked',
        }),
        'Update project status to On Hold',
      );
      expect(
        summary(ProjectAgentToolNames.updateProjectStatus, {
          'status': 'done',
        }, messages: de),
        'Projektstatus auf Abgeschlossen setzen',
      );
      // Outside the vocabulary the value passes through verbatim, and a
      // missing one degrades to the marker — never to English words.
      expect(
        summary(ProjectAgentToolNames.updateProjectStatus, {
          'status': 'limbo',
        }),
        'Update project status to limbo',
      );
      expect(
        summary(ProjectAgentToolNames.updateProjectStatus, const {}),
        'Update project status to ?',
      );
    });

    test(
      'an event follow-up falls back to a generic sentence when untitled',
      () {
        expect(
          summary(EventAgentToolNames.suggestFollowUpTask, {
            'title': 'Send memo',
          }),
          'Follow-up task: Send memo',
        );
        expect(
          summary(EventAgentToolNames.suggestFollowUpTask, {'title': '   '}),
          'Suggest a follow-up task',
        );
      },
    );
  });

  group('exploded checklist items', () {
    test('an added item reads as its title', () {
      expect(
        summary(TaskAgentToolNames.addChecklistItem, {'title': 'Buy milk'}),
        'Add: "Buy milk"',
      );
    });

    test('an update reads as the verb it performs', () {
      expect(
        summary(TaskAgentToolNames.updateChecklistItem, {
          'title': 'Buy milk',
          'isChecked': true,
        }),
        'Check: "Buy milk"',
      );
      expect(
        summary(TaskAgentToolNames.updateChecklistItem, {
          'title': 'Buy milk',
          'isChecked': false,
        }),
        'Uncheck: "Buy milk"',
      );
      expect(
        summary(TaskAgentToolNames.updateChecklistItem, {
          'title': 'Buy milk',
          'isArchived': true,
        }),
        'Archive: "Buy milk"',
      );
      expect(
        summary(TaskAgentToolNames.updateChecklistItem, {
          'title': 'Buy milk',
          'isArchived': false,
        }),
        'Restore: "Buy milk"',
      );
    });

    test('archival wins over a checked flag sent alongside it', () {
      // Both can arrive together; archiving is the larger action and reads
      // clearest as its own verb.
      expect(
        summary(TaskAgentToolNames.updateChecklistItem, {
          'title': 'Buy milk',
          'isArchived': true,
          'isChecked': true,
        }),
        'Archive: "Buy milk"',
      );
    });

    test('an item addressed only by id keeps the persisted wording', () {
      // The title was resolved from the database during the wake and never
      // stored in args, so it exists only in the persisted summary. Rendering
      // a bare id would be strictly worse than falling back.
      expect(
        summary(TaskAgentToolNames.updateChecklistItem, {
          'id': 'cl-1',
          'isChecked': true,
        }),
        isNull,
      );
      expect(
        summary(TaskAgentToolNames.addChecklistItem, {'id': 'cl-1'}),
        isNull,
      );
    });

    test('an update carrying only a title reads as a rename', () {
      expect(
        summary(TaskAgentToolNames.updateChecklistItem, {'title': 'Buy milk'}),
        'Update: "Buy milk"',
      );
    });

    test('a migrated item names the item being moved', () {
      // migrate_checklist_items requires `title` on every element expressly so
      // it can be displayed, which is why this one is reconstructible where an
      // id-only update is not.
      expect(
        summary(TaskAgentToolNames.migrateChecklistItem, {
          'id': 'cl-1',
          'title': 'Buy milk',
        }),
        'Migrate to follow-up: "Buy milk"',
      );
      expect(
        summary(TaskAgentToolNames.migrateChecklistItem, {'id': 'cl-1'}),
        isNull,
      );
    });

    test('label assignment keeps the persisted wording', () {
      // Label elements carry only `id` and `confidence`; the readable name is
      // resolved during the wake, so there is nothing here to rebuild from.
      expect(
        summary(TaskAgentToolNames.assignTaskLabel, {
          'id': 'lbl-1',
          'confidence': 'high',
        }),
        isNull,
      );
    });
  });

  group('the fallback contract', () {
    test(
      'an unknown tool yields null so the caller can use the stored text',
      () {
        expect(summary('some_future_tool', {'x': 1}), isNull);
        expect(summary('', const {}), isNull);
      },
    );

    test('tools with no proposal shape are not invented', () {
      // These are deferred-capable but never render as a proposal row; giving
      // them a summary here would put internal bookkeeping in front of a user.
      for (final tool in [
        TaskAgentToolNames.updateReport,
        TaskAgentToolNames.recordObservations,
        TaskAgentToolNames.retractSuggestions,
      ]) {
        expect(summary(tool, const {}), isNull, reason: '$tool got a summary');
      }
    });
  });

  group('locale', () {
    test('the same tool call reads differently in another language', () {
      // The point of the whole change. Asserting only against English would
      // pass just as well against the hardcoded strings this replaces.
      final english = summary(TaskAgentToolNames.setTaskTitle, {
        'title': 'Ship it',
      });
      final german = summary(TaskAgentToolNames.setTaskTitle, {
        'title': 'Ship it',
      }, messages: de);

      expect(german, isNotNull);
      expect(german, isNot(english));
      // The user's own text is data, not copy — it must survive translation.
      expect(german, contains('Ship it'));
    });

    test(
      'a due date is formatted for the reader, not left as the wire string',
      () {
        // The tool sends YYYY-MM-DD. Rendering that verbatim put an ISO date in a
        // sentence next to task headers that use DateFormat.yMMMd in the active
        // locale.
        const args = {'dueDate': '2026-08-01'};
        final english = summary(TaskAgentToolNames.updateTaskDueDate, args);
        final german = summary(
          TaskAgentToolNames.updateTaskDueDate,
          args,
          messages: de,
        );

        expect(english, isNot(contains('2026-08-01')));
        expect(german, isNot(contains('2026-08-01')));
        expect(german, isNot(english));
        expect(
          german,
          contains(DateFormat.yMMMd('de').format(DateTime(2026, 8))),
        );
      },
    );

    test('an unparseable due date is passed through rather than dropped', () {
      // A malformed value the model sent is still evidence of what it asked
      // for; silently blanking it would hide the mistake.
      expect(
        summary(TaskAgentToolNames.updateTaskDueDate, {
          'dueDate': 'next Tuesday',
        }),
        'Set due date to next Tuesday',
      );
    });

    test('only a date the handler would accept is prettified', () {
      // TaskDueDateHandler takes exactly YYYY-MM-DD encoding a real calendar
      // date. A parseable-but-datetime value would format into a plausible
      // "Aug 1, 2026" for a proposal that rejects on accept — so anything
      // outside the accepted shape stays verbatim, exposing the wire value.
      expect(
        summary(TaskAgentToolNames.updateTaskDueDate, {
          'dueDate': '2026-08-01T12:00:00',
        }),
        'Set due date to 2026-08-01T12:00:00',
      );
      // An overflow date parses (DateTime rolls it into March) but the
      // handler rejects it, so it must not be formatted either.
      expect(
        summary(TaskAgentToolNames.updateTaskDueDate, {
          'dueDate': '2026-02-31',
        }),
        'Set due date to 2026-02-31',
      );
    });

    test('a status value renders as the task UI label, in the locale', () {
      // The wire vocabulary is normalized the way TaskStatusHandler
      // normalizes it, then mapped onto the same taskStatus* labels the task
      // header uses — so a German proposal row and the German status selector
      // agree on what IN PROGRESS is called.
      expect(
        summary(TaskAgentToolNames.setTaskStatus, {'status': 'in progress'}),
        'Set status to In Progress',
      );
      expect(
        summary(TaskAgentToolNames.setTaskStatus, {
          'status': 'ON HOLD',
        }, messages: de),
        contains('Zurückgestellt'),
      );
      // Outside the vocabulary the value passes through verbatim — the
      // model's actual request is evidence, and mapping it would invent a
      // status that does not exist.
      expect(
        summary(TaskAgentToolNames.setTaskStatus, {'status': 'LIMBO'}),
        'Set status to LIMBO',
      );
    });

    test('a relationship sentence is translated, not just reordered', () {
      final blocks = relationshipDirectedOptions.firstWhere(
        (r) => r.type == EntryLinkType.blocks && !r.inverse,
      );

      expect(
        localizedRelationSentence(de, blocks, '"A"'),
        isNot(localizedRelationSentence(en, blocks, '"A"')),
      );
      expect(localizedRelationSentence(de, blocks, '"A"'), contains('"A"'));
    });
  });

  group('goal revision proposals', () {
    test('the structured changes render localized, joined and in order', () {
      final args = {
        'changes': {'targetValue': 8000, 'cadence': 4},
        'rationale': 'ease off',
      };
      expect(
        localizedChangeSummary(en, 'propose_goal_revision', args),
        'Change the target to 8,000 · Change the cadence to 4 — ease off',
      );
      expect(
        localizedChangeSummary(en, 'propose_goal_revision_v2', args),
        'Change the target to 8,000 · Change the cadence to 4 — ease off',
      );
      expect(
        localizedChangeSummary(de, 'propose_goal_revision', args),
        'Zielwert auf 8.000 ändern · Häufigkeit auf 4 ändern — ease off',
      );
    });

    test('tiny fractional targets keep their precision at the gate', () {
      expect(
        localizedChangeSummary(en, 'propose_goal_revision', {
          'changes': {'targetValue': 0.0001},
        }),
        'Change the target to 0.0001',
      );
      // Beyond any fixed fraction cap: falls back to the value's own
      // representation rather than rounding a nonzero target to 0.
      expect(
        localizedChangeSummary(en, 'propose_goal_revision', {
          'changes': {'targetValue': 0.00000000001},
        }),
        'Change the target to 1e-11',
      );
    });

    test('an empty or malformed changes map falls back to the persisted '
        'summary (null)', () {
      expect(
        localizedChangeSummary(en, 'propose_goal_revision', {
          'changes': <String, dynamic>{},
        }),
        isNull,
      );
      expect(
        localizedChangeSummary(en, 'propose_goal_revision', {
          'changes': 'not a map',
        }),
        isNull,
      );
    });

    test('a present metric scopes the target it binds', () {
      // metric is a non-empty string, so the target part gets the
      // "applies to {metric}" suffix appended by scoped().
      expect(
        localizedChangeSummary(en, 'propose_goal_revision', {
          'changes': {'metric': 'steps', 'targetValue': 5000},
        }),
        'Change the target to 5,000 (applies to steps)',
      );
    });

    test('a blank or absent metric leaves the part unscoped', () {
      // Blank (whitespace-only) is treated the same as absent: scoped()
      // must fall to the bare part, not append an empty scope suffix.
      expect(
        localizedChangeSummary(en, 'propose_goal_revision', {
          'changes': {'metric': '   ', 'targetValue': 5000},
        }),
        'Change the target to 5,000',
      );
      expect(
        localizedChangeSummary(en, 'propose_goal_revision', {
          'changes': {'targetValue': 5000},
        }),
        'Change the target to 5,000',
      );
    });

    test('a period change renders the localized window, scoped by metric', () {
      expect(
        localizedChangeSummary(en, 'propose_goal_revision', {
          'changes': {'metric': 'steps', 'period': 'rolling 14 days'},
        }),
        'Change the window to rolling 14 days (applies to steps)',
      );
    });

    test('a non-numeric, unparseable target passes through verbatim', () {
      // Neither `num` nor parseable by `num.tryParse` — must not throw, and
      // must not silently disappear, because it is still evidence of what
      // the model actually asked for.
      expect(
        localizedChangeSummary(en, 'propose_goal_revision', {
          'changes': {'targetValue': 'a lot more'},
        }),
        'Change the target to a lot more',
      );
    });

    test('every _localizedWindow branch renders its own phrase', () {
      // Exercises every arm of parseGoalWindowPhrase's result, plus the
      // verbatim passthrough for a phrase the parser rejects outright.
      const cases = {
        'day': 'Change the window to a single day',
        'rolling 14 days': 'Change the window to rolling 14 days',
        'calendar week': 'Change the window to calendar week',
        'calendar month': 'Change the window to calendar month',
        'once in a blue moon': 'Change the window to once in a blue moon',
      };
      for (final MapEntry(key: phrase, value: expected) in cases.entries) {
        expect(
          localizedChangeSummary(en, 'propose_goal_revision', {
            'changes': {'period': phrase},
          }),
          expected,
          reason: phrase,
        );
      }
    });
  });
}
