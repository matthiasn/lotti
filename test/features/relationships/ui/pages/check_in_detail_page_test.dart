import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/pages/check_in_detail_page.dart';
import 'package:lotti/features/relationships/ui/widgets/check_in_detail_view.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../test_data/test_data.dart';
import '../../../../widget_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  testWidgets('shows the check-in on its own page and leads back to the '
      'person', (tester) async {
    final repository = MockRelationshipRepository();
    when(
      () => repository.getRelationshipById(any()),
    ).thenAnswer((_) async => testRelationship);
    when(
      () => repository.getCheckInsForRelationship(any()),
    ).thenAnswer((_) async => []);
    when(
      () => repository.getEntriesForCheckIns(any()),
    ).thenAnswer((_) async => const {});
    when(() => repository.getLinkedTasks(any())).thenAnswer((_) async => []);
    final navigated = <String>[];
    beamToNamedOverride = navigated.add;
    addTearDown(() => beamToNamedOverride = null);

    await tester.pumpWidget(
      makeTestableWidgetNoScroll(
        const CheckInDetailPage(relationshipId: 'rel-001', checkInId: 'c-1'),
        overrides: [
          relationshipRepositoryProvider.overrideWithValue(repository),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final view = tester.widget<CheckInDetailView>(
      find.byType(CheckInDetailView),
    );
    expect((view.relationshipId, view.checkInId), ('rel-001', 'c-1'));

    await tester.tap(find.byKey(const ValueKey('check-in-detail-back')));

    expect(navigated, ['/people/rel-001']);
  });
}
