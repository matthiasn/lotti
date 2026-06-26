import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_message.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_page.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_state.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_chat_bubble.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_message_input.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';
import 'evolution_chat_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    String templateId = kTestTemplateId,
    Future<EvolutionChatData> Function(String)? chatStateBuilder,
    FutureOr<AgentDomainEntity?> Function(Ref, String)? templateOverride,
    List<Override> extraOverrides = const [],
  }) {
    final tpl = makeTestTemplate(id: templateId, agentId: templateId);

    final defaultChatData = EvolutionChatData(
      sessionId: 'session-1',
      messages: [
        EvolutionChatMessage.system(
          text: 'starting_session',
          timestamp: DateTime(2024, 3, 15),
        ),
        EvolutionChatMessage.assistant(
          text: 'Welcome! How can I help improve this template?',
          timestamp: DateTime(2024, 3, 15),
        ),
      ],
    );

    return makeTestableWidgetNoScroll(
      EvolutionChatPage(templateId: templateId),
      overrides: [
        agentTemplateProvider.overrideWith(
          templateOverride ?? (ref, id) async => tpl,
        ),
        templatePerformanceMetricsProvider.overrideWith(
          (ref, id) async => makeTestMetrics(templateId: templateId),
        ),
        evolutionChatStateProvider.overrideWith2(
          (_) => FakeEvolutionChatState(
            chatStateBuilder ?? (_) async => defaultChatData,
          ),
        ),
        ...extraOverrides,
      ],
    );
  }

  group('EvolutionChatPage', () {
    testWidgets('hides message input during loading state', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) => Completer<EvolutionChatData>().future,
        ),
      );
      await tester.pump();
      await tester.pump();

      // bottomNavigationBar uses whenOrNull which returns null during loading.
      expect(find.byType(EvolutionMessageInput), findsNothing);
    });

    testWidgets('hides message input during error state', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) =>
              Future<EvolutionChatData>.error(Exception('fail')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionMessageInput), findsNothing);
    });

    testWidgets('_handleSend forwards text to evolutionChatState.sendMessage', (
      tester,
    ) async {
      final tpl = makeTestTemplate();
      CapturingSendEvolutionChatState? capturedNotifier;

      final widget = makeTestableWidgetNoScroll(
        const EvolutionChatPage(templateId: kTestTemplateId),
        overrides: [
          agentTemplateProvider.overrideWith((ref, id) async => tpl),
          templatePerformanceMetricsProvider.overrideWith(
            (ref, id) async => makeTestMetrics(),
          ),
          evolutionChatStateProvider.overrideWith2((_) {
            capturedNotifier = CapturingSendEvolutionChatState(
              EvolutionChatData(
                sessionId: 'session-1',
                messages: [
                  EvolutionChatMessage.assistant(
                    text: 'Hello!',
                    timestamp: DateTime(2024, 3, 15),
                  ),
                ],
              ),
            );
            return capturedNotifier!;
          }),
        ],
      );

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'my message');
      await tester.pump();

      // Tap the send button.
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(capturedNotifier!.sentMessages, contains('my message'));
    });

    testWidgets(
      '_handleSend also triggered via keyboard submit action',
      (tester) async {
        final tpl = makeTestTemplate();
        CapturingSendEvolutionChatState? capturedNotifier;

        final widget = makeTestableWidgetNoScroll(
          const EvolutionChatPage(templateId: kTestTemplateId),
          overrides: [
            agentTemplateProvider.overrideWith((ref, id) async => tpl),
            templatePerformanceMetricsProvider.overrideWith(
              (ref, id) async => makeTestMetrics(),
            ),
            evolutionChatStateProvider.overrideWith2((_) {
              capturedNotifier = CapturingSendEvolutionChatState(
                EvolutionChatData(
                  sessionId: 'session-1',
                  messages: [
                    EvolutionChatMessage.assistant(
                      text: 'Hello!',
                      timestamp: DateTime(2024, 3, 15),
                    ),
                  ],
                ),
              );
              return capturedNotifier!;
            }),
          ],
        );

        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'keyboard submit');
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pump();

        expect(capturedNotifier!.sentMessages, contains('keyboard submit'));
      },
    );

    testWidgets(
      'onPopInvokedWithResult callback runs without error when popping',
      (tester) async {
        // Wrap EvolutionChatPage in a page route so we can pop.
        final tpl = makeTestTemplate();

        final navigatorKey = GlobalKey<NavigatorState>();
        final widget = makeTestableWidgetNoScroll(
          const SizedBox(),
          navigatorKey: navigatorKey,
          overrides: [
            agentTemplateProvider.overrideWith((ref, id) async => tpl),
            templatePerformanceMetricsProvider.overrideWith(
              (ref, id) async => makeTestMetrics(),
            ),
            evolutionChatStateProvider.overrideWith2(
              (_) => FakeEvolutionChatState(
                (_) async => EvolutionChatData(
                  sessionId: 'session-1',
                  messages: [
                    EvolutionChatMessage.assistant(
                      text: 'Hi',
                      timestamp: DateTime(2024, 3, 15),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        // Navigate to EvolutionChatPage.
        unawaited(
          navigatorKey.currentState!.push(
            MaterialPageRoute<void>(
              builder: (_) =>
                  const EvolutionChatPage(templateId: kTestTemplateId),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(EvolutionChatPage), findsOneWidget);

        // Pop the page — triggers onPopInvokedWithResult with didPop == true.
        navigatorKey.currentState!.pop();
        await tester.pumpAndSettle();

        // If onPopInvokedWithResult threw, pumpAndSettle would propagate it.
        expect(find.byType(EvolutionChatPage), findsNothing);
      },
    );

    testWidgets(
      'didUpdateWidget triggers scroll-to-bottom when messages list grows',
      (tester) async {
        final tpl = makeTestTemplate();
        MutableEvolutionChatState? capturedNotifier;

        final initialData = EvolutionChatData(
          sessionId: 'session-1',
          messages: [
            EvolutionChatMessage.assistant(
              text: 'First message',
              timestamp: DateTime(2024, 3, 15),
            ),
          ],
        );

        final widget = makeTestableWidgetNoScroll(
          const EvolutionChatPage(templateId: kTestTemplateId),
          overrides: [
            agentTemplateProvider.overrideWith((ref, id) async => tpl),
            templatePerformanceMetricsProvider.overrideWith(
              (ref, id) async => makeTestMetrics(),
            ),
            evolutionChatStateProvider.overrideWith2((_) {
              capturedNotifier = MutableEvolutionChatState(initialData);
              return capturedNotifier!;
            }),
          ],
        );

        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        // Confirm initial message count.
        expect(find.byType(EvolutionChatBubble), findsOneWidget);

        // Push new data with an additional message — causes didUpdateWidget.
        capturedNotifier!.pushData(
          EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.assistant(
                text: 'First message',
                timestamp: DateTime(2024, 3, 15),
              ),
              EvolutionChatMessage.assistant(
                text: 'Second message',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        );
        await tester.pump();

        // Both messages should now be visible.
        expect(find.byType(EvolutionChatBubble), findsNWidgets(2));
        expect(find.text('Second message'), findsOneWidget);
      },
    );

    testWidgets(
      'didUpdateWidget triggers scroll-to-bottom when isWaiting changes',
      (tester) async {
        final tpl = makeTestTemplate();
        MutableEvolutionChatState? capturedNotifier;

        final initialData = EvolutionChatData(
          sessionId: 'session-1',
          messages: [
            EvolutionChatMessage.assistant(
              text: 'Hello!',
              timestamp: DateTime(2024, 3, 15),
            ),
          ],
        );

        final widget = makeTestableWidgetNoScroll(
          const EvolutionChatPage(templateId: kTestTemplateId),
          overrides: [
            agentTemplateProvider.overrideWith((ref, id) async => tpl),
            templatePerformanceMetricsProvider.overrideWith(
              (ref, id) async => makeTestMetrics(),
            ),
            evolutionChatStateProvider.overrideWith2((_) {
              capturedNotifier = MutableEvolutionChatState(initialData);
              return capturedNotifier!;
            }),
          ],
        );

        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        // No loading indicator initially.
        expect(find.text('...'), findsNothing);

        // Push isWaiting=true — triggers didUpdateWidget.
        capturedNotifier!.pushData(
          EvolutionChatData(
            sessionId: 'session-1',
            messages: initialData.messages,
            isWaiting: true,
          ),
        );
        await tester.pump();

        // Loading indicator should appear.
        expect(find.text('...'), findsOneWidget);
      },
    );

    testWidgets(
      'Surface widget rendered for EvolutionSurfaceMessage when processor set',
      (tester) async {
        final processor = SurfaceController(catalogs: const []);
        addTearDown(processor.dispose);

        await tester.pumpWidget(
          buildSubject(
            chatStateBuilder: (_) async => EvolutionChatData(
              sessionId: 'session-1',
              processor: processor,
              messages: [
                EvolutionChatMessage.surface(
                  surfaceId: 'surf-test-1',
                  timestamp: DateTime(2024, 3, 15),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify the Surface branch was taken (processor != null, lines 187-188).
        // Since Surface renders as SizedBox.shrink without a registered
        // definition, we verify indirectly:
        //  1. No EvolutionChatBubble — confirms message was NOT rendered as a
        //     text bubble, i.e. the EvolutionSurfaceMessage branch was taken.
        //  2. We verify the processor was accessed by confirming no null-branch
        //     SizedBox.shrink children exist outside the Surface widget subtree
        //     (the Surface itself renders SizedBox.shrink internally but is
        //     wrapped by Surface — the EvolutionChatBubble check is sufficient).
        expect(find.byType(EvolutionChatBubble), findsNothing);
        // Confirm the Surface type is in the tree by checking the widget at the
        // exact position that _buildMessage(context, EvolutionSurfaceMessage)
        // would produce. Use skipOffstage:false to see off-screen items too.
        expect(
          find.byWidgetPredicate((w) => w is Surface, skipOffstage: false),
          findsOneWidget,
        );
      },
    );
  });
}
