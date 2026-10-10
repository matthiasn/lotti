import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu.dart';
import 'package:lotti/features/design_system/components/context_menus/design_system_context_menu_anchor.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/github/service/pull_request_image_fetcher.dart';
import 'package:lotti/features/github/state/github_providers.dart';
import 'package:lotti/features/github/ui/pull_request_image.dart';
import 'package:lotti/features/journal/ui/widgets/entry_image_widget.dart';
import 'package:lotti/widgets/markdown/agent_markdown_view.dart';
import 'package:lotti/widgets/markdown_link_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

/// A one-pixel PNG: enough for the image to decode.
final Uint8List onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  const url = 'https://pub-example.r2.dev/shots/desktop-dark.png';
  const taskId = 'task-1';

  late MockPullRequestImageFetcher fetcher;
  late MockPullRequestImageAttacher attacher;

  setUpAll(registerAllFallbackValues);

  setUp(() {
    fetcher = MockPullRequestImageFetcher();
    attacher = MockPullRequestImageAttacher();
    when(() => fetcher.cached(any())).thenReturn(null);
  });

  Future<void> pump(WidgetTester tester, {Widget? child}) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        child ?? const PullRequestImage(url: url, taskId: taskId),
        overrides: [
          pullRequestImageFetcherProvider.overrideWithValue(fetcher),
          pullRequestImageAttacherProvider.overrideWithValue(attacher),
        ],
      ),
    );
    await tester.pump();
  }

  /// The bytes the shown [Image] draws.
  Uint8List shownBytes(WidgetTester tester) =>
      (tester.widget<Image>(find.byType(Image)).image as MemoryImage).bytes;

  Future<void> rightClick(WidgetTester tester) async {
    await tester.tapAt(
      tester.getCenter(find.byType(Image)),
      buttons: kSecondaryButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows a loading box, then the fetched image', (tester) async {
    final gate = Completer<Uint8List>();
    when(() => fetcher.fetch(url)).thenAnswer((_) => gate.future);
    await pump(tester);

    expect(find.byType(Image), findsNothing);
    expect(
      find.bySemanticsLabel('Loading image from pub-example.r2.dev'),
      findsOneWidget,
    );

    gate.complete(onePixelPng);
    await tester.pump();

    expect(shownBytes(tester), onePixelPng);
    expect(find.bySemanticsLabel(RegExp('Loading image')), findsNothing);
    expect(find.byType(MarkdownImageNotice), findsNothing);
  });

  testWidgets('an image fetched before is shown at once', (tester) async {
    when(() => fetcher.cached(url)).thenReturn(onePixelPng);
    await pump(tester);

    expect(shownBytes(tester), onePixelPng);
    verifyNever(() => fetcher.fetch(any()));
  });

  testWidgets('an image that cannot be fetched says so, naming its host', (
    tester,
  ) async {
    when(() => fetcher.fetch(url)).thenAnswer(
      (_) async => throw const PullRequestImageException(
        PullRequestImageFailure.status,
        url,
      ),
    );
    await pump(tester);
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(
      find.text("Couldn't load image from pub-example.r2.dev"),
      findsOneWidget,
    );
    expect(find.byIcon(LottiIcons.imageBroken), findsOneWidget);
  });

  testWidgets('bytes that are not an image say so in place of it', (
    tester,
  ) async {
    when(() => fetcher.fetch(url)).thenAnswer(
      (_) async => Uint8List.fromList('<svg/>'.codeUnits),
    );
    await pump(tester);
    // The decode fails off the frame; the error builder takes over.
    await tester.pump();
    await tester.pump();

    expect(
      find.text("Couldn't load image from pub-example.r2.dev"),
      findsOneWidget,
    );
  });

  testWidgets('a tap opens the image full size in the viewer', (tester) async {
    when(() => fetcher.fetch(url)).thenAnswer((_) async => onePixelPng);
    await pump(tester);
    await tester.pump();

    expect(find.byType(HeroPhotoViewRouteWrapper), findsNothing);
    await tester.tap(find.byType(Image));
    await tester.pump();
    await tester.pump();

    final viewer = tester.widget<HeroPhotoViewRouteWrapper>(
      find.byType(HeroPhotoViewRouteWrapper),
    );
    expect(viewer.file.readAsBytesSync(), onePixelPng);
    expect(viewer.heroTag, url);
    expect(find.byIcon(LottiIcons.close), findsWidgets);
  });

  testWidgets('a right-click opens the menu with Add to task, which records '
      'the image on the task and says so', (tester) async {
    when(() => fetcher.fetch(url)).thenAnswer((_) async => onePixelPng);
    when(
      () => attacher.attach(
        bytes: any(named: 'bytes'),
        taskId: any(named: 'taskId'),
      ),
    ).thenAnswer((_) async => true);
    await pump(tester);
    await tester.pump();

    expect(find.byType(DesignSystemContextMenu), findsNothing);
    await rightClick(tester);

    expect(find.byType(DesignSystemContextMenu), findsOneWidget);
    await tester.tap(find.byKey(PullRequestImageKeys.addToTask));
    await tester.pump();
    await tester.pump();

    verify(
      () => attacher.attach(bytes: onePixelPng, taskId: taskId),
    ).called(1);
    expect(find.byType(DesignSystemContextMenu), findsNothing);
    expect(find.text('Image added to the task'), findsOneWidget);
    expect(find.byType(HeroPhotoViewRouteWrapper), findsNothing);
  });

  testWidgets('a long press opens the same menu', (tester) async {
    when(() => fetcher.fetch(url)).thenAnswer((_) async => onePixelPng);
    await pump(tester);
    await tester.pump();

    await tester.longPress(find.byType(Image));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(PullRequestImageKeys.addToTask), findsOneWidget);
    expect(find.byType(HeroPhotoViewRouteWrapper), findsNothing);
  });

  testWidgets('an attach that fails is told', (tester) async {
    when(() => fetcher.fetch(url)).thenAnswer((_) async => onePixelPng);
    when(
      () => attacher.attach(
        bytes: any(named: 'bytes'),
        taskId: any(named: 'taskId'),
      ),
    ).thenAnswer((_) async => false);
    await pump(tester);
    await tester.pump();

    await rightClick(tester);
    await tester.tap(find.byKey(PullRequestImageKeys.addToTask));
    await tester.pump();
    await tester.pump();

    expect(
      find.text("The image couldn't be added to the task."),
      findsOneWidget,
    );
  });

  testWidgets('while an attach runs, the action is not offered again', (
    tester,
  ) async {
    final gate = Completer<bool>();
    when(() => fetcher.fetch(url)).thenAnswer((_) async => onePixelPng);
    when(
      () => attacher.attach(
        bytes: any(named: 'bytes'),
        taskId: any(named: 'taskId'),
      ),
    ).thenAnswer((_) => gate.future);
    await pump(tester);
    await tester.pump();

    await rightClick(tester);
    await tester.tap(find.byKey(PullRequestImageKeys.addToTask));
    await tester.pump();
    await rightClick(tester);

    final item = tester
        .widget<DesignSystemContextMenu>(find.byType(DesignSystemContextMenu))
        .items
        .single;
    expect(item.onTap, isNull);

    gate.complete(true);
    await tester.pump();
    await tester.pump();
    expect(find.text('Image added to the task'), findsOneWidget);
  });

  testWidgets('the image is read as one, with its host and what a tap does', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    when(() => fetcher.fetch(url)).thenAnswer((_) async => onePixelPng);
    await pump(tester);
    await tester.pump();

    // The Image adds no node of its own, so the nearest is the one that
    // names the image and says what a tap and a long press do.
    final semantics = tester.getSemantics(find.byType(Image));
    expect(semantics.label, 'pub-example.r2.dev');
    expect(semantics.hint, 'View full size');
    expect(semantics.flagsCollection.isImage, isTrue);
    expect(semantics.flagsCollection.isButton, isTrue);
    handle.dispose();
  });

  testWidgets('pullRequestImageBuilder puts the image into markdown', (
    tester,
  ) async {
    when(() => fetcher.fetch(url)).thenAnswer((_) async => onePixelPng);
    await pump(
      tester,
      child: AgentMarkdownView(
        '| Shot |\n|---|\n| ![desktop dark]($url) |',
        imageBuilder: pullRequestImageBuilder(taskId),
      ),
    );
    await tester.pump();

    final image = tester.widget<PullRequestImage>(
      find.byType(PullRequestImage),
    );
    expect(image.url, url);
    expect(image.taskId, taskId);
    expect(shownBytes(tester), onePixelPng);
    expect(find.textContaining('not loaded'), findsNothing);
  });

  testWidgets('a size in the alt text sizes the image', (tester) async {
    when(() => fetcher.fetch(url)).thenAnswer((_) async => onePixelPng);
    await pump(
      tester,
      child: AgentMarkdownView(
        '![120x80]($url)',
        imageBuilder: pullRequestImageBuilder(taskId),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect(image.width, 120);
    expect(image.height, 80);
  });

  testWidgets('an image is never shown wider than the description, even in '
      'a table cell that gives it no width', (tester) async {
    when(() => fetcher.fetch(url)).thenAnswer((_) async => onePixelPng);
    await pump(
      tester,
      child: PullRequestDescriptionWidth(
        maxWidth: 100,
        child: AgentMarkdownView(
          '| Shot |\n|---|\n| ![640x480]($url) |',
          imageBuilder: pullRequestImageBuilder(taskId),
        ),
      ),
    );
    await tester.pump();

    expect(tester.getSize(find.byType(Image)).width, 100);
  });

  testWidgets('an image given another URL fetches and shows that one', (
    tester,
  ) async {
    const other = 'https://pub-example.r2.dev/shots/mobile-dark.png';
    final otherPng = Uint8List.fromList([...onePixelPng, 0]);
    when(() => fetcher.fetch(url)).thenAnswer((_) async => onePixelPng);
    when(() => fetcher.fetch(other)).thenAnswer((_) async => otherPng);
    await pump(tester);
    await tester.pump();
    expect(shownBytes(tester), onePixelPng);

    await pump(
      tester,
      child: const PullRequestImage(url: other, taskId: taskId),
    );

    expect(shownBytes(tester), otherPng);
    verify(() => fetcher.fetch(other)).called(1);
  });

  testWidgets('a description that narrows takes its images with it', (
    tester,
  ) async {
    when(() => fetcher.fetch(url)).thenAnswer((_) async => onePixelPng);
    Widget at(double maxWidth) => PullRequestDescriptionWidth(
      maxWidth: maxWidth,
      child: AgentMarkdownView(
        '![640x480]($url)',
        imageBuilder: pullRequestImageBuilder(taskId),
      ),
    );
    await pump(tester, child: at(300));
    await tester.pump();
    expect(tester.getSize(find.byType(Image)).width, 300);

    await pump(tester, child: at(150));
    expect(tester.getSize(find.byType(Image)).width, 150);
  });

  testWidgets('bytes that do not decode leave the notice and nothing to add', (
    tester,
  ) async {
    when(() => fetcher.fetch(url)).thenAnswer(
      (_) async => Uint8List.fromList('<svg/>'.codeUnits),
    );
    await pump(tester);
    await tester.pump();
    await tester.pump();

    expect(find.byType(Image), findsNothing);
    expect(find.byType(DesignSystemContextMenuAnchor), findsNothing);
    expect(
      find.text("Couldn't load image from pub-example.r2.dev"),
      findsOneWidget,
    );
    await tester.longPress(find.byType(MarkdownImageNotice));
    await tester.pump();
    expect(find.byKey(PullRequestImageKeys.addToTask), findsNothing);
  });

  testWidgets('the image is decoded no larger than it is shown', (
    tester,
  ) async {
    when(() => fetcher.fetch(url)).thenAnswer((_) async => onePixelPng);
    Widget at(double maxWidth, {String alt = 'shot'}) =>
        PullRequestDescriptionWidth(
          maxWidth: maxWidth,
          child: AgentMarkdownView(
            '![$alt]($url)',
            imageBuilder: pullRequestImageBuilder(taskId),
          ),
        );
    ResizeImage resized() =>
        tester.widget<Image>(find.byType(Image)).image as ResizeImage;

    // The test surface's device pixel ratio is 3.
    await pump(tester, child: at(300));
    await tester.pump();
    expect(resized().width, 900);
    expect(resized().allowUpscaling, isFalse);

    // A size in the markdown below the bound wins.
    await pump(tester, child: at(300, alt: '120x80'));
    expect(resized().width, 360);

    // Outside a description there is no bound, and no decode size.
    await pump(
      tester,
      child: AgentMarkdownView(
        '![shot]($url)',
        imageBuilder: pullRequestImageBuilder(taskId),
      ),
    );
    expect(tester.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
  });

  testWidgets('the full-size viewer offers Add to task, which records the '
      'image', (tester) async {
    when(() => fetcher.fetch(url)).thenAnswer((_) async => onePixelPng);
    when(
      () => attacher.attach(
        bytes: any(named: 'bytes'),
        taskId: any(named: 'taskId'),
      ),
    ).thenAnswer((_) async => true);
    await pump(tester);
    await tester.pump();

    await tester.tap(find.byType(Image));
    await tester.pump();
    await tester.pump();
    final action = find.widgetWithText(ImageViewerLabelButton, 'Add to task');
    expect(action, findsOneWidget);

    await tester.tap(action);
    await tester.pump();
    await tester.pump();

    verify(
      () => attacher.attach(bytes: onePixelPng, taskId: taskId),
    ).called(1);
    // Told in every scaffold the messenger serves: the viewer's, on top,
    // and the page's beneath it.
    expect(find.text('Image added to the task'), findsWidgets);
    // Still in the viewer: the user may want to look on.
    expect(find.byType(HeroPhotoViewRouteWrapper), findsOneWidget);
  });
}
