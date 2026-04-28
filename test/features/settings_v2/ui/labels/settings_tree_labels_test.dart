import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_data.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_index.dart';
import 'package:lotti/features/settings_v2/ui/labels/settings_tree_labels.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// Resolves a tree-label resolver under an English MaterialApp so
/// every arb-backed key round-trips through the real
/// `AppLocalizations`.
Future<SettingsTreeLabelResolver> _buildResolver(WidgetTester tester) async {
  late SettingsTreeLabelResolver resolver;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          resolver = settingsTreeLabelsFor(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return resolver;
}

void main() {
  group('settingsTreeLabelsFor — resolves every registered node id', () {
    testWidgets('every settingsNodeUrls key has non-empty title + desc', (
      tester,
    ) async {
      final resolve = await _buildResolver(tester);
      for (final id in settingsNodeUrls.keys) {
        final label = resolve(id);
        expect(label.title, isNotEmpty, reason: 'title for $id');
        expect(label.desc, isNotEmpty, reason: 'desc for $id');
      }
    });

    testWidgets(
      'resolves the in-pane whats-new node (not in settingsNodeUrls)',
      (tester) async {
        final resolve = await _buildResolver(tester);
        final label = resolve('whats-new');
        expect(label.title, isNotEmpty);
        expect(label.desc, isNotEmpty);
      },
    );
  });

  group('settingsTreeLabelsFor — arb-backed titles', () {
    testWidgets('top-level settings sections use their canonical arb keys', (
      tester,
    ) async {
      final resolve = await _buildResolver(tester);
      expect(resolve('ai').title, 'AI Settings');
      expect(resolve('agents').title, 'Agents');
      expect(resolve('habits').title, 'Habits');
      expect(resolve('categories').title, 'Categories');
      expect(resolve('labels').title, 'Labels');
      expect(resolve('sync').title, 'Sync Settings');
      expect(resolve('dashboards').title, 'Dashboards');
      expect(resolve('measurables').title, 'Measurable Types');
      expect(resolve('theming').title, 'Theming');
      expect(resolve('flags').title, 'Config Flags');
      expect(resolve('advanced').title, 'Advanced Settings');
      expect(resolve('whats-new').title, "What's New");
    });

    testWidgets('sync leaves with arb keys use their canonical titles', (
      tester,
    ) async {
      final resolve = await _buildResolver(tester);
      expect(resolve('sync/backfill').title, 'Backfill sync');
      expect(resolve('sync/stats').title, 'Matrix Stats');
      expect(resolve('sync/matrix-maintenance').title, 'Maintenance');
    });

    testWidgets('advanced/logging uses settingsLoggingDomainsTitle', (
      tester,
    ) async {
      final resolve = await _buildResolver(tester);
      expect(resolve('advanced/logging').title, 'Logging Domains');
    });

    testWidgets('advanced/maintenance uses settingsMaintenanceTitle', (
      tester,
    ) async {
      final resolve = await _buildResolver(tester);
      expect(resolve('advanced/maintenance').title, 'Maintenance');
    });
  });

  group('settingsTreeLabelsFor — nested-node arb titles', () {
    testWidgets('ai/profiles resolves from settingsAiProfilesTitle', (
      tester,
    ) async {
      final resolve = await _buildResolver(tester);
      expect(resolve('ai/profiles').title, 'Inference Profiles');
    });

    testWidgets('agent leaves use their canonical agent* arb keys', (
      tester,
    ) async {
      final resolve = await _buildResolver(tester);
      expect(resolve('agents/templates').title, 'Agent Templates');
      expect(resolve('agents/souls').title, 'Souls');
      expect(resolve('agents/instances').title, 'Instances');
    });

    testWidgets('sync/outbox uses settingsSyncOutboxTitle', (tester) async {
      final resolve = await _buildResolver(tester);
      expect(resolve('sync/outbox').title, 'Sync Outbox');
    });

    testWidgets('advanced/conflicts and advanced/about use their arb keys', (
      tester,
    ) async {
      final resolve = await _buildResolver(tester);
      expect(resolve('advanced/conflicts').title, 'Sync Conflicts');
      expect(resolve('advanced/about').title, 'About Lotti');
    });
  });

  group('settingsTreeLabelsFor — unknown ids', () {
    testWidgets('unknown id echoes itself as title and empty desc', (
      tester,
    ) async {
      final resolve = await _buildResolver(tester);
      final label = resolve('made-up-node-id');
      expect(label.title, 'made-up-node-id');
      expect(label.desc, '');
    });
  });
}
