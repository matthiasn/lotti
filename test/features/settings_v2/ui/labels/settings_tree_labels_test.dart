import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_data.dart';
import 'package:lotti/features/settings_v2/domain/settings_tree_index.dart';
import 'package:lotti/features/settings_v2/ui/labels/settings_tree_labels.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:material_ui/material_ui.dart';

/// Resolves a tree-label resolver under an English MaterialApp so
/// every arb-backed key round-trips through the real
/// `AppLocalizations`.
Future<SettingsTreeLabelResolver> _buildResolver(WidgetTester tester) async {
  late SettingsTreeLabelResolver resolver;
  await tester.pumpWidget(
    MaterialApp(
      builder: LegacyMaterialBridge.builder,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
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

    testWidgets(
      'resolves the demo-world sync-unavailable tile '
      '(inert, so not in settingsNodeUrls)',
      (tester) async {
        final resolve = await _buildResolver(tester);
        final label = resolve('sync-unavailable');
        expect(label.title, 'Sync Settings');
        expect(label.desc, 'Sync is not available in the demo workspace');
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
      expect(resolve('definitions').title, 'Definitions');
      expect(resolve('definitions/habits').title, 'Habits');
      expect(resolve('definitions/categories').title, 'Categories');
      expect(resolve('definitions/labels').title, 'Labels');
      expect(resolve('sync').title, 'Sync Settings');
      expect(resolve('definitions/dashboards').title, 'Dashboards');
      expect(resolve('definitions/measurables').title, 'Measurables');
      expect(resolve('preferences').title, 'Preferences');
      expect(resolve('preferences/recording-style').title, 'Recording Style');
      expect(resolve('preferences/theming').title, 'Theming');
      expect(resolve('advanced/flags').title, 'Config Flags');
      expect(resolve('advanced').title, 'Advanced Settings');
      expect(resolve('whats-new').title, "What's New");
      expect(resolve('onboarding').title, 'Onboarding');
    });

    testWidgets('sync leaves with arb keys use their canonical titles', (
      tester,
    ) async {
      final resolve = await _buildResolver(tester);
      // The node is the device roster, and its own section header says
      // "Devices" — titling the tree entry "Provisioned Sync" named the
      // mechanism rather than what the user finds there.
      expect(resolve('sync/provisioned').title, 'Devices');
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

  group('settingsTreeLabelsFor — the preferences branch', () {
    testWidgets('the branch names what it groups', (tester) async {
      final resolve = await _buildResolver(tester);
      expect(resolve('preferences').title, 'Preferences');
      expect(
        resolve('preferences').desc,
        'Theming, animations, recording style, speech, and shortcuts',
      );
    });

    testWidgets('each leaf keeps the arb title it had at the root', (
      tester,
    ) async {
      // Reparenting renamed the ids, not the copy: a user who knew the
      // rows by name still finds the same words one level down.
      final resolve = await _buildResolver(tester);
      expect(resolve('preferences/theming').title, 'Theming');
      expect(
        resolve('preferences/keyboard-shortcuts').title,
        'Keyboard shortcuts',
      );
      expect(resolve('preferences/recording-style').title, 'Recording Style');
      expect(resolve('preferences/speech').title, 'Speech');
    });

    testWidgets('animations resolves under its new preferences id', (
      tester,
    ) async {
      final resolve = await _buildResolver(tester);
      expect(resolve('preferences/animations').title, 'Animations');
      // The Advanced-branch id is retired, so it echoes itself.
      expect(resolve('advanced/animations').title, 'advanced/animations');
      expect(resolve('advanced/animations').desc, isEmpty);
    });

    testWidgets('the retired flat ids no longer resolve to real copy', (
      tester,
    ) async {
      // The resolver echoes an unknown id as its own title with an empty
      // desc. Asserting that here is what proves the old cases were
      // removed rather than left behind as a silent second source of copy.
      final resolve = await _buildResolver(tester);
      for (final legacyId in const [
        'theming',
        'keyboard-shortcuts',
        'recording-style',
        'speech',
      ]) {
        expect(resolve(legacyId).title, legacyId, reason: legacyId);
        expect(resolve(legacyId).desc, isEmpty, reason: legacyId);
      }
    });
  });

  group('settingsTreeLabelsFor — nested-node arb titles', () {
    testWidgets('ai/profiles resolves from settingsAiProfilesTitle', (
      tester,
    ) async {
      final resolve = await _buildResolver(tester);
      expect(resolve('ai/profiles').title, 'Inference Profiles');
    });

    testWidgets('ai leaves use their canonical settingsAi* arb keys', (
      tester,
    ) async {
      final resolve = await _buildResolver(tester);
      expect(resolve('ai/providers').title, 'Providers');
      expect(resolve('ai/models').title, 'Models');
      expect(resolve('ai/usage').title, 'Usage & Impact');
      expect(resolve('ai/usage').desc, 'Cost, energy, and CO₂e of AI calls');
    });

    testWidgets('agent leaves use their canonical agent* arb keys', (
      tester,
    ) async {
      final resolve = await _buildResolver(tester);
      expect(resolve('agents/templates').title, 'Agent Templates');
      expect(resolve('agents/instances').title, 'Instances');
      expect(resolve('agents/souls').title, 'Souls');
      expect(resolve('agents/pending-wakes').title, 'Wake Cycles');
    });

    testWidgets('sync/outbox uses settingsSyncOutboxTitle', (tester) async {
      final resolve = await _buildResolver(tester);
      expect(resolve('sync/outbox').title, 'Sync Outbox');
    });

    testWidgets('sync/conflicts and advanced/about use their arb keys', (
      tester,
    ) async {
      // The conflicts leaf moved from `advanced` to `sync` (it's a
      // sync-domain concept) — the resolver follows the new id.
      final resolve = await _buildResolver(tester);
      expect(resolve('sync/conflicts').title, 'Sync Conflicts');
      expect(resolve('advanced/about').title, 'About Lotti');
    });

    testWidgets('advanced/manual-language uses its dedicated arb keys', (
      tester,
    ) async {
      final resolve = await _buildResolver(tester);
      expect(resolve('advanced/manual-language').title, 'Language');
      expect(
        resolve('advanced/manual-language').desc,
        'Choose which language to open the Lotti Manual in',
      );
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
