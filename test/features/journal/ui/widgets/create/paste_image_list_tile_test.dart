import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/repository/clipboard_repository.dart';
import 'package:lotti/features/journal/ui/widgets/create/paste_image_list_tile.dart';
import 'package:mocktail/mocktail.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../../../../test_helper.dart';

class MockSystemClipboard extends Mock implements SystemClipboard {}

class MockClipboardReader extends Mock implements ClipboardReader {}

void main() {
  late MockSystemClipboard mockClipboard;
  late MockClipboardReader mockReader;

  setUp(() {
    mockClipboard = MockSystemClipboard();
    mockReader = MockClipboardReader();

    when(() => mockClipboard.read()).thenAnswer((_) async => mockReader);
  });

  testWidgets('PasteImageListTile shows when image is available',
      (tester) async {
    when(() => mockReader.canProvide(Formats.png)).thenReturn(true);
    when(() => mockReader.canProvide(Formats.jpeg)).thenReturn(false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clipboardRepositoryProvider.overrideWithValue(mockClipboard),
        ],
        child: const WidgetTestBench(
          child: Material(
            child: PasteImageListTile(
              'testId',
              categoryId: 'testCategory',
            ),
          ),
        ),
      ),
    );

    // Wait for async operations to complete
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsOneWidget);
    expect(find.byIcon(Icons.paste), findsOneWidget);
  });

  testWidgets('PasteImageListTile hides when no image is available',
      (tester) async {
    when(() => mockReader.canProvide(Formats.png)).thenReturn(false);
    when(() => mockReader.canProvide(Formats.jpeg)).thenReturn(false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clipboardRepositoryProvider.overrideWithValue(mockClipboard),
        ],
        child: const WidgetTestBench(
          child: Material(
            child: PasteImageListTile(
              'testId',
              categoryId: 'testCategory',
            ),
          ),
        ),
      ),
    );

    // Wait for async operations to complete
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNothing);
    expect(find.byIcon(Icons.paste), findsNothing);
  });

  testWidgets('PasteImageListTile handles tap correctly', (tester) async {
    when(() => mockReader.canProvide(Formats.png)).thenReturn(true);
    when(() => mockReader.canProvide(Formats.jpeg)).thenReturn(false);

    // Mock the file reading part
    when(() => mockReader.getFile(Formats.png, any())).thenAnswer((_) => null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clipboardRepositoryProvider.overrideWithValue(mockClipboard),
        ],
        child: WidgetTestBench(
          child: Navigator(
            onGenerateRoute: (settings) {
              return MaterialPageRoute<void>(
                builder: (context) => const Material(
                  child: PasteImageListTile(
                    'testId',
                    categoryId: 'testCategory',
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify the ListTile is shown
    expect(find.byType(ListTile), findsOneWidget);

    // Tap the ListTile
    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    // Verify that Navigator.pop was called (widget is no longer visible)
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('PasteImageListTile hides when clipboard is null',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          clipboardRepositoryProvider.overrideWithValue(null),
        ],
        child: const WidgetTestBench(
          child: Material(
            child: PasteImageListTile(
              'testId',
              categoryId: 'testCategory',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNothing);
    expect(find.byIcon(Icons.paste), findsNothing);
  });
}
