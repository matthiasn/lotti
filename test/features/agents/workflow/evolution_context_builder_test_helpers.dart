import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/workflow/evolution_context_builder.dart';


class GeneratedEvolutionContextCounts {
  const GeneratedEvolutionContextCounts({
    required this.reportCount,
    required this.observationCount,
    required this.noteCount,
    required this.versionCount,
    required this.changesSinceLastSession,
  });

  final int reportCount;
  final int observationCount;
  final int noteCount;
  final int versionCount;
  final int changesSinceLastSession;

  int get expectedReportCount =>
      reportCount > EvolutionContextBuilder.maxInstanceReports
      ? EvolutionContextBuilder.maxInstanceReports
      : reportCount;

  int get expectedObservationCount =>
      observationCount > EvolutionContextBuilder.maxInstanceObservations
      ? EvolutionContextBuilder.maxInstanceObservations
      : observationCount;

  int get expectedNoteCount => noteCount > EvolutionContextBuilder.maxPastNotes
      ? EvolutionContextBuilder.maxPastNotes
      : noteCount;

  int get expectedVersionHistoryCount =>
      versionCount - 1 > EvolutionContextBuilder.maxVersionHistory
      ? EvolutionContextBuilder.maxVersionHistory
      : versionCount - 1;

  @override
  String toString() {
    return 'GeneratedEvolutionContextCounts('
        'reportCount: $reportCount, '
        'observationCount: $observationCount, '
        'noteCount: $noteCount, '
        'versionCount: $versionCount, '
        'changesSinceLastSession: $changesSinceLastSession)';
  }
}

extension AnyGeneratedEvolutionContextCounts on glados.Any {
  glados.Generator<GeneratedEvolutionContextCounts>
  get evolutionContextCounts => glados.CombinableAny(this).combine5(
    glados.IntAnys(this).intInRange(
      0,
      EvolutionContextBuilder.maxInstanceReports + 8,
    ),
    glados.IntAnys(this).intInRange(
      0,
      EvolutionContextBuilder.maxInstanceObservations + 8,
    ),
    glados.IntAnys(this).intInRange(
      0,
      EvolutionContextBuilder.maxPastNotes + 8,
    ),
    glados.IntAnys(this).intInRange(
      1,
      EvolutionContextBuilder.maxVersionHistory + 8,
    ),
    glados.IntAnys(this).intInRange(0, 8),
    (
      int reportCount,
      int observationCount,
      int noteCount,
      int versionCount,
      int changesSinceLastSession,
    ) => GeneratedEvolutionContextCounts(
      reportCount: reportCount,
      observationCount: observationCount,
      noteCount: noteCount,
      versionCount: versionCount,
      changesSinceLastSession: changesSinceLastSession,
    ),
  );
}

String hSectionByHeading(String message, String heading) {
  final sectionStart = message.indexOf(heading);
  if (sectionStart == -1) return '';

  final nextSectionStart = message.indexOf('\n## ', sectionStart + 1);
  return message.substring(
    sectionStart,
    nextSectionStart == -1 ? message.length : nextSectionStart,
  );
}
