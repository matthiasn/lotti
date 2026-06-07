import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart'
    show categoryRepositoryProvider;

import '../../../../../mocks/mocks.dart';
import '../../../../../widget_test_utils.dart';

/// Shared harness for the per-provider FTUE setup tests: a button whose
/// callback receives a (context, ref) pair backed by the given repository
/// overrides. The per-provider result types all flow through the same shape.
Widget buildFtueHarness({
  required MockAiConfigRepository repository,
  required MockCategoryRepository categoryRepository,
  required Future<Object?> Function(BuildContext, WidgetRef) onPressed,
}) {
  return makeTestableWidgetNoScroll(
    Scaffold(
      body: Consumer(
        builder: (context, ref, _) {
          return ElevatedButton(
            onPressed: () async {
              await onPressed(context, ref);
            },
            child: const Text('Test'),
          );
        },
      ),
    ),
    overrides: [
      aiConfigRepositoryProvider.overrideWithValue(repository),
      categoryRepositoryProvider.overrideWithValue(categoryRepository),
    ],
  );
}
