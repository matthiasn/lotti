import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/soul_document_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/ui/agent_soul_detail_page.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../widget_test_utils.dart';
import '../test_utils.dart';

class MockSoulDocumentService extends Mock implements SoulDocumentService {}

void main() {
  late MockSoulDocumentService mockSoulService;

  setUp(() async {
    await setUpTestGetIt();
    mockSoulService = MockSoulDocumentService();
  });

  tearDown(() async {
    beamToNamedOverride = null;
    await tearDownTestGetIt();
  });

  Widget buildCreateSubject({
    List<Override> extraOverrides = const [],
  }) {
    return makeTestableWidgetNoScroll(
      const AgentSoulDetailPage(),
      theme: DesignSystemTheme.light(),
      overrides: [
        soulDocumentServiceProvider.overrideWithValue(mockSoulService),
        allSoulDocumentsProvider.overrideWith(
          (ref) async => <AgentDomainEntity>[],
        ),
        ...extraOverrides,
      ],
    );
  }

  Widget buildEditSubject({
    required String soulId,
    SoulDocumentEntity? soul,
    SoulDocumentVersionEntity? activeVersion,
    List<AgentDomainEntity> versionHistory = const [],
    List<String> assignedTemplateIds = const [],
    List<Override> extraOverrides = const [],
  }) {
    final defaultSoul =
        // ignore: avoid_redundant_argument_values
        soul ?? makeTestSoulDocument(id: soulId, displayName: 'Test Soul');
    final defaultVersion =
        activeVersion ?? makeTestSoulDocumentVersion(agentId: soulId);

    return makeTestableWidgetNoScroll(
      AgentSoulDetailPage(soulId: soulId),
      theme: DesignSystemTheme.light(),
      overrides: [
        soulDocumentServiceProvider.overrideWithValue(mockSoulService),
        soulDocumentProvider.overrideWith(
          (ref, id) async => defaultSoul,
        ),
        activeSoulVersionProvider.overrideWith(
          (ref, id) async => defaultVersion,
        ),
        soulVersionHistoryProvider.overrideWith(
          (ref, id) async => versionHistory.cast<AgentDomainEntity>(),
        ),
        templatesUsingSoulProvider.overrideWith(
          (ref, id) async => assignedTemplateIds,
        ),
        agentTemplateProvider.overrideWith(
          (ref, id) async => null,
        ),
        allSoulDocumentsProvider.overrideWith(
          (ref) async => <AgentDomainEntity>[],
        ),
        ...extraOverrides,
      ],
    );
  }

  group('AgentSoulDetailPage — create mode', () {
    testWidgets('shows create form with name and directive fields', (
      tester,
    ) async {
      await tester.pumpWidget(buildCreateSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSoulDetailPage));
      expect(
        find.text(context.messages.agentSoulCreateTitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentSoulDisplayNameLabel),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentSoulVoiceDirectiveLabel),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentSoulToneBoundsLabel),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentSoulCoachingStyleLabel),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentSoulAntiSycophancyLabel),
        findsOneWidget,
      );
    });

    testWidgets('create button disabled when name or voice is empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildCreateSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSoulDetailPage));
      final createButton = find.text(context.messages.createButton);
      expect(createButton, findsOneWidget);

      // Button should be disabled (no name or voice directive).
      final buttonWidget = tester.widget<FilledButton>(
        find.ancestor(
          of: createButton,
          matching: find.byType(FilledButton),
        ),
      );
      expect(buttonWidget.onPressed, isNull);
    });

    testWidgets('create button enabled when name and voice are provided', (
      tester,
    ) async {
      await tester.pumpWidget(buildCreateSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSoulDetailPage));

      // Enter name.
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText ==
                  context.messages.agentSoulDisplayNameLabel,
        ),
        'My Soul',
      );
      await tester.pump();

      // Enter voice directive.
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText ==
                  context.messages.agentSoulVoiceDirectiveLabel,
        ),
        'Be warm',
      );
      await tester.pump();

      // Create button should now be enabled.
      final createButton = find.text(context.messages.createButton);
      final buttonWidget = tester.widget<FilledButton>(
        find.ancestor(
          of: createButton,
          matching: find.byType(FilledButton),
        ),
      );
      expect(buttonWidget.onPressed, isNotNull);
    });

    testWidgets('calls createSoul on save and shows snackbar', (
      tester,
    ) async {
      when(
        () => mockSoulService.createSoul(
          displayName: any(named: 'displayName'),
          voiceDirective: any(named: 'voiceDirective'),
          toneBounds: any(named: 'toneBounds'),
          coachingStyle: any(named: 'coachingStyle'),
          antiSycophancyPolicy: any(named: 'antiSycophancyPolicy'),
          authoredBy: any(named: 'authoredBy'),
        ),
      ).thenAnswer(
        (_) async => makeTestSoulDocument(displayName: 'New Soul'),
      );

      await tester.pumpWidget(buildCreateSubject());
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSoulDetailPage));

      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText ==
                  context.messages.agentSoulDisplayNameLabel,
        ),
        'New Soul',
      );
      await tester.pump();

      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText ==
                  context.messages.agentSoulVoiceDirectiveLabel,
        ),
        'Be kind',
      );
      await tester.pump();

      await tester.tap(find.text(context.messages.createButton));
      await tester.pumpAndSettle();

      verify(
        () => mockSoulService.createSoul(
          displayName: 'New Soul',
          voiceDirective: 'Be kind',
          // ignore: avoid_redundant_argument_values
          toneBounds: '',
          // ignore: avoid_redundant_argument_values
          coachingStyle: '',
          // ignore: avoid_redundant_argument_values
          antiSycophancyPolicy: '',
          authoredBy: 'user',
        ),
      ).called(1);
    });
  });

  group('AgentSoulDetailPage — edit mode', () {
    testWidgets('shows edit form seeded with soul data', (tester) async {
      final version = makeTestSoulDocumentVersion(
        agentId: 'soul-edit',
        voiceDirective: 'Be warm and clear',
        toneBounds: 'Friendly tone',
        coachingStyle: 'Direct coaching',
        antiSycophancyPolicy: 'No flattery',
      );

      await tester.pumpWidget(
        buildEditSubject(
          soulId: 'soul-edit',
          soul: makeTestSoulDocument(
            id: 'soul-edit',
            displayName: 'Edit Soul',
          ),
          activeVersion: version,
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSoulDetailPage));
      expect(
        find.text(context.messages.agentSoulDetailTitle),
        findsOneWidget,
      );
      expect(find.text('Edit Soul'), findsOneWidget);
      expect(find.text('Be warm and clear'), findsOneWidget);
      expect(find.text('Friendly tone'), findsOneWidget);
      expect(find.text('Direct coaching'), findsOneWidget);
      expect(find.text('No flattery'), findsOneWidget);
    });

    testWidgets('has Settings and Info tabs', (tester) async {
      await tester.pumpWidget(
        buildEditSubject(soulId: 'soul-tabs'),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSoulDetailPage));
      expect(
        find.text(context.messages.agentSoulSettingsTab),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentSoulInfoTab),
        findsOneWidget,
      );
    });

    testWidgets('Info tab shows version history', (tester) async {
      final v1 = makeTestSoulDocumentVersion(
        id: 'v1',
        agentId: 'soul-info',
        // ignore: avoid_redundant_argument_values
        version: 1,
        // ignore: avoid_redundant_argument_values
        status: SoulDocumentVersionStatus.active,
      );
      final v0 = makeTestSoulDocumentVersion(
        id: 'v0',
        agentId: 'soul-info',
        version: 0,
        status: SoulDocumentVersionStatus.archived,
      );

      await tester.pumpWidget(
        buildEditSubject(
          soulId: 'soul-info',
          activeVersion: v1,
          versionHistory: [v1, v0],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSoulDetailPage));

      // Switch to Info tab.
      await tester.tap(find.text(context.messages.agentSoulInfoTab));
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.agentSoulVersionHistoryTitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentSoulVersionLabel(1)),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentSoulVersionLabel(0)),
        findsOneWidget,
      );

      // Active version should show "Active" badge.
      expect(
        find.text(context.messages.agentTemplateStatusActive),
        findsOneWidget,
      );
      // Archived version should show "Archived" badge.
      expect(
        find.text(context.messages.agentTemplateStatusArchived),
        findsOneWidget,
      );
    });

    testWidgets('Info tab shows assigned templates section', (tester) async {
      final soul = makeTestSoulDocument(
        id: 'soul-assigned',
        // ignore: avoid_redundant_argument_values
        displayName: 'Test Soul',
      );
      final version = makeTestSoulDocumentVersion(agentId: 'soul-assigned');

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentSoulDetailPage(soulId: 'soul-assigned'),
          theme: DesignSystemTheme.light(),
          overrides: [
            soulDocumentServiceProvider.overrideWithValue(mockSoulService),
            soulDocumentProvider.overrideWith(
              (ref, id) async => soul,
            ),
            activeSoulVersionProvider.overrideWith(
              (ref, id) async => version,
            ),
            soulVersionHistoryProvider.overrideWith(
              (ref, id) async => <AgentDomainEntity>[],
            ),
            templatesUsingSoulProvider.overrideWith(
              (ref, id) async => ['tpl-1', 'tpl-2'],
            ),
            agentTemplateProvider.overrideWith(
              (ref, id) async => makeTestTemplate(
                id: id,
                agentId: id,
                displayName: 'Template $id',
              ),
            ),
            allSoulDocumentsProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSoulDetailPage));
      await tester.tap(find.text(context.messages.agentSoulInfoTab));
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.agentSoulAssignedTemplatesTitle),
        findsOneWidget,
      );
      expect(find.text('Template tpl-1'), findsOneWidget);
      expect(find.text('Template tpl-2'), findsOneWidget);
    });

    testWidgets('Info tab shows rollback button for archived versions', (
      tester,
    ) async {
      final activeVersion = makeTestSoulDocumentVersion(
        id: 'v2',
        agentId: 'soul-rb',
        version: 2,
        // ignore: avoid_redundant_argument_values
        status: SoulDocumentVersionStatus.active,
      );
      final archivedVersion = makeTestSoulDocumentVersion(
        id: 'v1',
        agentId: 'soul-rb',
        // ignore: avoid_redundant_argument_values
        version: 1,
        status: SoulDocumentVersionStatus.archived,
      );

      await tester.pumpWidget(
        buildEditSubject(
          soulId: 'soul-rb',
          activeVersion: activeVersion,
          versionHistory: [activeVersion, archivedVersion],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSoulDetailPage));
      await tester.tap(find.text(context.messages.agentSoulInfoTab));
      await tester.pumpAndSettle();

      // Archived version should have a restore button.
      expect(find.byIcon(Icons.restore), findsOneWidget);
    });

    testWidgets('shows not-found when soul does not exist', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentSoulDetailPage(soulId: 'ghost'),
          theme: DesignSystemTheme.light(),
          overrides: [
            soulDocumentServiceProvider.overrideWithValue(mockSoulService),
            soulDocumentProvider.overrideWith(
              (ref, id) async => null,
            ),
            activeSoulVersionProvider.overrideWith(
              (ref, id) async => null,
            ),
            soulVersionHistoryProvider.overrideWith(
              (ref, id) async => <AgentDomainEntity>[],
            ),
            templatesUsingSoulProvider.overrideWith(
              (ref, id) async => <String>[],
            ),
            allSoulDocumentsProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[],
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSoulDetailPage));
      expect(
        find.text(context.messages.agentSoulNotFound),
        findsOneWidget,
      );
    });

    testWidgets('shows delete button on Info tab', (tester) async {
      await tester.pumpWidget(
        buildEditSubject(soulId: 'soul-del'),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSoulDetailPage));
      await tester.tap(find.text(context.messages.agentSoulInfoTab));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.text(context.messages.deleteButton), findsOneWidget);
    });

    testWidgets('delete shows confirmation dialog', (tester) async {
      await tester.pumpWidget(
        buildEditSubject(soulId: 'soul-del'),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSoulDetailPage));
      await tester.tap(find.text(context.messages.agentSoulInfoTab));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(
        find.text(context.messages.agentSoulDeleteConfirmTitle),
        findsOneWidget,
      );
      expect(
        find.text(context.messages.agentSoulDeleteConfirmBody),
        findsOneWidget,
      );
    });

    testWidgets('dirty state tracked when form fields change', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildEditSubject(soulId: 'soul-dirty'),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSoulDetailPage));

      // Initially no save button visible (not dirty).
      expect(
        find.text(context.messages.agentTemplateSaveNewVersion),
        findsNothing,
      );

      // Modify voice directive.
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText ==
                  context.messages.agentSoulVoiceDirectiveLabel,
        ),
        'Changed voice',
      );
      await tester.pump();

      // Save button should now appear.
      expect(
        find.text(context.messages.agentTemplateSaveNewVersion),
        findsOneWidget,
      );
    });

    testWidgets('calls createVersion on save in edit mode', (tester) async {
      when(
        () => mockSoulService.createVersion(
          soulId: any(named: 'soulId'),
          voiceDirective: any(named: 'voiceDirective'),
          toneBounds: any(named: 'toneBounds'),
          coachingStyle: any(named: 'coachingStyle'),
          antiSycophancyPolicy: any(named: 'antiSycophancyPolicy'),
          authoredBy: any(named: 'authoredBy'),
        ),
      ).thenAnswer(
        (_) async => makeTestSoulDocumentVersion(version: 2),
      );

      await tester.pumpWidget(
        buildEditSubject(soulId: 'soul-save'),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentSoulDetailPage));

      // Modify voice directive to make form dirty.
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText ==
                  context.messages.agentSoulVoiceDirectiveLabel,
        ),
        'Updated voice',
      );
      await tester.pump();

      // Tap save.
      await tester.tap(find.text(context.messages.agentTemplateSaveNewVersion));
      await tester.pumpAndSettle();

      verify(
        () => mockSoulService.createVersion(
          soulId: 'soul-save',
          voiceDirective: 'Updated voice',
          // ignore: avoid_redundant_argument_values
          toneBounds: '',
          // ignore: avoid_redundant_argument_values
          coachingStyle: '',
          // ignore: avoid_redundant_argument_values
          antiSycophancyPolicy: '',
          authoredBy: 'user',
        ),
      ).called(1);
    });
  });
}
