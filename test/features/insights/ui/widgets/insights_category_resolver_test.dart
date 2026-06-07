import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/insights/model/insights_models.dart';
import 'package:lotti/features/insights/ui/widgets/insights_category_resolver.dart';

import '../../../categories/test_utils.dart';

void main() {
  final resolver = InsightsCategoryResolver(
    categoriesById: {
      'cat-1': CategoryTestUtils.createTestCategory(
        id: 'cat-1',
        name: 'Client Work',
        color: '#3B82F6',
      ),
    },
    uncategorizedLabel: 'Uncategorized',
    otherLabel: 'Other',
    deletedLabel: 'Deleted category',
  );

  test('resolves known categories to their name and color', () {
    expect(resolver.labelFor('cat-1'), 'Client Work');
    expect(resolver.colorHexFor('cat-1'), '#3B82F6');
  });

  test('null key resolves to the uncategorized label with no color', () {
    expect(resolver.labelFor(null), 'Uncategorized');
    expect(resolver.colorHexFor(null), isNull);
  });

  test('the Other sentinel resolves to its label with no color', () {
    expect(resolver.labelFor(kInsightsOtherCategoryKey), 'Other');
    expect(resolver.colorHexFor(kInsightsOtherCategoryKey), isNull);
  });

  test('unknown ids resolve to the deleted label — never a raw UUID', () {
    expect(resolver.labelFor('gone-uuid'), 'Deleted category');
    expect(resolver.colorHexFor('gone-uuid'), isNull);
  });
}
