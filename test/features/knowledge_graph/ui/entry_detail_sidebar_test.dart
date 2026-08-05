import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/knowledge_graph/ui/entry_detail_sidebar.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

class _ControlledEntryController extends EntryController {
  _ControlledEntryController(this.load);

  final Future<EntryState?> Function() load;

  @override
  Future<EntryState?> build() => load();
}

void main() {
  setUp(() async {
    await setUpTestGetIt(
      additionalSetup: () {
        getIt.registerSingleton<EditorStateService>(MockEditorStateService());
      },
    );
  });

  tearDown(tearDownTestGetIt);

  testWidgets(
    'keeps established details visible during reload and reload failure',
    (tester) async {
      final reload = Completer<EntryState?>();
      var builds = 0;
      Future<EntryState?> load() {
        builds++;
        return builds == 1 ? Future.value() : reload.future;
      }

      final result = makeTestableWidgetWithContainer(
        EntryDetailSidebar(
          entryId: 'entry-1',
          onClose: () {},
          tokens: dsTokensDark,
        ),
        overrides: [
          entryControllerProvider(
            'entry-1',
          ).overrideWith(() => _ControlledEntryController(load)),
        ],
      );
      addTearDown(result.container.dispose);

      await tester.pumpWidget(result.widget);
      await tester.pump();
      expect(find.text('Entry not found'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      result.container.invalidate(entryControllerProvider('entry-1'));
      await tester.pump();
      expect(builds, 2);
      expect(find.text('Entry not found'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      final providerFuture = result.container.read(
        entryControllerProvider('entry-1').future,
      );
      await tester.runAsync(() async {
        reload.completeError(StateError('reload failed'), StackTrace.current);
        await providerFuture.then<void>((_) {}, onError: (_) {});
      });
      await tester.pump();

      expect(find.text('Entry not found'), findsOneWidget);
      expect(find.text("Couldn't load this entry"), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
