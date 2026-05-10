import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/entry_image_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/utils/image_utils.dart';

import '../../../../helpers/fake_entry_controller.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory mockDocumentsDirectory;

  JournalImage buildJournalImage({
    String id = 'image-1',
    String imageFile = 'test.jpg',
    String imageDirectory = '/images/',
  }) {
    final now = DateTime(2025, 12, 31, 12);
    return JournalImage(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: ImageData(
        imageId: 'img-uuid-$id',
        imageFile: imageFile,
        imageDirectory: imageDirectory,
        capturedAt: now,
      ),
    );
  }

  String createInvalidImageFile(JournalImage image) {
    final fullPath = getFullImagePath(image);
    Directory(
      fullPath.substring(0, fullPath.lastIndexOf('/')),
    ).createSync(recursive: true);
    File(fullPath).writeAsBytesSync([0x00, 0x01, 0x02, 0x03]);
    return fullPath;
  }

  group('EntryImageWidget', () {
    setUp(() async {
      mockDocumentsDirectory = Directory.systemTemp.createTempSync(
        'entry_image_widget_test_',
      );
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..registerSingleton<EditorStateService>(MockEditorStateService())
            ..registerSingleton<Directory>(mockDocumentsDirectory);
        },
      );
    });

    tearDown(() async {
      await tearDownTestGetIt();
      try {
        mockDocumentsDirectory.deleteSync(recursive: true);
      } catch (_) {
        // Ignore cleanup errors
      }
    });

    Widget makeSubject(JournalImage image) {
      return ProviderScope(
        overrides: [createEntryControllerOverride(image)],
        child: MaterialApp(
          home: Scaffold(body: EntryImageWidget(image)),
        ),
      );
    }

    testWidgets('decodes via ResizeImage with a positive cacheHeight cap', (
      tester,
    ) async {
      final image = buildJournalImage();
      createInvalidImageFile(image);

      await tester.pumpWidget(makeSubject(image));
      await tester.pump();

      final imageWidget = tester.widget<Image>(find.byType(Image));
      expect(imageWidget.fit, BoxFit.contain);
      expect(imageWidget.errorBuilder, isNotNull);

      // The cacheHeight cap is applied by wrapping the FileImage in a
      // ResizeImage. A bounded height ensures the decoded bitmap stays
      // proportional to display size instead of the source resolution
      // (which can be 10000×10000 per image_utils.compressAndSave limits).
      expect(imageWidget.image, isA<ResizeImage>());
      final resize = imageWidget.image as ResizeImage;
      expect(resize.height, isNotNull);
      expect(resize.height, greaterThan(0));
      expect(resize.imageProvider, isA<FileImage>());
    });

    testWidgets(
      'errorBuilder swaps the failed Image without tearing the tree',
      (tester) async {
        final image = buildJournalImage();
        createInvalidImageFile(image);

        await tester.pumpWidget(makeSubject(image));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Outer scaffolding (GestureDetector → ColoredBox → Hero) must still
        // be in the tree even after the inner Image.file fails to decode the
        // invalid bytes.
        expect(find.byType(EntryImageWidget), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(EntryImageWidget),
            matching: find.byType(Hero),
          ),
          findsOneWidget,
        );
        final hero = tester.widget<Hero>(find.byType(Hero));
        expect(hero.tag, 'entry_img');
      },
    );

    testWidgets(
      'errorBuilder returns SizedBox.shrink and exercises cache eviction',
      (tester) async {
        final image = buildJournalImage();
        createInvalidImageFile(image);

        await tester.pumpWidget(makeSubject(image));
        await tester.pump();

        final imageWidget = tester.widget<Image>(find.byType(Image));
        final builder = imageWidget.errorBuilder!;
        final element = tester.element(find.byType(Image));
        final result = builder(element, Object(), StackTrace.current);

        expect(result, isA<SizedBox>());
        final shrink = result as SizedBox;
        expect(shrink.width, 0.0);
        expect(shrink.height, 0.0);
      },
    );
  });
}
