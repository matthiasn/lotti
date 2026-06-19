import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/events/ui/pages/event_detail_page.dart';
import 'package:lotti/features/journal/model/entry_state.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';

import '../../../../widget_test_utils.dart';

const _eventId = 'event-1';

/// Yields `null` for `entryControllerProvider` to exercise the page's
/// not-yet-resolved (loading) branch. The resolved branch is covered by the
/// pure mapping tests, the `EventDetailView` widget tests, and the events
/// controller test.
class _NullEntryController extends EntryController {
  @override
  Future<EntryState?> build({required String id}) async => null;
}

void main() {
  testWidgets('shows a loading indicator until the event resolves', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryControllerProvider(
            id: _eventId,
          ).overrideWith(_NullEntryController.new),
        ],
        child: makeTestableWidget2(const EventDetailPage(eventId: _eventId)),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
