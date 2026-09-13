part of '../journal_page_controller_test.dart';

void _registerLockdown(JournalControllerTestSetup setup) {
  List<String>? lastTasksCategoryIds() {
    final calls = verify(
      () => setup.mockJournalDb.getTasks(
        ids: any(named: 'ids'),
        starredStatuses: any(named: 'starredStatuses'),
        taskStatuses: any(named: 'taskStatuses'),
        categoryIds: captureAny(named: 'categoryIds'),
        labelIds: any(named: 'labelIds'),
        priorities: any(named: 'priorities'),
        sortByDate: any(named: 'sortByDate'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).captured;
    return calls.isEmpty ? null : (calls.last as List<String>?);
  }

  test('entering lockdown re-queries with only the locked category and '
      'shows it as the selection; the persisted filter stays untouched', () {
    fakeAsync((async) {
      final controller = setup.container.read(
        journalPageControllerProvider(true).notifier,
      );
      settle(async);
      // The user's own filter picks a category outside the lock.
      unawaited(
        controller.applyBatchFilterUpdate(categoryIds: {'health'}),
      );
      settle(async);
      expect(
        setup.container
            .read(journalPageControllerProvider(true))
            .selectedCategoryIds,
        {'health'},
      );
      lastTasksCategoryIds(); // drain the calls made so far

      setup.container
          .read(lockdownControllerProvider.notifier)
          .lockToCategory('work');
      settle(async);

      expect(lastTasksCategoryIds(), ['work']);
      expect(
        setup.container
            .read(journalPageControllerProvider(true))
            .selectedCategoryIds,
        {'work'},
      );

      setup.container.read(lockdownControllerProvider.notifier).clear();
      settle(async);

      expect(lastTasksCategoryIds(), ['health']);
      expect(
        setup.container
            .read(journalPageControllerProvider(true))
            .selectedCategoryIds,
        {'health'},
      );
    });
  });

  test('category edits made while locked down do not touch the raw '
      'selection, so exiting restores the pre-lockdown filter', () {
    fakeAsync((async) {
      final controller = setup.container.read(
        journalPageControllerProvider(true).notifier,
      );
      settle(async);
      unawaited(
        controller.applyBatchFilterUpdate(categoryIds: {'health'}),
      );
      settle(async);

      setup.container
          .read(lockdownControllerProvider.notifier)
          .lockToCategory('work');
      settle(async);
      // The filter sheet re-applies what it was seeded with (the effective
      // scope) on Apply, and chips toggle — neither may leak into the raw
      // selection.
      unawaited(
        controller.applyBatchFilterUpdate(
          categoryIds: {'work'},
          statuses: {'OPEN'},
        ),
      );
      unawaited(controller.toggleSelectedCategoryIds('other'));
      settle(async);
      expect(
        setup.container
            .read(journalPageControllerProvider(true))
            .selectedCategoryIds,
        {'work'},
      );

      setup.container.read(lockdownControllerProvider.notifier).clear();
      settle(async);

      expect(
        setup.container
            .read(journalPageControllerProvider(true))
            .selectedCategoryIds,
        {'health'},
      );
      expect(lastTasksCategoryIds(), ['health']);
    });
  });

  test(
    'under lockdown an empty selection never expands to all categories',
    () {
      fakeAsync((async) {
        setup.container
            .read(lockdownControllerProvider.notifier)
            .lockToCategory('work');
        setup.container.read(journalPageControllerProvider(true));
        settle(async);

        expect(lastTasksCategoryIds(), ['work']);
      });
    },
  );
}
