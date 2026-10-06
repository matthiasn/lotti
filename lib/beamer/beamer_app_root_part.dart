part of 'beamer_app.dart';

typedef GlobalCommandLinkedIdResolver = Future<String?> Function();
typedef GlobalCommandCreationAction =
    Future<Object?> Function({String? linkedId});

class MyBeamerApp extends ConsumerStatefulWidget {
  const MyBeamerApp({
    super.key,
    this.navService,
    this.userActivityService,
    this.linkedIdResolver = getIdFromSavedRoute,
    this.createTextEntryAction = createTextEntry,
    this.createTaskAction,
    this.captureScreenshotAction = createScreenshot,
  });

  final NavService? navService;
  final UserActivityService? userActivityService;

  /// Testable boundary around route lookup and side-effectful creation.
  final GlobalCommandLinkedIdResolver linkedIdResolver;
  final GlobalCommandCreationAction createTextEntryAction;

  /// Null creates the task with [createTask], reporting to the app's logger.
  final GlobalCommandCreationAction? createTaskAction;
  final GlobalCommandCreationAction captureScreenshotAction;

  @override
  ConsumerState<MyBeamerApp> createState() => _MyBeamerAppState();
}

class _MyBeamerAppState extends ConsumerState<MyBeamerApp> {
  late final DomainLogger _logger;

  late final BeamerDelegate routerDelegate;
  late final NavService effectiveNavService;

  @override
  void initState() {
    super.initState();
    _logger = ref.read(domainLoggerProvider);
    effectiveNavService = widget.navService ?? ref.read(navServiceProvider);

    routerDelegate = BeamerDelegate(
      initialPath: effectiveNavService.currentPath,
      locationBuilder: RoutesLocationBuilder(
        routes: {
          '*': (context, state, data) => const AppScreen(),
        },
      ).call,
    );
  }

