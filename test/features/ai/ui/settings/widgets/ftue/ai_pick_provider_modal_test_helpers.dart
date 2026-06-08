import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/ui/settings/widgets/ftue/ai_pick_provider_modal.dart';
import 'package:lotti/l10n/app_localizations.dart';

/// Resolves the localised messages bundle from the running widget
/// tree so test assertions can stay in sync with the live ARB files
/// (rather than copying English strings inline and silently drifting
/// when copy is updated).
AppLocalizations hL10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(AiPickProviderModal)))!;
