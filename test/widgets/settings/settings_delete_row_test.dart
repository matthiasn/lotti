import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/settings/settings_delete_row.dart';

import '../../test_helper.dart';

void main() {
  testWidgets('renders the label with the delete glyph and fires on tap', (
    tester,
  ) async {
    var deleted = false;
    await tester.pumpWidget(
      WidgetTestBench(
        child: SettingsDeleteRow(
          label: 'Delete category',
          onTap: () => deleted = true,
        ),
      ),
    );

    expect(find.text('Delete category'), findsOneWidget);
    expect(find.byIcon(LottiIcons.delete), findsOneWidget);

    await tester.tap(find.text('Delete category'));
    expect(deleted, isTrue);
  });

  testWidgets('disabled row ignores taps', (tester) async {
    var deleted = false;
    await tester.pumpWidget(
      WidgetTestBench(
        child: SettingsDeleteRow(
          label: 'Delete category',
          enabled: false,
          onTap: () => deleted = true,
        ),
      ),
    );

    await tester.tap(find.text('Delete category'));
    expect(deleted, isFalse);
  });
}
