import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/template_selector.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/features/categories/ui/pages/category_details_page.dart';
import 'package:lotti/features/design_system/components/glass_action_bar.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/utils/consts.dart';
import 'package:lotti/widgets/settings/settings_picker_field.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import '../../../../mocks/mocks.dart';
import '../../../../test_helper.dart';
import '../../../agents/test_utils.dart';
import '../../test_utils.dart';

/// Tests for the event-agent default-template picker built by
/// `category_details_form_sections.dart`'s `_buildDefaultEventTemplatePicker`.
///
/// That section is a `part of` the [CategoryDetailsPage] library, so it can
/// only be exercised through the mounted page. The picker is additionally
/// gated behind the `enableEventsFlag` config flag, so every test here
/// overrides that flag to `true` (the parent page test file leaves it off,
/// which is why this section is otherwise uncovered).
/// Finds the action-bar glass pill by its (localized) label.
Finder pillFinder(String label) => find.byWidgetPredicate(
  (widget) => widget is DsGlassPill && widget.label == label,
);

/// Whether the action bar's pill with [label] is enabled.
bool isPillEnabled(WidgetTester tester, String label) =>
    tester.widget<DsGlassPill>(pillFinder(label)).enabled;

void main() {
  setUpAll(() {
    registerFallbackValue(FakeCategoryDefinition());
  });

  group('Default event template picker', () {
    late MockCategoryRepository mockRepository;
    late String testCategoryId;

    setUp(() {
      mockRepository = MockCategoryRepository();
      testCategoryId = const Uuid().v4();
      beamToNamedOverride = (_) {};
    });

    tearDown(() {
      beamToNamedOverride = null;
    });

    final taskTemplate = makeTestTemplate(
      id: 'tpl-task',
      displayName: 'Task Helper',
    );
    final eventTemplate = makeTestTemplate(
      id: 'tpl-event',
      displayName: 'Recap Writer',
      kind: AgentTemplateKind.eventAgent,
    );
    final otherEventTemplate = makeTestTemplate(
      id: 'tpl-event-2',
      displayName: 'Timeline Summarizer',
      kind: AgentTemplateKind.eventAgent,
    );

    /// Pumps the edit-mode page with the events flag on and the given
    /// [templates] backing the agent-templates provider. A tall viewport
    /// ensures the AI defaults section (well below the fold) builds.
    Future<void> pumpPage(
      WidgetTester tester, {
      required CategoryDefinition category,
      bool eventsEnabled = true,
      List<AgentDomainEntity> templates = const [],
    }) async {
      tester.view.physicalSize = const Size(1024, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
        (_) => Stream.value(category),
      );

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            categoryRepositoryProvider.overrideWithValue(mockRepository),
            configFlagProvider(
              enableEventsFlag,
            ).overrideWith((ref) => Stream.value(eventsEnabled)),
            agentTemplatesProvider.overrideWith((ref) async => templates),
          ],
          child: CategoryDetailsPage(categoryId: testCategoryId),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
    }

    /// The event-agent [TemplateSelector] is the second one in the AI
    /// defaults section (the first is the task-agent picker). It is the only
    /// one carrying the event label.
    Finder eventSelectorFinder() => find.byWidgetPredicate(
      (widget) =>
          widget is TemplateSelector &&
          widget.kind == AgentTemplateKind.eventAgent,
    );

    testWidgets(
      'omits the event-agent picker when the events flag is off',
      (tester) async {
        final category = CategoryTestUtils.createTestCategory();

        await pumpPage(
          tester,
          category: category,
          eventsEnabled: false,
          templates: [eventTemplate],
        );

        // The section omits the event picker entirely; only the task-agent
        // picker (kind defaults to taskAgent) renders.
        expect(eventSelectorFinder(), findsNothing);
        expect(find.byType(TemplateSelector), findsOneWidget);
        expect(find.text('Default event agent template'), findsNothing);
      },
    );

    testWidgets(
      'renders the event-agent picker with its label when the flag is on',
      (tester) async {
        final category = CategoryTestUtils.createTestCategory();

        await pumpPage(
          tester,
          category: category,
          templates: [taskTemplate, eventTemplate],
        );

        // Both the task and event pickers render side by side.
        expect(eventSelectorFinder(), findsOneWidget);
        expect(find.byType(TemplateSelector), findsNWidgets(2));
        // The event picker carries its dedicated label.
        expect(find.text('Default event agent template'), findsOneWidget);
      },
    );

    testWidgets(
      'event picker reflects the category defaultEventTemplateId',
      (tester) async {
        final category = CategoryTestUtils.createTestCategory().copyWith(
          defaultEventTemplateId: 'tpl-event',
        );

        await pumpPage(
          tester,
          category: category,
          templates: [taskTemplate, eventTemplate, otherEventTemplate],
        );

        // The selector is seeded with the category's stored event template id.
        final selector = tester.widget<TemplateSelector>(eventSelectorFinder());
        expect(selector.selectedTemplateId, 'tpl-event');

        // Its picker field shows the resolved template's display name as the
        // current value — not the hint.
        final pickerField = tester.widget<SettingsPickerField>(
          find.descendant(
            of: eventSelectorFinder(),
            matching: find.byType(SettingsPickerField),
          ),
        );
        expect(pickerField.valueText, 'Recap Writer');
      },
    );

    testWidgets(
      'selecting an event template calls setDefaultEventTemplateId and '
      'marks the form dirty',
      (tester) async {
        // Starts with no event template selected.
        final category = CategoryTestUtils.createTestCategory();

        await pumpPage(
          tester,
          category: category,
          templates: [taskTemplate, eventTemplate, otherEventTemplate],
        );

        // Save begins disabled (pristine form).
        expect(isPillEnabled(tester, 'Save'), isFalse);

        // Open the event picker and choose an event template.
        await tester.ensureVisible(eventSelectorFinder());
        await tester.tap(
          find.descendant(
            of: eventSelectorFinder(),
            matching: find.byType(InkWell),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Only event-kind templates are offered — the task template is
        // filtered out by the selector's kind filter.
        expect(find.text('Recap Writer'), findsWidgets);
        expect(find.text('Timeline Summarizer'), findsOneWidget);
        expect(find.text('Task Helper'), findsNothing);

        await tester.tap(find.text('Timeline Summarizer'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // The onTemplateSelected callback ran setDefaultEventTemplateId on
        // the controller, mutating the pending category → form is dirty.
        final selector = tester.widget<TemplateSelector>(eventSelectorFinder());
        expect(selector.selectedTemplateId, 'tpl-event-2');
        expect(isPillEnabled(tester, 'Save'), isTrue);
      },
    );

    testWidgets(
      'clearing the event template resets it to null and marks the form dirty',
      (tester) async {
        final category = CategoryTestUtils.createTestCategory().copyWith(
          defaultEventTemplateId: 'tpl-event',
        );

        await pumpPage(
          tester,
          category: category,
          templates: [taskTemplate, eventTemplate],
        );

        // Pristine to start (the stored id matches the original).
        expect(isPillEnabled(tester, 'Save'), isFalse);

        // The clear affordance is the close icon inside the event picker.
        final clearButton = find.descendant(
          of: eventSelectorFinder(),
          matching: find.byIcon(Icons.close_rounded),
        );
        expect(clearButton, findsOneWidget);
        await tester.ensureVisible(clearButton);
        await tester.tap(clearButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // onTemplateSelected(null) → setDefaultEventTemplateId(null) cleared
        // the id, so the selector now shows no selection and the form is
        // dirty (null != the original 'tpl-event').
        final selector = tester.widget<TemplateSelector>(eventSelectorFinder());
        expect(selector.selectedTemplateId, isNull);
        expect(isPillEnabled(tester, 'Save'), isTrue);
      },
    );

    testWidgets(
      'saving persists the chosen event template id to the repository',
      (tester) async {
        final category = CategoryTestUtils.createTestCategory();
        final controller = StreamController<CategoryDefinition?>.broadcast();
        addTearDown(controller.close);

        tester.view.physicalSize = const Size(1024, 3600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        when(() => mockRepository.watchCategory(testCategoryId)).thenAnswer(
          (_) => controller.stream,
        );
        when(() => mockRepository.getCategoryById(testCategoryId)).thenAnswer(
          (_) async => category,
        );
        when(() => mockRepository.updateCategory(any())).thenAnswer(
          (_) async => category,
        );

        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              categoryRepositoryProvider.overrideWithValue(mockRepository),
              configFlagProvider(
                enableEventsFlag,
              ).overrideWith((ref) => Stream.value(true)),
              agentTemplatesProvider.overrideWith(
                (ref) async => [eventTemplate],
              ),
            ],
            child: CategoryDetailsPage(categoryId: testCategoryId),
          ),
        );
        controller.add(category);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Pick the event template.
        await tester.ensureVisible(eventSelectorFinder());
        await tester.tap(
          find.descendant(
            of: eventSelectorFinder(),
            matching: find.byType(InkWell),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.tap(find.text('Recap Writer').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        await tester.tap(pillFinder('Save'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final saved =
            verify(
                  () => mockRepository.updateCategory(captureAny()),
                ).captured.single
                as CategoryDefinition;
        expect(saved.defaultEventTemplateId, 'tpl-event');
      },
    );
  });
}
