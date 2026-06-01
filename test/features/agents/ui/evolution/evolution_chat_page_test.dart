import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_dashboard_header.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_message_input.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../helpers/fallbacks.dart';
import '../../../../widget_test_utils.dart';
import '../../test_utils.dart';

/// Fake [EvolutionChatState] that returns a pre-configured [EvolutionChatData].
class _FakeEvolutionChatState extends EvolutionChatState {
  _FakeEvolutionChatState(this._buildFn);

  final Future<EvolutionChatData> Function(String) _buildFn;

  @override
  Future<EvolutionChatData> build(String templateId) => _buildFn(templateId);
}

/// Fake [EvolutionChatState] that captures [sendMessage] calls without
/// actually invoking the real workflow.
class _CapturingSendState extends EvolutionChatState {
  _CapturingSendState(this._initialData);

  final EvolutionChatData _initialData;
  final List<String> sentMessages = [];

  @override
  Future<EvolutionChatData> build(String templateId) async => _initialData;

  @override
  Future<void> sendMessage(
    String text, {
    bool skipApprovalCheck = false,
  }) async {
    sentMessages.add(text);
  }
}

/// Fake [EvolutionChatState] that allows its state to be mutated from
/// the test after initial build, exercising the didUpdateWidget path
/// in the private _MessageListState.
class _MutableFakeState extends EvolutionChatState {
  _MutableFakeState(this._initialData);

  final EvolutionChatData _initialData;

  @override
  Future<EvolutionChatData> build(String templateId) async => _initialData;

  // Expose a helper so the test can push a new AsyncData value.
  void pushData(EvolutionChatData data) {
    state = AsyncData(data);
  }
}

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
        evolutionChatStateProvider.overrideWith(
          () => _FakeEvolutionChatState(
            chatStateBuilder ?? (_) async => defaultChatData,
          ),
        ),
        ...extraOverrides,
      ],
    );
  }

  group('EvolutionChatPage', () {
    testWidgets('shows template name in app bar', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Test Template'), findsOneWidget);
    });

    testWidgets('shows dashboard header', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(EvolutionDashboardHeader), findsOneWidget);
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

    testWidgets('shows loading indicator when chat state is loading', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) => Completer<EvolutionChatData>().future,
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message when session fails', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) =>
              Future<EvolutionChatData>.error(Exception('fail')),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionError),
        findsOneWidget,
      );
    });

    testWidgets('resolves system message tokens to localized text', (
      tester,
    ) async {
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

      final context = tester.element(find.byType(EvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionStarting),
        findsOneWidget,
      );
    });

    testWidgets('disables message input when sessionId is null', (
      tester,
    ) async {
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

      final input = tester.widget<EvolutionMessageInput>(
        find.byType(EvolutionMessageInput),
      );
      expect(input.enabled, isFalse);
    });

    testWidgets('shows waiting indicator when isWaiting is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.assistant(
                text: 'Thinking...',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
            isWaiting: true,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Loading indicator with ellipsis should appear.
      expect(find.text('...'), findsOneWidget);
      // The waiting indicator in the message list (there may be more from
      // the input widget).
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('resolves session_completed token with version number', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.system(
                text: 'session_completed:3',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionCompleted(3)),
        findsOneWidget,
      );
    });

    testWidgets('resolves approval_failed system token', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.system(
                text: 'approval_failed',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionProposalApprovalFailed),
        findsOneWidget,
      );
    });

    testWidgets('resolves session_error system token', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
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

      final context = tester.element(find.byType(EvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionError),
        findsOneWidget,
      );
    });

    testWidgets('resolves session_abandoned system token', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
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

      final context = tester.element(find.byType(EvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionSessionAbandoned),
        findsOneWidget,
      );
    });

    testWidgets('resolves proposal_rejected system token', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.system(
                text: 'proposal_rejected',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(EvolutionChatPage));
      expect(
        find.text(context.messages.agentEvolutionProposalRejected),
        findsOneWidget,
      );
    });

    testWidgets('shows unrecognized system token as-is', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.system(
                text: 'unknown_token_xyz',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('unknown_token_xyz'), findsOneWidget);
    });

    testWidgets('surface message renders SizedBox.shrink when no processor', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          chatStateBuilder: (_) async => EvolutionChatData(
            sessionId: 'session-1',
            messages: [
              EvolutionChatMessage.surface(
                surfaceId: 'surf-1',
                timestamp: DateTime(2024, 3, 15),
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The surface message should render (no crash) but as SizedBox.shrink.
      expect(find.byType(EvolutionChatBubble), findsNothing);
    });

    testWidgets('shows empty template name when template is not loaded', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          templateOverride: (ref, id) async => null,
        ),
      );
      await tester.pumpAndSettle();

      // Template name area should be empty (not crash).
      expect(find.text('Test Template'), findsNothing);
    });

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
      _CapturingSendState? capturedNotifier;

      final widget = makeTestableWidgetNoScroll(
        const EvolutionChatPage(templateId: kTestTemplateId),
        overrides: [
          agentTemplateProvider.overrideWith((ref, id) async => tpl),
          templatePerformanceMetricsProvider.overrideWith(
            (ref, id) async => makeTestMetrics(),
          ),
          evolutionChatStateProvider.overrideWith(() {
            capturedNotifier = _CapturingSendState(
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
        _CapturingSendState? capturedNotifier;

        final widget = makeTestableWidgetNoScroll(
          const EvolutionChatPage(templateId: kTestTemplateId),
          overrides: [
            agentTemplateProvider.overrideWith((ref, id) async => tpl),
            templatePerformanceMetricsProvider.overrideWith(
              (ref, id) async => makeTestMetrics(),
            ),
            evolutionChatStateProvider.overrideWith(() {
              capturedNotifier = _CapturingSendState(
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
        final widget = ProviderScope(
          overrides: [
            agentTemplateProvider.overrideWith((ref, id) async => tpl),
            templatePerformanceMetricsProvider.overrideWith(
              (ref, id) async => makeTestMetrics(),
            ),
            evolutionChatStateProvider.overrideWith(
              () => _FakeEvolutionChatState(
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
          child: MaterialApp(
            navigatorKey: navigatorKey,
            theme: resolveTestTheme(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SizedBox(),
          ),
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
        _MutableFakeState? capturedNotifier;

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
            evolutionChatStateProvider.overrideWith(() {
              capturedNotifier = _MutableFakeState(initialData);
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
        _MutableFakeState? capturedNotifier;

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
            evolutionChatStateProvider.overrideWith(() {
              capturedNotifier = _MutableFakeState(initialData);
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
