import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/file_uploads/design_system_file_upload.dart';
import 'package:lotti/features/design_system/widgetbook/design_system_file_upload_widgetbook.dart';

import 'widgetbook_test_helpers.dart';

void main() {
  group('buildDesignSystemFileUploadWidgetbookComponent', () {
    testWidgets('renders the overview page with all variants', (
      tester,
    ) async {
      await pumpWidgetbookOverview(
        tester,
        buildDesignSystemFileUploadWidgetbookComponent(),
        expectedName: 'File upload',
      );

      // Drop zone section
      expect(find.textContaining('Drop Zone'), findsOneWidget);
      expect(find.textContaining('Click to upload'), findsAtLeast(1));
      expect(find.textContaining('or drag and drop'), findsAtLeast(1));

      // File items section
      expect(find.textContaining('File Items'), findsOneWidget);
      expect(find.text('Game_of_throne.png'), findsAtLeast(1));
      expect(find.text('200 KB'), findsAtLeast(1));

      // Verify all drop zone states rendered
      expect(
        find.byType(DesignSystemFileUploadDropZone),
        findsNWidgets(3),
      );

      // Verify all file item states rendered
      expect(
        find.byType(DesignSystemFileUploadItem),
        findsNWidgets(3),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
