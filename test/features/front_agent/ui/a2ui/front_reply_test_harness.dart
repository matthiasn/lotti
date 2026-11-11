import 'package:a2ui_flutter/a2ui_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/front_agent/model/front_entity_preview.dart';
import 'package:lotti/features/front_agent/model/front_reply_surface.dart';
import 'package:lotti/features/front_agent/state/front_entity_preview_provider.dart';
import 'package:lotti/features/front_agent/ui/a2ui/front_reply_catalog.dart';
import 'package:lotti/features/front_agent/ui/a2ui/front_reply_surfaces.dart';
import 'package:lotti/features/tasks/state/task_preview_provider.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

/// What the surfaces under test asked the chat to do.
class FrontReplyTaps {
  final opened = <FrontEntityReference>[];
  final openedTasks = <String>[];
  final quickReplies = <String>[];
}

/// Pumps the replies of [surfaces] — by reply id — as a thread does: one
/// [FrontReplySurfaces] over them, each drawn in its [FrontReplyScope],
/// which draws her words as `words: <markdown>` and records taps in [taps].
/// A reply with no live surface is drawn as `no surface: <id>`. No entity
/// loads, so each card keeps the title it was given.
Future<void> pumpReplySurfaces(
  WidgetTester tester,
  Map<String, FrontReplySurface> surfaces, {
  required FrontReplyTaps taps,
  DomainLogger? logger,
  Set<String> shownIds = const {},
  bool canReply = true,
}) async {
  await setUpTestGetIt();
  addTearDown(tearDownTestGetIt);
  await tester.pumpWidget(
    makeTestableWidgetNoScroll(
      Scaffold(
        body: SingleChildScrollView(
          child: FrontReplySurfaces(
            surfaces: surfaces,
            logger: logger ?? MockDomainLogger(),
            onQuickReply: taps.quickReplies.add,
            child: Builder(
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final id in surfaces.keys)
                    switch (FrontReplySurfaces.surfaceOf(context, id)) {
                      null => Text('no surface: $id'),
                      final surface => FrontReplyScope(
                        surface: surface,
                        prose: (markdown) => Text('words: $markdown'),
                        onOpen: taps.opened.add,
                        onOpenTask: taps.openedTasks.add,
                        shownIds: shownIds,
                        canReply: canReply,
                        child: A2uiSurface(
                          key: ObjectKey(surface),
                          surface: surface,
                        ),
                      ),
                    },
                ],
              ),
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
