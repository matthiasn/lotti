import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/file_uploads/design_system_file_upload.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DesignSystemFileUploadDropZone', () {
    testWidgets('renders upload icon, link text, and hint', (tester) async {
      await _pumpWidget(
        tester,
        DesignSystemFileUploadDropZone(
          clickToUploadLabel: 'Click to upload',
          dragAndDropLabel: 'or drag and drop',
          hintText: 'SVG, PNG, JPG or GIF',
          onTap: () {},
        ),
      );

      expect(find.byIcon(Icons.upload_file), findsOneWidget);
      expect(find.textContaining('Click to upload'), findsOneWidget);
      expect(find.textContaining('or drag and drop'), findsOneWidget);
      expect(find.text('SVG, PNG, JPG or GIF'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;

      await _pumpWidget(
        tester,
        DesignSystemFileUploadDropZone(
          clickToUploadLabel: 'Click to upload',
          dragAndDropLabel: 'or drag and drop',
          hintText: 'SVG, PNG, JPG or GIF',
          onTap: () => tapped = true,
        ),
      );

      await tester.tap(find.byType(DesignSystemFileUploadDropZone));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('applies hover background via forcedState', (tester) async {
      const key = Key('hover-zone');

      await _pumpWidget(
        tester,
        DesignSystemFileUploadDropZone(
          key: key,
          clickToUploadLabel: 'Click to upload',
          dragAndDropLabel: 'or drag and drop',
          hintText: 'hint',
          forcedState: DesignSystemFileUploadDropZoneVisualState.hover,
          onTap: () {},
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;

      expect(decoration.color, dsTokensLight.colors.surface.enabled);
    });

    testWidgets('disabled state uses low emphasis colors', (tester) async {
      const key = Key('disabled-zone');

      await _pumpWidget(
        tester,
        const DesignSystemFileUploadDropZone(
          key: key,
          clickToUploadLabel: 'Click to upload',
          dragAndDropLabel: 'or drag and drop',
          hintText: 'hint',
        ),
      );

      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byIcon(Icons.upload_file),
        ),
      );

      expect(icon.color, dsTokensLight.colors.text.lowEmphasis);
    });

    testWidgets('paints dashed border via CustomPaint', (tester) async {
      const key = Key('dashed-zone');

      await _pumpWidget(
        tester,
        DesignSystemFileUploadDropZone(
          key: key,
          clickToUploadLabel: 'Click to upload',
          dragAndDropLabel: 'or drag and drop',
          hintText: 'hint',
          onTap: () {},
        ),
      );

      expect(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );
    });

    testWidgets('provides semantics label', (tester) async {
      const key = Key('semantics-zone');

      await _pumpWidget(
        tester,
        DesignSystemFileUploadDropZone(
          key: key,
          clickToUploadLabel: 'Click to upload',
          dragAndDropLabel: 'or drag and drop',
          hintText: 'hint',
          semanticsLabel: 'Upload area',
          onTap: () {},
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics && widget.properties.label == 'Upload area',
          ),
        ),
      );

      expect(semantics.properties.label, 'Upload area');
    });
    testWidgets('hover interaction changes background', (tester) async {
      const key = Key('hover-interact-zone');

      await _pumpWidget(
        tester,
        DesignSystemFileUploadDropZone(
          key: key,
          clickToUploadLabel: 'Click to upload',
          dragAndDropLabel: 'or drag and drop',
          hintText: 'hint',
          onTap: () {},
        ),
      );

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(tester.getCenter(find.byKey(key)));
      await tester.pump();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;

      expect(decoration.color, dsTokensLight.colors.surface.enabled);

      // Move far away to trigger exit
      await gesture.moveTo(const Offset(-500, -500));
      await tester.pump();

      final containerAfter = tester.widget<Container>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(Container),
        ),
      );
      final decorationAfter = containerAfter.decoration! as BoxDecoration;

      expect(decorationAfter.color, Colors.transparent);
    });
  });

  group('DesignSystemFileUploadItem', () {
    testWidgets('renders file name and size', (tester) async {
      await _pumpWidget(
        tester,
        DesignSystemFileUploadItem(
          fileName: 'photo.png',
          fileSize: '200 KB',
          status: DesignSystemFileUploadItemStatus.uploading,
          progress: 0.5,
          onCancel: () {},
        ),
      );

      expect(find.text('photo.png'), findsOneWidget);
      expect(find.text('200 KB'), findsOneWidget);
    });

    testWidgets('shows progress bar and percentage when uploading', (
      tester,
    ) async {
      await _pumpWidget(
        tester,
        DesignSystemFileUploadItem(
          fileName: 'photo.png',
          fileSize: '200 KB',
          status: DesignSystemFileUploadItemStatus.uploading,
          progress: 0.2,
          onCancel: () {},
        ),
      );

      expect(find.text('20%'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsOneWidget);
    });

    testWidgets('shows check icon when complete', (tester) async {
      await _pumpWidget(
        tester,
        const DesignSystemFileUploadItem(
          fileName: 'photo.png',
          fileSize: '200 KB',
          status: DesignSystemFileUploadItemStatus.complete,
          progress: 1,
        ),
      );

      expect(find.text('100%'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('check icon uses success color', (tester) async {
      const key = Key('complete-item');

      await _pumpWidget(
        tester,
        const DesignSystemFileUploadItem(
          key: key,
          fileName: 'photo.png',
          fileSize: '200 KB',
          status: DesignSystemFileUploadItemStatus.complete,
          progress: 1,
        ),
      );

      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byIcon(Icons.check_circle),
        ),
      );

      expect(icon.color, dsTokensLight.colors.alert.success.defaultColor);
    });

    testWidgets('shows error state with error label and retry', (
      tester,
    ) async {
      await _pumpWidget(
        tester,
        DesignSystemFileUploadItem(
          fileName: 'photo.png',
          fileSize: '200 KB',
          status: DesignSystemFileUploadItemStatus.error,
          errorLabel: 'Upload failed',
          retryLabel: 'Retry',
          onRetry: () {},
        ),
      );

      expect(find.text('Upload failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('error state has red border', (tester) async {
      const key = Key('error-item');

      await _pumpWidget(
        tester,
        DesignSystemFileUploadItem(
          key: key,
          fileName: 'photo.png',
          fileSize: '200 KB',
          status: DesignSystemFileUploadItemStatus.error,
          errorLabel: 'Upload failed',
          onRetry: () {},
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration! as BoxDecoration;
      final border = decoration.border! as Border;

      expect(
        border.top.color,
        dsTokensLight.colors.alert.error.defaultColor,
      );
    });

    testWidgets('calls onCancel when cancel icon is tapped', (tester) async {
      var cancelled = false;

      await _pumpWidget(
        tester,
        DesignSystemFileUploadItem(
          fileName: 'photo.png',
          fileSize: '200 KB',
          status: DesignSystemFileUploadItemStatus.uploading,
          progress: 0.5,
          onCancel: () => cancelled = true,
        ),
      );

      await tester.tap(find.byIcon(Icons.cancel_outlined));
      await tester.pump();

      expect(cancelled, isTrue);
    });

    testWidgets('calls onRetry when retry icon is tapped', (tester) async {
      var retried = false;

      await _pumpWidget(
        tester,
        DesignSystemFileUploadItem(
          fileName: 'photo.png',
          fileSize: '200 KB',
          status: DesignSystemFileUploadItemStatus.error,
          errorLabel: 'Upload failed',
          retryLabel: 'Retry',
          onRetry: () => retried = true,
        ),
      );

      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      expect(retried, isTrue);
    });

    testWidgets('calls onRetry when retry label text is tapped', (
      tester,
    ) async {
      var retried = false;

      await _pumpWidget(
        tester,
        DesignSystemFileUploadItem(
          fileName: 'photo.png',
          fileSize: '200 KB',
          status: DesignSystemFileUploadItemStatus.error,
          errorLabel: 'Upload failed',
          retryLabel: 'Retry',
          onRetry: () => retried = true,
        ),
      );

      await tester.tap(find.text('Retry'));
      await tester.pump();

      expect(retried, isTrue);
    });

    testWidgets('does not show progress bar in error state', (tester) async {
      await _pumpWidget(
        tester,
        DesignSystemFileUploadItem(
          fileName: 'photo.png',
          fileSize: '200 KB',
          status: DesignSystemFileUploadItemStatus.error,
          errorLabel: 'Upload failed',
          onRetry: () {},
        ),
      );

      // No percentage text in error state
      expect(find.text('0%'), findsNothing);
      expect(find.text('20%'), findsNothing);
    });

    testWidgets('upload file icon uses error color in error state', (
      tester,
    ) async {
      const key = Key('error-icon-item');

      await _pumpWidget(
        tester,
        DesignSystemFileUploadItem(
          key: key,
          fileName: 'photo.png',
          fileSize: '200 KB',
          status: DesignSystemFileUploadItemStatus.error,
          errorLabel: 'Upload failed',
          onRetry: () {},
        ),
      );

      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byIcon(Icons.upload_file),
        ),
      );

      expect(icon.color, dsTokensLight.colors.alert.error.defaultColor);
    });

    testWidgets('provides semantics label', (tester) async {
      const key = Key('semantics-item');

      await _pumpWidget(
        tester,
        DesignSystemFileUploadItem(
          key: key,
          fileName: 'photo.png',
          fileSize: '200 KB',
          status: DesignSystemFileUploadItemStatus.uploading,
          progress: 0.5,
          semanticsLabel: 'Photo upload',
          onCancel: () {},
        ),
      );

      final semantics = tester.widget<Semantics>(
        find.descendant(
          of: find.byKey(key),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Semantics &&
                widget.properties.label == 'Photo upload',
          ),
        ),
      );

      expect(semantics.properties.label, 'Photo upload');
    });
  });
}

Future<void> _pumpWidget(
  WidgetTester tester,
  Widget child,
) async {
  await tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      child,
      theme: DesignSystemTheme.light(),
    ),
  );
}
