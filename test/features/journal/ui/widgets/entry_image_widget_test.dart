import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/entry_image_widget.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:photo_view/photo_view.dart';

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
      return makeTestableWidget(
        EntryImageWidget(image),
        overrides: [createEntryControllerOverride(image)],
        mediaQueryData: phoneMediaQueryData.copyWith(devicePixelRatio: 3),
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

      // Both axes are capped via ResizeImage so extreme aspect ratios —
      // e.g. panoramas — can't balloon along the unconstrained axis. Source
      // images can be up to 10000×10000 per image_utils.compressAndSave
      // limits. ResizeImagePolicy.fit keeps the source aspect ratio at
      // decode time so the displayed bitmap isn't squashed.
      expect(imageWidget.image, isA<ResizeImage>());
      final resize = imageWidget.image as ResizeImage;
      expect(resize.width, isNotNull);
      expect(resize.width, greaterThan(0));
      expect(resize.height, isNotNull);
      expect(resize.height, greaterThan(0));
      expect(resize.policy, ResizeImagePolicy.fit);
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

    testWidgets(
      'tapping the image pushes HeroPhotoViewRouteWrapper onto the navigator',
      (tester) async {
        final image = buildJournalImage();
        createInvalidImageFile(image);

        // Wrap in a fixed-size container so the GestureDetector has non-zero
        // area to receive the tap even though the inner Image collapses on
        // error.
        final subject = ProviderScope(
          overrides: [createEntryControllerOverride(image)],
          child: MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 390,
                height: 400,
                child: EntryImageWidget(image),
              ),
            ),
          ),
        );

        await tester.pumpWidget(subject);
        await tester.pump();

        // Before tap, only EntryImageWidget is in the tree.
        expect(find.byType(HeroPhotoViewRouteWrapper), findsNothing);

        await tester.ensureVisible(find.byType(GestureDetector).first);
        await tester.tap(find.byType(GestureDetector).first);
        // One pump to schedule the route push, one more to build the new route.
        await tester.pump();
        await tester.pump();

        // After navigation, HeroPhotoViewRouteWrapper should be rendered.
        expect(find.byType(HeroPhotoViewRouteWrapper), findsOneWidget);
        // The close icon from the wrapper should be visible.
        expect(find.byIcon(Icons.close_rounded), findsWidgets);
      },
    );
  });

  group('HeroPhotoViewRouteWrapper', () {
    late Directory tempDir;
    late File imageFile;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync(
        'hero_photo_view_test_',
      );
      imageFile = File('${tempDir.path}/photo.jpg')
        ..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xE0]);
    });

    tearDown(() async {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // Ignore cleanup errors.
      }
    });

    Widget buildWrapper({BoxDecoration? backgroundDecoration}) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: HeroPhotoViewRouteWrapper(
            file: imageFile,
            backgroundDecoration: backgroundDecoration,
          ),
        ),
      );
    }

    testWidgets(
      'renders Scaffold with PhotoView and close IconButton',
      (tester) async {
        await tester.pumpWidget(buildWrapper());
        await tester.pump();

        // Scaffold body must be present.
        expect(find.byType(Scaffold), findsOneWidget);

        // PhotoView carries the hero tag for the shared-element transition.
        expect(find.byType(PhotoView), findsOneWidget);
        final photoView = tester.widget<PhotoView>(find.byType(PhotoView));
        expect(photoView.imageProvider, isA<FileImage>());
        expect(photoView.minScale, PhotoViewComputedScale.contained);
        expect(
          photoView.heroAttributes?.tag,
          'entry_img',
        );

        // Close button is rendered in the top-right Positioned widget.
        expect(find.byType(IconButton), findsOneWidget);
        // Two close icons: one blurred behind, one white on top.
        expect(find.byIcon(Icons.close_rounded), findsNWidgets(2));
      },
    );

    testWidgets(
      'passes backgroundDecoration to PhotoView when provided',
      (tester) async {
        const decoration = BoxDecoration(color: Colors.red);
        await tester.pumpWidget(buildWrapper(backgroundDecoration: decoration));
        await tester.pump();

        final photoView = tester.widget<PhotoView>(find.byType(PhotoView));
        expect(photoView.backgroundDecoration, decoration);
      },
    );

    testWidgets(
      'close button pops the route when tapped',
      (tester) async {
        // The close IconButton has padding: EdgeInsets.all(48); use a large
        // viewport so its hit target falls within bounds.
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        // Push HeroPhotoViewRouteWrapper so there is a route beneath it to
        // pop back to.
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(
                builder: (context) {
                  return Scaffold(
                    body: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute<void>(
                            builder: (_) => HeroPhotoViewRouteWrapper(
                              file: imageFile,
                            ),
                          ),
                        );
                      },
                      child: const Text('Open'),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump();

        // Push the wrapper route.
        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump();

        // Wrapper is visible.
        expect(find.byType(HeroPhotoViewRouteWrapper), findsOneWidget);

        // Invoke the close button's onPressed callback directly to avoid
        // off-screen hit-testing issues caused by the large 48px padding on
        // the Positioned close button.
        final iconButton = tester.widget<IconButton>(find.byType(IconButton));
        iconButton.onPressed?.call();
        await tester.pump();
        await tester.pump();

        // The wrapper route has been popped.
        expect(find.byType(HeroPhotoViewRouteWrapper), findsNothing);
        // We're back on the home screen.
        expect(find.text('Open'), findsOneWidget);
      },
    );

    testWidgets(
      'FileImage is constructed from the provided file',
      (tester) async {
        await tester.pumpWidget(buildWrapper());
        await tester.pump();

        final photoView = tester.widget<PhotoView>(find.byType(PhotoView));
        final fileImage = photoView.imageProvider! as FileImage;
        expect(fileImage.file.path, imageFile.path);
      },
    );
  });
}
