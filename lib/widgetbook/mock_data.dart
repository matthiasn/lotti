import 'package:lotti/classes/checklist_item_data.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/utils/file_utils.dart';

final checklistItem1 = ChecklistItem(
  meta: createMetadata(uuid.v4()),
  data: const ChecklistItemData(
    title: 'Create PR',
    isChecked: true,
    linkedChecklists: [],
  ),
);

final checklistItem2 = ChecklistItem(
  meta: createMetadata(uuid.v4()),
  data: const ChecklistItemData(
    title: 'release iOS',
    isChecked: true,
    linkedChecklists: [],
  ),
);

final checklistItem3 = ChecklistItem(
  meta: createMetadata(uuid.v4()),
  data: const ChecklistItemData(
    title: 'release macOS',
    isChecked: false,
    linkedChecklists: [],
  ),
);

final checklistItem4 = ChecklistItem(
  meta: createMetadata(uuid.v4()),
  data: const ChecklistItemData(
    title: 'merge PR',
    isChecked: false,
    linkedChecklists: [],
  ),
);

Metadata createMetadata(String id) {
  final now = DateTime.now();
  return Metadata(
    id: id,
    createdAt: now,
    updatedAt: now,
    dateFrom: now,
    dateTo: now,
  );
}
