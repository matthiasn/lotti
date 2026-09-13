// ignore_for_file: cascade_invocations

part of '../journal_page_controller_test.dart';

void _registerVisibilityEdges(JournalControllerTestSetup setup) {
  group('Visibility Edge Cases', () {
    test('does not refresh when transitioning from visible to invisible', () {
      fakeAsync((async) {
        var queryCount = 0;
        when(
          () => setup.mockJournalDb.getJournalEntities(
            types: any(named: 'types'),
            starredStatuses: any(named: 'starredStatuses'),
            privateStatuses: any(named: 'privateStatuses'),
            flaggedStatuses: any(named: 'flaggedStatuses'),
            ids: any(named: 'ids'),
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
            categoryIds: any(named: 'categoryIds'),
          ),
        ).thenAnswer((_) async {
          queryCount++;
          return [];
        });

        final controller = setup.container.read(
          journalPageControllerProvider(false).notifier,
        );

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // Make visible first
        _emitVisibility(setup, controller, isVisible: true);

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        final visibleCount = queryCount;

        // Now make invisible
        _emitVisibility(setup, controller, isVisible: false);

        async.elapse(const Duration(milliseconds: 100));
        async.flushMicrotasks();

        // Query count should not increase when becoming invisible
        expect(queryCount, equals(visibleCount));
      });
    });
  });
}
