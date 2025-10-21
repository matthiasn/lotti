import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/features/sync/ui/view_models/outbox_list_item_view_model.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OutboxListItemViewModel', () {
    testWidgets(
        'gracefully falls back when the stored status index is out of range',
        (tester) async {
      late OutboxListItemViewModel viewModel;
      late BuildContext capturedContext;

      final item = OutboxItem(
        id: 1,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
        status: 999, // legacy/invalid value should not crash
        retries: 0,
        message: jsonEncode({
          'runtimeType': 'aiConfigDelete',
          'id': 'config-id',
        }),
        subject: 'subject',
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              capturedContext = context;
              viewModel = OutboxListItemViewModel.fromItem(
                context: context,
                item: item,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pump();

      expect(viewModel.statusLabel, 'Pending');
      expect(
        viewModel.statusColor,
        Theme.of(capturedContext).colorScheme.tertiary,
      );
    });

    testWidgets('trims whitespace subjects and reports missing attachment',
        (tester) async {
      late OutboxListItemViewModel viewModel;
      late BuildContext capturedContext;

      final item = OutboxItem(
        id: 7,
        createdAt: DateTime(2024, 2, 2, 12),
        updatedAt: DateTime(2024, 2, 2, 12),
        status: 2,
        retries: 2,
        // malformed payload should fall back to Unknown payload
        message: '{"unexpected":"shape"}',
        subject: '   ',
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          Builder(
            builder: (context) {
              capturedContext = context;
              viewModel = OutboxListItemViewModel.fromItem(
                context: context,
                item: item,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await tester.pump();

      expect(viewModel.subjectValue, isNull);
      expect(
        viewModel.payloadKindLabel,
        capturedContext.messages.syncListUnknownPayload,
      );
      expect(viewModel.attachmentValue, 'No attachment');
      expect(viewModel.retriesLabel, '2 Retries');
      expect(
        viewModel.semanticsLabel.toLowerCase(),
        contains('unknown payload'),
      );
    });
  });
}
