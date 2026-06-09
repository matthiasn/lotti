part of 'change_set_builder.dart';

ChangeSetEntity _retireConsolidatedSet(ChangeSetEntity set) {
  return set.copyWith(
    items: [
      for (final item in set.items)
        item.status == ChangeItemStatus.pending
            ? item.copyWith(status: ChangeItemStatus.retracted)
            : item,
    ],
    status: ChangeSetStatus.resolved,
    resolvedAt: clock.now(),
  );
}
