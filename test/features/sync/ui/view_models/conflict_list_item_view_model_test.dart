import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/checklist_data.dart';
import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/event_data.dart';
import 'package:lotti/classes/event_status.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/sync/ui/view_models/conflict_list_item_view_model.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

typedef _Captured = ({ConflictListItemViewModel viewModel, BuildContext ctx});

Future<_Captured> _pumpAndBuild(
  WidgetTester tester, {
  required Conflict conflict,
}) async {
  late ConflictListItemViewModel viewModel;
  late BuildContext capturedContext;

  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Builder(
        builder: (context) {
          capturedContext = context;
          viewModel = ConflictListItemViewModel.fromConflict(
            context: context,
            conflict: conflict,
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pump();

  return (viewModel: viewModel, ctx: capturedContext);
}

Conflict _conflict({
  required String id,
  required ConflictStatus status,
  required String serializedJson,
  DateTime? createdAt,
}) {
  final ts = createdAt ?? DateTime(2024, 3, 15, 12, 30);
  return Conflict(
    id: id,
    createdAt: ts,
    updatedAt: ts,
    serialized: serializedJson,
    schemaVersion: 1,
    status: status.index,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConflictListItemViewModel', () {
    testWidgets(
      'resolved conflict produces success tone and capitalized label',
      (tester) async {
        final result = await _pumpAndBuild(
          tester,
          conflict: _conflict(
            id: 'resolved-id',
            status: ConflictStatus.resolved,
            serializedJson: jsonEncode(testWorkoutRunning.toJson()),
          ),
        );

        expect(result.viewModel.statusTone, ConflictStatusTone.resolved);
        expect(result.viewModel.statusLabel, 'Resolved');
        expect(
          result.viewModel.entityLabel,
          result.ctx.messages.entryTypeLabelWorkoutEntry,
        );
      },
    );

    testWidgets('unresolved conflict produces unresolved tone', (tester) async {
      final result = await _pumpAndBuild(
        tester,
        conflict: _conflict(
          id: 'unresolved-id',
          status: ConflictStatus.unresolved,
          serializedJson: jsonEncode(testTextEntry.toJson()),
        ),
      );

      expect(result.viewModel.statusTone, ConflictStatusTone.unresolved);
      expect(result.viewModel.statusLabel, 'Unresolved');
    });

    testWidgets('conflictIdShort truncates ids longer than 8 chars', (
      tester,
    ) async {
      final result = await _pumpAndBuild(
        tester,
        conflict: _conflict(
          id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
          status: ConflictStatus.unresolved,
          serializedJson: jsonEncode(testTextEntry.toJson()),
        ),
      );

      expect(result.viewModel.conflictIdShort, 'a1b2c3d4');
      expect(result.viewModel.conflictIdShort.length, 8);
      expect(
        result.viewModel.conflictIdFull,
        'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
      );
    });

    testWidgets('conflictIdShort returns the full id when shorter than 8', (
      tester,
    ) async {
      final result = await _pumpAndBuild(
        tester,
        conflict: _conflict(
          id: 'id',
          status: ConflictStatus.unresolved,
          serializedJson: jsonEncode(testTextEntry.toJson()),
        ),
      );

      expect(result.viewModel.conflictIdShort, 'id');
      expect(result.viewModel.conflictIdFull, 'id');
    });

    testWidgets(
      'semanticsLabel contains status, timestamp, entity, and full id',
      (tester) async {
        final result = await _pumpAndBuild(
          tester,
          conflict: _conflict(
            id: 'a1b2c3d4-e5f6-7890-abcd-ef1234567890',
            status: ConflictStatus.unresolved,
            serializedJson: jsonEncode(testTextEntry.toJson()),
          ),
        );

        expect(result.viewModel.semanticsLabel, contains('Unresolved'));
        expect(
          result.viewModel.semanticsLabel,
          contains(result.viewModel.timestampLabel),
        );
        expect(
          result.viewModel.semanticsLabel,
          contains(result.viewModel.entityLabel),
        );
        expect(
          result.viewModel.semanticsLabel,
          contains('a1b2c3d4-e5f6-7890-abcd-ef1234567890'),
        );
      },
    );

    testWidgets('entity label resolves to the localized type name', (
      tester,
    ) async {
      // Every entry in the impl's _entityLabel map — all 13 types.
      final now = DateTime(2024, 3, 15);
      final meta = Metadata(
        id: 'label-entity',
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      );
      final cases = <(dynamic, String Function(BuildContext))>[
        (testTextEntry, (c) => c.messages.entryTypeLabelJournalEntry),
        (testTask, (c) => c.messages.entryTypeLabelTask),
        (testAudioEntry, (c) => c.messages.entryTypeLabelJournalAudio),
        (testWorkoutRunning, (c) => c.messages.entryTypeLabelWorkoutEntry),
        (testWeightEntry, (c) => c.messages.entryTypeLabelQuantitativeEntry),
        (testImageEntry, (c) => c.messages.entryTypeLabelJournalImage),
        (
          testMeasurementChocolateEntry,
          (c) => c.messages.entryTypeLabelMeasurementEntry,
        ),
        (
          testHabitCompletionEntry,
          (c) => c.messages.entryTypeLabelHabitCompletionEntry,
        ),
        (
          JournalEntity.event(
            meta: meta,
            data: const EventData(
              status: EventStatus.tentative,
              title: 'Event',
              stars: 0,
            ),
          ),
          (c) => c.messages.entryTypeLabelJournalEvent,
        ),
        (
          JournalEntity.checklist(
            meta: meta,
            data: const ChecklistData(
              title: 'Checklist',
              linkedChecklistItems: [],
              linkedTasks: [],
            ),
          ),
          (c) => c.messages.entryTypeLabelChecklist,
        ),
        (
          JournalEntity.checklistItem(
            meta: meta,
            data: const ChecklistItemData(
              title: 'Item',
              isChecked: false,
              linkedChecklists: [],
            ),
          ),
          (c) => c.messages.entryTypeLabelChecklistItem,
        ),
        (
          JournalEntity.aiResponse(
            meta: meta,
            data: const AiResponseData(
              model: 'm',
              systemMessage: '',
              prompt: '',
              thoughts: '',
              response: '',
            ),
          ),
          (c) => c.messages.entryTypeLabelAiResponse,
        ),
        (
          JournalEntity.survey(
            meta: meta,
            data: fallbackSurveyData,
          ),
          (c) => c.messages.entryTypeLabelSurveyEntry,
        ),
      ];

      for (final (entity, expectedLabel) in cases) {
        final dynamic entityDyn = entity;
        final result = await _pumpAndBuild(
          tester,
          conflict: _conflict(
            id: 'id',
            status: ConflictStatus.unresolved,
            // ignore: avoid_dynamic_calls
            serializedJson: jsonEncode(entityDyn.toJson()),
          ),
        );

        expect(
          result.viewModel.entityLabel,
          expectedLabel(result.ctx),
          reason: 'mismatch for ${entity.runtimeType}',
        );
      }
    });
  });

  group('shortenConflictId — Glados property', () {
    glados.Glados<String>(
      glados.any.letterOrDigits,
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'ids of 8 chars or fewer pass through; longer ids truncate to the '
      'first 8',
      (id) {
        final short = ConflictListItemViewModel.shortenConflictId(id);
        if (id.length <= 8) {
          expect(short, id);
        } else {
          expect(short.length, 8);
          expect(short, id.substring(0, 8));
          expect(id, startsWith(short));
        }
      },
      tags: 'glados',
    );
  });
}
