import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/motion_tokens.dart';
import 'package:lotti/utils/thumbhash.dart';
import 'package:lotti/widgets/media/thumb_hash_backed_image.dart';
import 'package:lotti/widgets/media/thumb_hash_image.dart';

import '../../widget_test_utils.dart';

/// A picture whose single frame arrives when the test says so.
class _ControlledImage extends ImageProvider<_ControlledImage> {
  _ControlledImage(this.name);

  final String name;
  final Completer<ImageInfo> _frame = Completer<ImageInfo>();

  /// Completes the frame with its own handle on [pixels].
  void deliverFrame(ui.Image pixels) =>
      _frame.complete(ImageInfo(image: pixels.clone()));

  @override
  Future<_ControlledImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_ControlledImage>(this);

  @override
  ImageStreamCompleter loadImage(
    _ControlledImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(_frame.future);

  @override
  String toString() => '_ControlledImage($name)';
}

ThumbHash _hash() => ThumbHash.encode(
  width: 4,
  height: 4,
  rgba: Uint8List.fromList(
    List.filled(4 * 4, [200, 60, 60, 255]).expand((px) => px).toList(),
  ),
);

Widget _subject({
  required ThumbHash? thumbHash,
  required ImageProvider? image,
  BoxFit fit = BoxFit.cover,
  AlignmentGeometry alignment = Alignment.center,
  ImageErrorWidgetBuilder? errorBuilder,
  bool reduceMotion = false,
  Key? key,
}) => makeTestableWidget(
  Center(
    child: SizedBox(
      width: 80,
      height: 60,
      child: ThumbHashBackedImage(
        key: key,
        thumbHash: thumbHash,
        image: image,
        fit: fit,
        alignment: alignment,
        errorBuilder: errorBuilder,
      ),
    ),
  ),
  mediaQueryData: phoneMediaQueryData.copyWith(
    disableAnimations: reduceMotion,
  ),
);

/// Finders scoped to the widget under test: the surrounding MaterialApp has
/// stacks and fade transitions of its own.
Finder _inSubject(Type type) => find.descendant(
  of: find.byType(ThumbHashBackedImage),
  matching: find.byType(type),
);

Image _placeholder(WidgetTester tester) => tester.widget<Image>(
  find.byWidgetPredicate((w) => w is Image && w.image is ThumbHashImage),
);

Image _picture(WidgetTester tester) => tester.widget<Image>(
  find.byWidgetPredicate((w) => w is Image && w.image is _ControlledImage),
);

AnimatedOpacity _fade(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(_inSubject(AnimatedOpacity));

double _pictureOpacity(WidgetTester tester) =>
    tester.widget<FadeTransition>(_inSubject(FadeTransition)).opacity.value;

void main() {
  // Made outside FakeAsync: the engine's completion never reaches a
  // testWidgets body, which is why Flutter's own tests build theirs here.
  late ui.Image frame;

  setUpAll(() async {
    frame = await createTestImage(width: 4, height: 4);
  });

  tearDownAll(() => frame.dispose());

  tearDown(() {
    imageCache
      ..clear()
      ..clearLiveImages();
  });

  group('ThumbHashBackedImage', () {
    testWidgets('paints nothing without a hash or a picture', (tester) async {
      await tester.pumpWidget(_subject(thumbHash: null, image: null));

      expect(find.byType(Image), findsNothing);
      final box = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(ThumbHashBackedImage),
          matching: find.byType(SizedBox),
        ),
      );
      expect(box.width, 0);
      expect(box.height, 0);
    });

    testWidgets('paints only the stand-in while the picture is missing', (
      tester,
    ) async {
      final hash = _hash();
      await tester.pumpWidget(
        _subject(
          thumbHash: hash,
          image: null,
          alignment: Alignment.topCenter,
        ),
      );

      expect(find.byType(Image), findsOneWidget);
      expect(_inSubject(Stack), findsNothing);
      final placeholder = _placeholder(tester);
      expect(placeholder.image, ThumbHashImage(hash));
      expect(placeholder.fit, BoxFit.cover);
      expect(placeholder.alignment, Alignment.topCenter);
      expect(placeholder.filterQuality, FilterQuality.high);
      expect(placeholder.gaplessPlayback, isTrue);
      expect(placeholder.excludeFromSemantics, isTrue);
      expect(
        tester.getSize(find.byType(ThumbHashBackedImage)),
        const Size(80, 60),
      );
    });

    testWidgets('lets the stand-in fill a scale-down box', (tester) async {
      await tester.pumpWidget(
        _subject(
          thumbHash: _hash(),
          image: _ControlledImage('a'),
          fit: BoxFit.scaleDown,
        ),
      );

      // A 32 px raster under scaleDown would sit in the corner at 32 px; the
      // picture keeps the fit it was given.
      expect(_placeholder(tester).fit, BoxFit.contain);
      expect(_picture(tester).fit, BoxFit.scaleDown);
    });

    testWidgets('paints the picture alone, with no fade, when there is no '
        'hash', (tester) async {
      final image = _ControlledImage('a');
      await tester.pumpWidget(_subject(thumbHash: null, image: image));

      expect(find.byType(Image), findsOneWidget);
      expect(_inSubject(Stack), findsNothing);
      final picture = _picture(tester);
      expect(picture.image, same(image));
      expect(picture.frameBuilder, isNull);
      expect(picture.gaplessPlayback, isTrue);
    });

    testWidgets('fades the picture in over the stand-in once its first frame '
        'arrives', (tester) async {
      final image = _ControlledImage('a');
      await tester.pumpWidget(_subject(thumbHash: _hash(), image: image));

      // Both layers are mounted, stand-in underneath, picture invisible.
      final stack = tester.widget<Stack>(_inSubject(Stack));
      expect(stack.fit, StackFit.passthrough);
      expect(stack.children.first, isA<Positioned>());
      expect(find.byType(Image), findsNWidgets(2));
      expect(_picture(tester).fit, BoxFit.cover);
      expect(_pictureOpacity(tester), 0);
      final fade = _fade(tester);
      expect(fade.duration, MotionDurations.medium1);
      expect(fade.curve, MotionCurves.emphasizedDecelerate);

      image.deliverFrame(frame);
      await tester.pump();
      expect(_fade(tester).opacity, 1);
      expect(_pictureOpacity(tester), 0);

      await tester.pump(MotionDurations.medium1 ~/ 2);
      final midway = _pictureOpacity(tester);
      expect(midway, greaterThan(0));
      expect(midway, lessThan(1));

      await tester.pump(MotionDurations.medium1);
      expect(_pictureOpacity(tester), 1);
      // The stand-in stays underneath: the box never flashes empty.
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('shows the picture at once under reduced motion', (
      tester,
    ) async {
      final image = _ControlledImage('a');
      await tester.pumpWidget(
        _subject(thumbHash: _hash(), image: image, reduceMotion: true),
      );
      expect(_fade(tester).duration, Duration.zero);
      expect(_pictureOpacity(tester), 0);

      image.deliverFrame(frame);
      await tester.pump();

      expect(_pictureOpacity(tester), 1);
    });

    testWidgets('does not fade again when the provider swaps after the '
        'reveal', (tester) async {
      final first = _ControlledImage('first');
      const key = ValueKey('same-picture');
      await tester.pumpWidget(
        _subject(thumbHash: _hash(), image: first, key: key),
      );
      first.deliverFrame(frame);
      await tester.pump();
      await tester.pump(MotionDurations.medium1 * 2);
      expect(_pictureOpacity(tester), 1);

      // A resize bucket crossing: a new provider for the same picture, whose
      // frame has not arrived. Gapless playback keeps the old frame; the
      // opacity must not drop while it waits.
      final second = _ControlledImage('second');
      await tester.pumpWidget(
        _subject(thumbHash: _hash(), image: second, key: key),
      );
      await tester.pump();

      expect(_picture(tester).image, same(second));
      expect(_fade(tester).opacity, 1);
      expect(_pictureOpacity(tester), 1);
    });

    testWidgets('starts over from the stand-in for a different picture', (
      tester,
    ) async {
      final first = _ControlledImage('first');
      await tester.pumpWidget(
        _subject(
          thumbHash: _hash(),
          image: first,
          key: const ValueKey('one'),
        ),
      );
      first.deliverFrame(frame);
      await tester.pump();
      await tester.pump(MotionDurations.medium1 * 2);
      expect(_pictureOpacity(tester), 1);

      await tester.pumpWidget(
        _subject(
          thumbHash: _hash(),
          image: _ControlledImage('second'),
          key: const ValueKey('two'),
        ),
      );

      expect(_pictureOpacity(tester), 0);
    });

    testWidgets('is revealed at once when the picture is already decoded', (
      tester,
    ) async {
      final image = _ControlledImage('cached');
      await tester.pumpWidget(
        _subject(thumbHash: _hash(), image: image, key: const ValueKey('a')),
      );
      image.deliverFrame(frame);
      await tester.pump();

      // Same provider, fresh widget: a cache hit hands the frame over
      // synchronously, and a picture that is already on screen elsewhere has
      // nothing to fade in from.
      await tester.pumpWidget(
        _subject(thumbHash: _hash(), image: image, key: const ValueKey('b')),
      );

      expect(_fade(tester).opacity, 1);
      expect(_pictureOpacity(tester), 1);
    });

    testWidgets('forwards the error builder to the picture', (tester) async {
      Widget onError(BuildContext context, Object error, StackTrace? stack) =>
          const SizedBox.shrink();
      await tester.pumpWidget(
        _subject(
          thumbHash: _hash(),
          image: _ControlledImage('a'),
          errorBuilder: onError,
        ),
      );

      expect(_picture(tester).errorBuilder, same(onError));
      expect(_placeholder(tester).errorBuilder, isNull);
    });
  });
}