  @override
  void dispose() {
    routerDelegate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep long-lived runtime wiring alive from app startup onward.
    // - agentInitializationProvider: sync can apply and verify incoming agent
    //   payloads before the first entry view. A failure is logged: swallowed,
    //   it left the agent runtime half started with no trace of why.
    // - syncedAudioInferenceListenerProvider: auto-trigger local AI inference
    //   on synced audio for pinned profiles (keepAlive — this listen just
    //   forces construction so the listener subscribes to syncUpdateStream).
    ref
      ..listen(agentInitializationProvider, (_, next) {
        if (next case AsyncError(:final error, :final stackTrace)) {
          _logger.error(
            LogDomain.agentRuntime,
            error,
            stackTrace: stackTrace,
            subDomain: 'agentInitialization',
          );
        }
      })
      ..listen(syncedAudioInferenceListenerProvider, (_, _) {})
      // goalSignalSyncListenerProvider: run the deterministic goal tier
      // (Phase A) when synced signals arrive — the orchestrator only
      // listens locally (ADR 0054).
      ..listen(goalSignalSyncListenerProvider, (_, _) {})
      ..watch(dayProcessingRuntimeProvider);

    final themingState = ref.watch(themingControllerProvider);
    final enableTooltips = ref.watch(enableTooltipsProvider).value ?? true;
    final languagePreference = ref.watch(manualLanguageControllerProvider);

    if (themingState.darkTheme == null || languagePreference.isLoading) {
      // Theming and language re-resolve from the NEW world's SettingsDb on
      // every generation rebuild, so this frame sits between the switch
      // splash and the first themed frame. It holds the colour
      // [ProfileSwitchChrome] carried over from the outgoing generation —
      // no MaterialApp and no Scaffold, either of which would fall back to
      // Flutter's default LIGHT theme and strobe the switch white. A plain
      // hold also beats the old untranslated "Loading..." app bar, which
      // flashed chrome the user never asked for.
      return Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: ProfileSwitchChrome.instance.background,
          child: const SizedBox.expand(),
        ),
      );
    }

    final languageOverride = languagePreference.value;

    final updateActivity =
        (widget.userActivityService ?? getIt<UserActivityService>())
            .updateActivity;

    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) => updateActivity(),
        onPointerMove: (event) => updateActivity(),
        onPointerPanZoomStart: (event) => updateActivity(),
        onPointerPanZoomEnd: (event) => updateActivity(),
        onPointerUp: (event) => updateActivity(),
        onPointerSignal: (event) => updateActivity(),
        onPointerPanZoomUpdate: (event) => updateActivity(),
        child: TooltipVisibility(
          visible: enableTooltips,
          child: MaterialApp.router(
            locale: languageOverride?.locale,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: themingState.lightTheme,
            darkTheme: themingState.darkTheme,
            themeMode: themingState.themeMode,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              FormBuilderLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
              FlutterQuillLocalizations.delegate,
            ],
            debugShowCheckedModeBanner: false,
            routerDelegate: routerDelegate,
            routeInformationParser: BeamerParser(),
            backButtonDispatcher: DrawerFirstBackButtonDispatcher(
              delegate: routerDelegate,
              drawer: ref.watch(mobileNavigationDrawerControllerProvider),
            ),
            builder: LegacyMaterialBridge.wrapBuilder((context, child) {
              // Publish the RESOLVED theme (light vs dark per themeMode and
              // platform brightness — known only here, below MaterialApp's
              // own Theme) so the next profile switch can paint its splash
              // and loading frame in this colour instead of white.
              ProfileSwitchChrome.instance.capture(Theme.of(context));
              final zoomController = ref.watch(
                zoomControllerProvider.notifier,
              );
              final closing = getIt.isRegistered<WindowService>()
                  ? getIt<WindowService>().closing
                  : null;
              return AppClosingOverlay(
                closing: closing,
                child: AppCommandHost(
                  handlers: _globalCommandHandlers(),
                  onActivity: updateActivity,
                  onError: (id, error, stackTrace) {
                    _logger.error(
                      LogDomain.general,
                      error,
                      stackTrace: stackTrace,
                      subDomain: 'keyboardCommand:${id.name}',
                    );
                  },
                  child: DesktopMenuWrapper(
                    onOpenManual: () => openManualInBrowser(
                      systemLocale:
                          WidgetsBinding.instance.platformDispatcher.locale,
                      override: languageOverride,
                    ),
                    onZoomIn: zoomController.zoomIn,
                    onZoomOut: zoomController.zoomOut,
                    onZoomReset: zoomController.resetZoom,
                    closing: closing,
                    // The demo banner sits above the router's navigator, so
                    // it survives every route change; the exit sheet needs a
                    // context INSIDE that navigator to push from.
                    child: DemoModeScaffold(
                      sheetContext: () =>
                          routerDelegate.navigatorKey.currentContext ?? context,
                      child: ZoomWrapper(
                        scale: ref.watch(zoomControllerProvider),
                        child: child ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Map<AppCommandId, AppCommandHandler> _globalCommandHandlers() {
    final navService = effectiveNavService;
    final zoomController = ref.read(zoomControllerProvider.notifier);
    final handlers = <AppCommandId, AppCommandHandler>{
      AppCommandId.openCommandPalette: AppCommandHandler(
        invoke: (invocation) {
          final modalContext =
              routerDelegate.navigatorKey.currentContext ?? invocation.context;
          return showAppCommandPalette(modalContext, invocation.snapshot);
        },
      ),
      AppCommandId.openShortcutHelp: AppCommandHandler(
        invoke: (invocation) {
          final modalContext =
              routerDelegate.navigatorKey.currentContext ?? invocation.context;
          return showKeyboardShortcutsOverlay(modalContext);
        },
      ),
      AppCommandId.createTextEntry: AppCommandHandler(
        invoke: (_) async {
          final linkedId = await widget.linkedIdResolver();
          await widget.createTextEntryAction(linkedId: linkedId);
        },
      ),
      AppCommandId.createTask: AppCommandHandler(
        invoke: (_) async {
          final linkedId = await widget.linkedIdResolver();
          final createTaskAction = widget.createTaskAction;
          if (createTaskAction != null) {
            await createTaskAction(linkedId: linkedId);
          } else {
            await createTask(domainLogger: _logger, linkedId: linkedId);
          }
        },
      ),
      AppCommandId.captureScreenshot: AppCommandHandler(
        invoke: (_) async {
          final linkedId = await widget.linkedIdResolver();
          await widget.captureScreenshotAction(linkedId: linkedId);
        },
      ),
      AppCommandId.navigateTasks: AppCommandHandler(
        invoke: (_) => navService.tapIndex(navService.tasksIndex),
      ),
      AppCommandId.navigateDailyOs: AppCommandHandler(
        isEnabled: () => navService.isDailyOsPageEnabled,
        invoke: (_) => navService.tapIndex(navService.calendarIndex),
      ),
      AppCommandId.navigateProjects: AppCommandHandler(
        isEnabled: () => navService.isProjectsPageEnabled,
        invoke: (_) => navService.tapIndex(navService.projectsIndex),
      ),
      AppCommandId.navigateHabits: AppCommandHandler(
        isEnabled: () => navService.isHabitsPageEnabled,
        invoke: (_) => navService.tapIndex(navService.habitsIndex),
      ),
      AppCommandId.navigateDashboards: AppCommandHandler(
        isEnabled: () => navService.isDashboardsPageEnabled,
        invoke: (_) => navService.tapIndex(navService.dashboardsIndex),
      ),
      AppCommandId.navigateJournal: AppCommandHandler(
        invoke: (_) => navService.tapIndex(navService.journalIndex),
      ),
      AppCommandId.navigateEvents: AppCommandHandler(
        isEnabled: () => navService.isEventsPageEnabled,
        invoke: (_) => navService.tapIndex(navService.eventsIndex),
      ),
      AppCommandId.navigateSettings: AppCommandHandler(
        invoke: (_) => navService.tapIndex(navService.settingsIndex),
      ),
      AppCommandId.zoomIn: AppCommandHandler(
        invoke: (_) => zoomController.zoomIn(),
      ),
      AppCommandId.zoomOut: AppCommandHandler(
        invoke: (_) => zoomController.zoomOut(),
      ),
      AppCommandId.resetZoom: AppCommandHandler(
        invoke: (_) => zoomController.resetZoom(),
      ),
    };
    return handlers;
  }
}
