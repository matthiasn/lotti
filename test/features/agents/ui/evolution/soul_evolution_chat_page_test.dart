import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genui/genui.dart' as genui;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/state/soul_query_providers.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_message.dart';
import 'package:lotti/features/agents/ui/evolution/evolution_chat_state.dart';
import 'package:lotti/features/agents/ui/evolution/soul_evolution_chat_page.dart';
import 'package:lotti/features/agents/ui/evolution/soul_evolution_chat_state.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_chat_bubble.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_message_input.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../mocks/mocks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';
import 'evolution_chat_test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  Widget buildSubject({
    String soulId = kTestSoulId,
    Future<EvolutionChatData> Function(String)? chatStateBuilder,
    FutureOr<AgentDomainEntity?> Function(Ref, String)? soulOverride,
    List<Override> extraOverrides = const [],
  }) {
    final defaultSoul = makeTestSoulDocument(
      id: soulId,
      displayName: 'Laura',
    );

    final defaultChatData = EvolutionChatData(
      sessionId: 'session-1',
      messages: [
        EvolutionChatMessage.system(
          text: 'starting_session',
          timestamp: DateTime(2024, 3, 15),
        ),
        EvolutionChatMessage.assistant(
          text: 'Hi! I am Laura. How has my communication been?',
          timestamp: DateTime(2024, 3, 15),
        ),
      ],
    );

    return makeTestableWidgetNoScroll(
      SoulEvolutionChatPage(soulId: soulId),
      overrides: [
        soulDocumentProvider.overrideWith(
          soulOverride ?? (ref, id) async => defaultSoul,
        ),
        soulEvolutionChatStateProvider.overrideWith(
          () => FakeSoulEvolutionChatState(
            chatStateBuilder ?? (_) async => defaultChatData,
          ),
        ),
        ...extraOverrides,
      ],
    );
  }

  group('SoulEvolutionChatPage', () {
    testWidgets('shows soul name in app bar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Laura'), findsOneWidget);
    });

    testWidgets('shows message input', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionMessageInput), findsOneWidget);
    });

    testWidgets('renders chat bubbles for messages', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionChatBubble), findsNWidgets(2));
    });

    testWidgets('resolves system message tokens', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.system(
                text: 'starting_session',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SoulEvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionStarting),
        findsOneWidget,
      );
    });

    testWidgets('resolves soul_version_created token', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            messages: [
              EvolutionChatMessage.system(
                text: 'soul_version_created:v3',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SoulEvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionCompleted(3)),
        findsOneWidget,
      );
    });

    testWidgets('resolves session_abandoned token', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            messages: [
              EvolutionChatMessage.system(
                text: 'session_abandoned',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SoulEvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionAbandoned),
        findsOneWidget,
      );
    });

    testWidgets('resolves soul_proposal_rejected token', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            messages: [
              EvolutionChatMessage.system(
                text: 'soul_proposal_rejected',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SoulEvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionProposalRejected),
        findsOneWidget,
      );
    });

    testWidgets('shows loading state', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) => Completer<EvolutionChatData>().future,
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error state', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) =>
              Future<EvolutionChatData>.error(Exception('fail')),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SoulEvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionError),
        findsOneWidget,
      );
    });

    testWidgets('disables input when session is null', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => const EvolutionChatData(
            messages: [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final input = tester.widget<EvolutionMessageInput>(
        find.byType(EvolutionMessageInput),
      );
      expect(input.enabled, isFalse);
    });

    testWidgets('resolves session_error token', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            messages: [
              EvolutionChatMessage.system(
                text: 'session_error',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SoulEvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionError),
        findsOneWidget,
      );
    });

    testWidgets('renders unknown system token as-is', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.system(
                text: 'some_unknown_token',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('some_unknown_token'), findsOneWidget);
    });

    testWidgets(
      'renders SizedBox.shrink for surface message without processor',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            chatStateBuilder: (_) async => EvolutionChatData(
              sessionId: 'session-1',
              messages: [
                EvolutionChatMessage.surface(
                  surfaceId: 'test-surface-1',
                  timestamp: DateTime(2024, 3, 15),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // With no processor, surface messages render as SizedBox.shrink
        // and no EvolutionChatBubble should be present for it.
        expect(find.byType(EvolutionChatBubble), findsNothing);
      },
    );

    testWidgets('shows loading indicator when waiting', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.system(
                text: 'starting_session',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
            isWaiting: true,
          ),
        ),
      );
      // Use pump() — pumpAndSettle will timeout on the spinner animation.
      await tester.pump();
      await tester.pump();

      expect(find.text('...'), findsOneWidget);
    });

    testWidgets(
      'onPopInvokedWithResult callback is exercised on back navigation',
      (tester) async {
        // Push SoulEvolutionChatPage onto a real navigator so that a pop can be
        // triggered, which exercises the onPopInvokedWithResult closure (line 42).
        final defaultSoul = makeTestSoulDocument(displayName: 'Laura');
        final defaultChatData = EvolutionChatData(
          sessionId: 'session-1',
          messages: [
            EvolutionChatMessage.assistant(
              text: 'Hello!',
              timestamp: DateTime(2024, 3, 15),
            ),
          ],
        );

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => Builder(
                  builder: (context) => Scaffold(
                    body: ElevatedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              const SoulEvolutionChatPage(soulId: kTestSoulId),
                        ),
                      ),
                      child: const Text('Open'),
                    ),
                  ),
                ),
              ),
            ),
            overrides: [
              soulDocumentProvider.overrideWith((ref, id) async => defaultSoul),
              soulEvolutionChatStateProvider.overrideWith(
                () => FakeSoulEvolutionChatState((_) async => defaultChatData),
              ),
            ],
          ),
        );

        // Navigate to the page.
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.byType(SoulEvolutionChatPage), findsOneWidget);

        // Pop back — this invokes onPopInvokedWithResult with didPop == true.
        tester.state<NavigatorState>(find.byType(Navigator).last).pop();
        await tester.pumpAndSettle();

        // The page was popped and we are back on the root route.
        expect(find.byType(SoulEvolutionChatPage), findsNothing);
      },
    );

    testWidgets('_handleSend routes typed text to the notifier sendMessage', (
      tester,
    ) async {
      // Use the tracking fake to capture what text reaches the notifier.
      late TrackingSoulEvolutionChatState notifierInstance;

      final defaultSoul = makeTestSoulDocument(displayName: 'Laura');
      final initialData = EvolutionChatData(
        sessionId: 'session-1',
        messages: [
          EvolutionChatMessage.assistant(
            text: 'Hello!',
            timestamp: DateTime(2024, 3, 15),
          ),
        ],
      );

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const SoulEvolutionChatPage(soulId: kTestSoulId),
          overrides: [
            soulDocumentProvider.overrideWith((ref, id) async => defaultSoul),
            soulEvolutionChatStateProvider.overrideWith(() {
              final n = TrackingSoulEvolutionChatState(
                (_) async => initialData,
              );
              notifierInstance = n;
              return n;
            }),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Type a message in the TextField inside EvolutionMessageInput.
      await tester.enterText(find.byType(TextField), 'Hello from test');
      await tester.pump();

      // Submit via the TextInputAction (calls _handleSend in the input widget,
      // which in turn fires SoulEvolutionChatPage._handleSend).
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();

      expect(notifierInstance.lastSentMessage, 'Hello from test');
    });

    testWidgets(
      '_MessageList.didUpdateWidget schedules scroll when messages are added',
      (tester) async {
        // Build the page with a controllable fake notifier.
        final defaultSoul = makeTestSoulDocument(displayName: 'Laura');
        final initialData = EvolutionChatData(
          sessionId: 'session-1',
          messages: [
            EvolutionChatMessage.assistant(
              text: 'First message',
              timestamp: DateTime(2024, 3, 15),
            ),
          ],
        );

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const SoulEvolutionChatPage(soulId: kTestSoulId),
            overrides: [
              soulDocumentProvider.overrideWith((ref, id) async => defaultSoul),
              soulEvolutionChatStateProvider.overrideWith(
                () => ControllableSoulEvolutionChatState(
                  (_) async => initialData,
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Confirm first message rendered.
        expect(find.text('First message'), findsOneWidget);

        // Push a new data state with an extra message to trigger didUpdateWidget
        // on _MessageList (messages.length changed).
        final element = tester.element(find.byType(SoulEvolutionChatPage));
        final container = ProviderScope.containerOf(element);
        (container.read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
                as ControllableSoulEvolutionChatState)
            .pushUpdate(
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

        // Both messages are now visible — didUpdateWidget ran without error.
        expect(find.text('Second message'), findsOneWidget);
      },
    );

    testWidgets(
      '_MessageList.didUpdateWidget schedules scroll when isWaiting changes',
      (tester) async {
        final defaultSoul = makeTestSoulDocument(displayName: 'Laura');
        final initialData = EvolutionChatData(
          sessionId: 'session-1',
          messages: [
            EvolutionChatMessage.assistant(
              text: 'Hello!',
              timestamp: DateTime(2024, 3, 15),
            ),
          ],
        );

        await tester.pumpWidget(
          makeTestableWidgetNoScroll(
            const SoulEvolutionChatPage(soulId: kTestSoulId),
            overrides: [
              soulDocumentProvider.overrideWith((ref, id) async => defaultSoul),
              soulEvolutionChatStateProvider.overrideWith(
                () => ControllableSoulEvolutionChatState(
                  (_) async => initialData,
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Flip isWaiting to true — this changes the value without adding messages,
        // exercising the second branch of the didUpdateWidget condition.
        final element = tester.element(find.byType(SoulEvolutionChatPage));
        final container = ProviderScope.containerOf(element);
        (container.read(soulEvolutionChatStateProvider(kTestSoulId).notifier)
                as ControllableSoulEvolutionChatState)
            .pushUpdate(
              EvolutionChatData(
                sessionId: 'session-1',
                messages: [
                  EvolutionChatMessage.assistant(
                    text: 'Hello!',
                    timestamp: DateTime(2024, 3, 15),
                  ),
                ],
                isWaiting: true,
              ),
            );
        // Use pump() to avoid settling on the new spinner animation.
        await tester.pump();
        await tester.pump();

        // The loading indicator ('...') should now appear.
        expect(find.text('...'), findsOneWidget);
      },
    );

    testWidgets('surface message with processor renders Surface widget', (
      tester,
    ) async {
      // Set up a MockSurfaceController whose contextFor returns a stubbed
      // SurfaceContext with a null definition so the Surface widget renders
      // SizedBox.shrink() internally — but lines 179-180 are still hit.
      final mockProcessor = MockSurfaceController();
      final mockContext = MockSurfaceContext();
      final definitionNotifier = ValueNotifier<genui.SurfaceDefinition?>(null);
      addTearDown(definitionNotifier.dispose);

      when(() => mockProcessor.contextFor('surf-42')).thenReturn(mockContext);
      when(() => mockContext.surfaceId).thenReturn('surf-42');
      when(() => mockContext.definition).thenReturn(definitionNotifier);

      final defaultSoul = makeTestSoulDocument(displayName: 'Laura');

      await tester.pumpWidget(
        makeTestableWidgetNoScroll(
          const SoulEvolutionChatPage(soulId: kTestSoulId),
          overrides: [
            soulDocumentProvider.overrideWith((ref, id) async => defaultSoul),
            soulEvolutionChatStateProvider.overrideWith(
              () => FakeSoulEvolutionChatState(
                (_) async => EvolutionChatData(
                  sessionId: 'session-1',
                  messages: [
                    EvolutionChatMessage.surface(
                      surfaceId: 'surf-42',
                      timestamp: DateTime(2024, 3, 15),
                    ),
                  ],
                  processor: mockProcessor,
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // contextFor should have been called when the Surface widget was built.
      verify(() => mockProcessor.contextFor('surf-42')).called(greaterThan(0));
      // With null definition the Surface renders SizedBox.shrink; no chat bubble.
      expect(find.byType(EvolutionChatBubble), findsNothing);
    });
  });
}
