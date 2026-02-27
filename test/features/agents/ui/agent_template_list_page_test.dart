import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/agent_template_list_page.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  setUp(() async {
    await setUpTestGetIt();
  });
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    required List<AgentDomainEntity> templates,
    List<Override> extraOverrides = const [],
  }) {
    return makeTestableWidgetNoScroll(
      const AgentTemplateListPage(),
      overrides: [
        agentTemplatesProvider.overrideWith(
          (ref) async => templates,
        ),
        // Override version provider to avoid real DB lookups.
        activeTemplateVersionProvider.overrideWith(
          (ref, templateId) async => makeTestTemplateVersion(
            agentId: templateId,
          ),
        ),
        ...extraOverrides,
      ],
    );
  }

  group('AgentTemplateListPage', () {
    testWidgets('renders template cards with name, kind, and model',
        (tester) async {
      final laura = makeTestTemplate(
        id: 'tpl-laura',
        agentId: 'tpl-laura',
        displayName: 'Laura',
      );
      final tom = makeTestTemplate(
        id: 'tpl-tom',
        agentId: 'tpl-tom',
        displayName: 'Tom',
      );

      await tester.pumpWidget(
        buildSubject(templates: [laura, tom]),
      );
      await tester.pumpAndSettle();

      // Both template names visible
      expect(find.text('Laura'), findsOneWidget);
      expect(find.text('Tom'), findsOneWidget);

      // Kind badge visible for each
      final context = tester.element(find.byType(AgentTemplateListPage));
      expect(
        find.text(context.messages.agentTemplateKindTaskAgent),
        findsNWidgets(2),
      );

      // Model ID visible
      expect(
        find.text('models/gemini-3-flash-preview'),
        findsNWidgets(2),
      );
    });

    testWidgets('shows empty state when no templates', (tester) async {
      await tester.pumpWidget(
        buildSubject(templates: []),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateListPage));
      expect(
        find.text(context.messages.agentTemplateEmptyList),
        findsOneWidget,
      );
    });

    testWidgets('shows page title', (tester) async {
      await tester.pumpWidget(
        buildSubject(templates: [makeTestTemplate()]),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateListPage));
      expect(
        find.text(context.messages.agentTemplatesTitle),
        findsOneWidget,
      );
    });

    testWidgets('shows version number from active version', (tester) async {
      final template = makeTestTemplate(id: 'tpl-1', agentId: 'tpl-1');

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentTemplateListPage(),
          overrides: [
            agentTemplatesProvider.overrideWith(
              (ref) async => <AgentDomainEntity>[template],
            ),
            activeTemplateVersionProvider.overrideWith(
              (ref, templateId) async => makeTestTemplateVersion(
                agentId: templateId,
                version: 3,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateListPage));
      expect(
        find.text(context.messages.agentTemplateVersionLabel(3)),
        findsOneWidget,
      );
    });

    testWidgets('has FAB for creating new template', (tester) async {
      await tester.pumpWidget(
        buildSubject(templates: []),
      );
      await tester.pumpAndSettle();

      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);

      // Verify the FAB is actionable (has an onPressed callback).
      final fab = tester.widget<FloatingActionButton>(fabFinder);
      expect(fab.onPressed, isNotNull);
    });

    testWidgets('shows loading indicator while templates are loading',
        (tester) async {
      final completer = Completer<List<AgentDomainEntity>>();

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentTemplateListPage(),
          overrides: [
            agentTemplatesProvider.overrideWith(
              (ref) => completer.future,
            ),
            activeTemplateVersionProvider.overrideWith(
              (ref, templateId) async => makeTestTemplateVersion(
                agentId: templateId,
              ),
            ),
          ],
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future and settle to avoid pending timer assertions.
      completer.complete([]);
      await tester.pumpAndSettle();
    });

    testWidgets('shows error text with error color on provider failure',
        (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const AgentTemplateListPage(),
          overrides: [
            agentTemplatesProvider.overrideWith(
              (ref) => Future<List<AgentDomainEntity>>.error(
                Exception('db failure'),
              ),
            ),
            activeTemplateVersionProvider.overrideWith(
              (ref, templateId) async => makeTestTemplateVersion(
                agentId: templateId,
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(AgentTemplateListPage));
      final errorText = find.text(context.messages.commonError);
      expect(errorText, findsOneWidget);

      // Verify the error text uses the error color from the theme.
      final textWidget = tester.widget<Text>(errorText);
      final theme = Theme.of(context);
      expect(
        textWidget.style?.color,
        theme.colorScheme.error,
      );
    });
  });
}
