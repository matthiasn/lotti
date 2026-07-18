import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/l10n/app_localizations_sv.dart';

void main() {
  final messages = AppLocalizationsSv();

  group('Swedish app localizations', () {
    test('uses distinct labels for timers and time recordings', () {
      expect(messages.addActionAddTimer, 'Lägg till timer');
      expect(
        messages.addActionAddTimeRecording,
        'Lägg till tidsregistrering',
      );
    });

    test('uses Swedish agent and AI metric terminology', () {
      expect(
        messages.agentControlsDestroyedMessage,
        'Denna agent har förstörts.',
      );
      expect(messages.agentControlsResumeButton, 'Fortsätt');
      expect(messages.aiImpactKpiRequests, 'FÖRFRÅGNINGAR');
      expect(messages.aiImpactMetricRequests, 'Förfrågningar');
      expect(messages.aiImpactMetricTokens, 'Tokens');
      expect(messages.agentStatsTokensPerWakeLabel, 'Tokens / väckning');
      expect(messages.agentStatsWakesLabel, 'Väckningar');
      expect(messages.aiModelPickerProviderModelCount(2), '2 modeller');
      expect(messages.aiProviderCardStatusConnected(1), 'Ansluten · 1 modell');
    });

    test('uses Swedish labels for drafts, task states, and due dates', () {
      expect(messages.aiProviderConnectSaveAsDraft, 'Spara som utkast');
      expect(messages.dailyOsNextStateInProgress(0), 'Pågående');
      expect(messages.dailyOsNextStateOverdue(0), 'Försenad');
      expect(messages.dailyOsNextStateDueOnDate('4 juli'), 'Förfaller: 4 juli');
      expect(messages.projectShowcaseDueDate('4 juli'), 'Förfaller: 4 juli');
      expect(messages.taskDueDateWithDate('4 juli'), 'Förfaller: 4 juli');
      expect(messages.taskDueInDays(2), 'Förfaller om 2 dagar');
    });
  });
}
