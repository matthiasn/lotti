import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/state/front_entity_preview_provider.dart';
import 'package:lotti/features/front_agent/ui/genui/front_reply_catalog.dart';
import 'package:lotti/features/front_agent/ui/genui/front_reply_surface.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

/// What a reply surface's scope was asked to do.
class FrontReplyTaps {
  final opened = <FrontEntityReference>[];
  final openedTasks = <String>[];
}

/// Pumps one reply surface of [components] under a scope that draws her
/// words as `words: <markdown>` and records taps in [taps]. No entity
/// loads, so each card keeps the title it was given.
Future<void> pumpReplySurface(
  WidgetTester tester,
  List<Map<String, Object?>> components, {
  required FrontReplyTaps taps,
  String surfaceId = 'a1',
}) async {
  await setUpTestGetIt();
  addTearDown(tearDownTestGetIt);
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Scaffold(
        body: SingleChildScrollView(
          child: FrontReplyScope(
            prose: (markdown) => Text('words: $markdown'),
            onOpen: taps.opened.add,
            onOpenTask: taps.openedTasks.add,
            child: FrontReplySurface(
              key: ValueKey('surface-$surfaceId'),
              surfaceId: surfaceId,
              components: components,
            ),
          ),
        ),
      ),
      overrides: [
        frontEntityPreviewProvider.overrideWith((ref, key) async => null),
        taskPreviewProvider.overrideWith((ref, id) async => null),
      ],
    ),
  );
  await tester.pump();
}
