import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/widgets/mlx_audio_model_download_dialog.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/mlx_audio_channel.dart';
import 'package:lotti/features/ai/util/mlx_audio_model_progress_store.dart';

import '../../../../../widget_test_utils.dart';
import 'mlx_audio_model_download_dialog_test_helpers.dart';

void main() {
  group('MlxAudioModelDownloadDialog', () {
    testWidgets('shows an indeterminate checking state while install starts', (
      tester,
    ) async {
      final model = hModel(
        id: 'qwen-17b-8bit',
        name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
        providerModelId: mlxAudioQwenAsr17B8BitModelId,
      );
      final channel = PendingStatusMlxAudioChannel(model.providerModelId);
      addTearDown(channel.close);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MlxAudioModelDownloadDialog(model: model),
          overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
        ),
      );

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, isNull);
      expect(find.text('Checking model status'), findsOneWidget);
      expect(channel.installCalls, 1);
    });

    testWidgets(
      'reports a Flutter error when starting the install throws',
      (tester) async {
        final model = hModel(
          id: 'qwen-17b-8bit',
          name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
          providerModelId: mlxAudioQwenAsr17B8BitModelId,
        );
        // The store status path still needs a working channel; only the
        // install call is forced to throw via the overridden store notifier.
        final channel = TerminalMlxAudioChannel(
          model.providerModelId,
          MlxAudioModelStatus.notInstalled,
        );
        addTearDown(channel.close);

        final installError = StateError('install boom');

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            MlxAudioModelDownloadDialog(model: model),
            overrides: [
              mlxAudioChannelProvider.overrideWithValue(channel),
              mlxAudioModelProgressStoreProvider.overrideWith(
                () => ThrowingInstallStore(installError),
              ),
            ],
          ),
        );
        // Let the post-frame callback run so _startDownload executes and the
        // overridden installModel throws into the dialog's catch block.
        await tester.pump();
        await tester.pump();
        await tester.pump();

        // The dialog funnels the failure through FlutterError.reportError; the
        // test binding captures it so we can assert on the reported exception.
        final reported = tester.takeException();
        expect(reported, same(installError));

        // The dialog itself does not crash and keeps rendering its UI.
        expect(find.byType(MlxAudioModelDownloadDialog), findsOneWidget);
      },
    );

    testWidgets('renders measured downloading progress as percent', (
      tester,
    ) async {
      final model = hModel(
        id: 'qwen-17b-8bit',
        name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
        providerModelId: mlxAudioQwenAsr17B8BitModelId,
      );
      final channel = TerminalMlxAudioChannel(
        model.providerModelId,
        MlxAudioModelStatus.downloading,
        completedUnitCount: 42,
        totalUnitCount: 100,
      );
      addTearDown(channel.close);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          MlxAudioModelDownloadDialog(model: model),
          overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.value, 0.42);
      expect(find.text('Downloading 42%'), findsOneWidget);
    });

    testWidgets(
      'renders indeterminate downloading progress without a percent',
      (
        tester,
      ) async {
        final model = hModel(
          id: 'qwen-17b-8bit',
          name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
          providerModelId: mlxAudioQwenAsr17B8BitModelId,
        );
        final channel = TerminalMlxAudioChannel(
          model.providerModelId,
          MlxAudioModelStatus.downloading,
        );
        addTearDown(channel.close);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            MlxAudioModelDownloadDialog(model: model),
            overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();

        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(indicator.value, isNull);
        expect(find.text('Downloading'), findsOneWidget);
        expect(find.textContaining('%'), findsNothing);
      },
    );

    testWidgets('renders installed and not-installed terminal states', (
      tester,
    ) async {
      final model = hModel(
        id: 'qwen-17b-8bit',
        name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
        providerModelId: mlxAudioQwenAsr17B8BitModelId,
      );

      for (final statusCase in const [
        (MlxAudioModelStatus.installed, 1.0, 'Installed'),
        (MlxAudioModelStatus.notInstalled, 0.0, 'Not installed'),
      ]) {
        final channel = TerminalMlxAudioChannel(
          model.providerModelId,
          statusCase.$1,
        );
        addTearDown(channel.close);

        await tester.pumpWidget(
          makeTestableWidgetWithScaffold(
            MlxAudioModelDownloadDialog(model: model),
            overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
          ),
        );
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();
        await tester.pump();

        final indicator = tester.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator),
        );
        expect(indicator.value, statusCase.$2);
        expect(find.text(statusCase.$3), findsOneWidget);
      }
    });

    testWidgets('close button pops the dialog', (tester) async {
      final model = hModel(
        id: 'qwen-17b-8bit',
        name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
        providerModelId: mlxAudioQwenAsr17B8BitModelId,
      );
      final channel = TerminalMlxAudioChannel(
        model.providerModelId,
        MlxAudioModelStatus.installed,
      );
      addTearDown(channel.close);

      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => MlxAudioModelDownloadDialog.show(
                context: context,
                model: model,
              ),
              child: const Text('Open download'),
            ),
          ),
          overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
        ),
      );
      await tester.tap(find.text('Open download'));
      await tester.pump();
      await tester.pump(kThemeAnimationDuration);
      await tester.pump();
      await tester.pump();

      expect(find.byType(MlxAudioModelDownloadDialog), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.pump(kThemeAnimationDuration);

      expect(find.byType(MlxAudioModelDownloadDialog), findsNothing);
    });

    testWidgets(
      'renders terminal failed and unsupported states with determinate progress',
      (tester) async {
        final model = hModel(
          id: 'qwen-17b-8bit',
          name: 'Qwen3 ASR 1.7B (MLX 8-bit)',
          providerModelId: mlxAudioQwenAsr17B8BitModelId,
        );

        for (final status in [
          MlxAudioModelStatus.failed,
          MlxAudioModelStatus.unsupported,
        ]) {
          final channel = TerminalMlxAudioChannel(
            model.providerModelId,
            status,
          );
          addTearDown(channel.close);

          await tester.pumpWidget(
            makeTestableWidgetWithScaffold(
              MlxAudioModelDownloadDialog(model: model),
              overrides: [mlxAudioChannelProvider.overrideWithValue(channel)],
            ),
          );
          await tester.pump();
          await tester.pump();
          await tester.pump();
          await tester.pump();
          await tester.pump();

          final indicator = tester.widget<LinearProgressIndicator>(
            find.byType(LinearProgressIndicator),
          );
          expect(indicator.value, 0);

          if (status == MlxAudioModelStatus.failed) {
            expect(find.text('Download failed'), findsOneWidget);
          } else {
            expect(find.text('Apple Silicon required'), findsOneWidget);
          }
        }
      },
    );
  });
}
