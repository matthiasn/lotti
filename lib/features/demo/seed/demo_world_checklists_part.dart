part of 'demo_world.dart';

typedef _SupplementalChecklist = ({
  Checklist checklist,
  List<ChecklistItem> items,
});

typedef _SupplementalChecklistBuilder =
    _SupplementalChecklist Function({
      required String slug,
      required String taskId,
      required (String, String) taskTitle,
      List<(String, String)>? runbook,
      List<(String, String)>? steps,
      int checkedCount,
      String categoryId,
    });

/// The checklists that give every remaining penguin task the same
/// interactive, mixed-progress experience: the shared runbooks for the
/// original fixture, bespoke steps for the expansion tasks.
List<_SupplementalChecklist> _penguinSupplementalChecklists({
  required _SupplementalChecklistBuilder supplementalChecklist,
}) {
  final launchRunbook = <(String, String)>[
    ('Brief the boarding crew', 'Die Einsteigemannschaft briefen'),
    ('Time the hatch sequence', 'Die Lukensequenz stoppen'),
    ('Test the intercom', 'Die Gegensprechanlage testen'),
    ('Rehearse the abort call', 'Den Abbruchruf proben'),
  ];
  final habitatRunbook = <(String, String)>[
    ('Vent Bay A', 'Bucht A entlüften'),
    ('Swap cartridges A1–A4', 'Patronen A1–A4 tauschen'),
    ('Log the CO2 baseline', 'CO2-Ausgangswert notieren'),
    ('Return the used cartridges', 'Die alten Patronen zurückgeben'),
  ];
  final logisticsRunbook = <(String, String)>[
    ('Check bay two', 'Bucht zwei prüfen'),
    ('Check the cold ring', 'Den Kühlring prüfen'),
    ('Ask the dock crew', 'Die Dockmannschaft fragen'),
    ('File a loss report', 'Verlustmeldung einreichen'),
  ];
  final colonyRunbook = <(String, String)>[
    ('Colony news', 'Neues aus der Kolonie'),
    ('Launch update', 'Neues zum Start'),
    ('Chick of the month', 'Küken des Monats'),
    ('Sardine recipe', 'Sardinenrezept'),
  ];
  return [
    supplementalChecklist(
      slug: 'roll-call',
      taskId: manualRollCallTaskId,
      taskTitle: ('Emperor penguin roll call', 'Kaiserpinguine durchzählen'),
      runbook: colonyRunbook,
    ),
    supplementalChecklist(
      slug: 'launch-review',
      taskId: manualLaunchReviewTaskId,
      taskTitle: (
        'Project Waddle launch review',
        'Startprüfung für Project Waddle',
      ),
      runbook: launchRunbook,
    ),
    supplementalChecklist(
      slug: 'lunch',
      taskId: manualLunchTaskId,
      taskTitle: (
        'Lunch (coffee is not a vegetable)',
        'Mittagessen (Kaffee ist kein Gemüse)',
      ),
      runbook: colonyRunbook,
    ),
    supplementalChecklist(
      slug: 'sardine-futures',
      taskId: manualSardineFuturesTaskId,
      taskTitle: ('Negotiate sardine futures', 'Sardinen-Futures verhandeln'),
      runbook: logisticsRunbook,
      categoryId: demoLogisticsCategoryId,
    ),
    supplementalChecklist(
      slug: 'fish-feeder',
      taskId: manualFishFeederTaskId,
      taskTitle: (
        'Recalibrate the zero-gravity fish feeder',
        'Schwerelosen Fischfütterer neu kalibrieren',
      ),
      runbook: habitatRunbook,
    ),
    supplementalChecklist(
      slug: 'sardine-cargo',
      taskId: manualSardineCargoTaskId,
      taskTitle: (
        'Confirm the interplanetary sardine cargo pods',
        'Interplanetare Sardinen-Frachtkapseln bestätigen',
      ),
      runbook: logisticsRunbook,
      categoryId: demoLogisticsCategoryId,
    ),
    supplementalChecklist(
      slug: 'penguin-passenger',
      taskId: manualPenguinPassengerTaskId,
      taskTitle: (
        'Ask Legal whether a penguin is a passenger',
        'Rechtsabteilung fragen, ob ein Pinguin Passagier ist',
      ),
      runbook: logisticsRunbook,
      categoryId: demoLogisticsCategoryId,
    ),
    supplementalChecklist(
      slug: 'headset-walk',
      taskId: manualHeadsetWalkTaskId,
      taskTitle: ('Walk without a headset', 'Spaziergang ohne Headset'),
      runbook: colonyRunbook,
    ),
    supplementalChecklist(
      slug: 'launch-comms-plan',
      taskId: demoLaunchCommsTaskId,
      taskTitle: (
        'Draft the launch comms plan',
        'Kommunikationsplan entwerfen',
      ),
      steps: [
        (
          'List every launch-day announcement',
          'Alle Ansagen des Starttags auflisten',
        ),
        (
          'Name a speaker for each slot',
          'Für jeden Slot eine Stimme benennen',
        ),
        (
          'Write the fallback script for a hold',
          'Das Ersatzskript für einen Halt schreiben',
        ),
        (
          'Get sign-off from Flight Direction',
          'Das Okay der Flugleitung einholen',
        ),
      ],
    ),
    supplementalChecklist(
      slug: 'ice-pad-weather',
      taskId: demoIcePadWeatherTaskId,
      taskTitle: (
        'Check the ice-pad weather window',
        'Wetterfenster am Eisstartplatz prüfen',
      ),
      steps: [
        ('Pull the morning soundings', 'Die Morgensondierungen ziehen'),
        (
          'Compare the three forecast models',
          'Die drei Wettermodelle vergleichen',
        ),
        (
          'Check the crosswind against the 18-knot limit',
          'Den Seitenwind gegen das 18-Knoten-Limit prüfen',
        ),
        (
          'Send the go or no-go call to Flight Direction',
          'Das Go oder No-Go an die Flugleitung melden',
        ),
      ],
    ),
    supplementalChecklist(
      slug: 'flight-suit-fitting',
      taskId: demoFlightSuitTaskId,
      taskTitle: (
        'Fit the penguin flight suits',
        'Pinguin-Fluganzüge anpassen',
      ),
      steps: [
        ('Remeasure all twelve flyers', 'Alle zwölf Flieger neu vermessen'),
        (
          'Tag the three wide-flipper returns',
          'Die drei Rückläufer mit weiten Flossen kennzeichnen',
        ),
        ('Book the courier pickup', 'Die Kurierabholung buchen'),
        (
          'Confirm the replacement delivery date',
          'Den Liefertermin des Ersatzes bestätigen',
        ),
      ],
    ),
    supplementalChecklist(
      slug: 'humidity-spike',
      taskId: demoHumiditySpikeTaskId,
      taskTitle: (
        'Trace the humidity spike in Bay C',
        'Feuchtigkeitsspitze in Bucht C aufspüren',
      ),
      steps: [
        (
          'Chart the humidity readings by day',
          'Die Feuchtigkeitswerte nach Tagen aufzeichnen',
        ),
        (
          'Wait for the Bay C sensor swap',
          'Auf den Sensortausch in Bucht C warten',
        ),
        (
          'Walk the seam line with the thermal camera',
          'Die Nahtlinie mit der Wärmebildkamera ablaufen',
        ),
        (
          'Report the leak or clear the bay',
          'Das Leck melden oder die Bucht freigeben',
        ),
      ],
      categoryId: demoHabitatCategoryId,
    ),
    supplementalChecklist(
      slug: 'ice-rink-resurface',
      taskId: demoIceRinkTaskId,
      taskTitle: (
        'Resurface the habitat ice rink',
        'Eisbahn im Habitat neu aufbereiten',
      ),
      steps: [
        (
          'Book the resurfacer for an evening slot',
          'Die Maschine für einen Abendtermin buchen',
        ),
        (
          'Announce the one-session closure',
          'Die Sperrung für eine Einheit ankündigen',
        ),
        (
          'Resurface and inspect the ice',
          'Die Bahn aufbereiten und das Eis abnehmen',
        ),
        ('Post the new ice rules', 'Die neuen Eisregeln aushängen'),
      ],
      categoryId: demoHabitatCategoryId,
    ),
    supplementalChecklist(
      slug: 'solar-array-tilt',
      taskId: demoSolarArrayTaskId,
      taskTitle: (
        'Retune the solar array tilt',
        'Neigung der Solarfläche justieren',
      ),
      steps: [
        (
          'Recalibrate against the noon reference',
          'Am Mittagsreferenzpunkt neu kalibrieren',
        ),
        (
          'Verify the tracking curve for a full day',
          'Die Nachführkurve einen ganzen Tag prüfen',
        ),
        (
          'Log the recovered wattage',
          'Die zurückgewonnene Leistung protokollieren',
        ),
        (
          'Close the storm-damage ticket',
          'Das Sturmschaden-Ticket schließen',
        ),
      ],
      categoryId: demoHabitatCategoryId,
    ),
    supplementalChecklist(
      slug: 'water-recycler',
      taskId: demoWaterRecyclerTaskId,
      taskTitle: ('Service the water recycler', 'Wasseraufbereiter warten'),
      steps: [
        ('Flush the recycler loop', 'Den Kreislauf der Anlage spülen'),
        ('Clean the filter housing', 'Das Filtergehäuse reinigen'),
        ('Swap the pre-filter', 'Den Vorfilter tauschen'),
        ('Log the throughput numbers', 'Die Durchsatzwerte protokollieren'),
      ],
      // The task is done, so its checklist reads as finished work.
      checkedCount: 4,
      categoryId: demoHabitatCategoryId,
    ),
    supplementalChecklist(
      slug: 'krill-supplier',
      taskId: demoKrillSupplierTaskId,
      taskTitle: (
        'Shortlist a second krill supplier',
        'Zweiten Krill-Lieferanten finden',
      ),
      steps: [
        (
          'Write down the selection criteria',
          'Die Auswahlkriterien aufschreiben',
        ),
        (
          'Collect quotes from three candidates',
          'Angebote von drei Kandidaten einholen',
        ),
        (
          'Order sample crates from the best two',
          'Bei den besten zwei Probekisten bestellen',
        ),
        (
          'Put a recommendation to the council',
          'Dem Rat eine Empfehlung vorlegen',
        ),
      ],
      categoryId: demoLogisticsCategoryId,
    ),
    supplementalChecklist(
      slug: 'pod-seal-order',
      taskId: demoPodSealOrderTaskId,
      taskTitle: (
        'Order replacement pod seals',
        'Ersatzdichtungen für Kapseln bestellen',
      ),
      steps: [
        (
          'Confirm seal sizes against the pod register',
          'Die Dichtungsgrößen mit dem Kapselregister abgleichen',
        ),
        ('Place the rush order', 'Die Eilbestellung aufgeben'),
        (
          'Chase the delivery confirmation',
          'Die Lieferbestätigung nachfassen',
        ),
        (
          'Warn Logistics about the affected pods',
          'Die Logistik über die betroffenen Kapseln warnen',
        ),
      ],
      categoryId: demoLogisticsCategoryId,
    ),
    supplementalChecklist(
      slug: 'customs-europa',
      taskId: demoCustomsEuropaTaskId,
      taskTitle: ('Clear customs on Europa', 'Zoll auf Europa erledigen'),
      steps: [
        (
          'Assemble the certificate folder',
          'Den Zertifikatsordner zusammenstellen',
        ),
        (
          'Draft the passenger ruling request',
          'Die Anfrage zur Passagierfrage aufsetzen',
        ),
        ('Copy the current manifest', 'Die aktuelle Frachtliste kopieren'),
        ('Book the Monday customs slot', 'Den Zolltermin am Montag buchen'),
      ],
      categoryId: demoLogisticsCategoryId,
    ),
    supplementalChecklist(
      slug: 'chick-daycare',
      taskId: demoChickDaycareTaskId,
      taskTitle: (
        'Refill the chick daycare rota',
        'Dienstplan der Kükenbetreuung füllen',
      ),
      steps: [
        (
          'Ask the reserve list for Thursday',
          'Die Reserveliste für Donnerstag fragen',
        ),
        (
          'Post the open shifts on the colony board',
          'Die offenen Schichten ans Koloniebrett hängen',
        ),
        (
          'Confirm two names per shift',
          'Zwei Namen pro Schicht bestätigen',
        ),
        (
          'Publish the full week by Friday',
          'Den vollen Wochenplan bis Freitag aushängen',
        ),
      ],
    ),
    supplementalChecklist(
      slug: 'movie-night',
      taskId: demoMovieNightTaskId,
      taskTitle: (
        'Pick the film for colony night',
        'Film für den Kolonieabend wählen',
      ),
      steps: [
        ('Request the screening licence', 'Die Vorführlizenz anfragen'),
        (
          'Reserve the dome for the evening',
          'Die Kuppel für den Abend reservieren',
        ),
        (
          'Schedule the heater shutdown',
          'Das Abschalten der Heizung einplanen',
        ),
        (
          'Post the start time on the colony board',
          'Die Anfangszeit ans Koloniebrett schreiben',
        ),
      ],
    ),
    supplementalChecklist(
      slug: 'tobogganing-league',
      taskId: demoTobogganingTaskId,
      taskTitle: (
        'Restart the tobogganing league',
        'Rodel-Liga wieder starten',
      ),
      steps: [
        (
          'Pile fresh snow on the run-out',
          'Frischen Schnee in den Auslauf schaufeln',
        ),
        (
          'Set the doubles-sled weight limit',
          'Das Gewichtslimit für den Doppelschlitten festlegen',
        ),
        (
          'Draft the new season schedule',
          'Den neuen Saisonplan entwerfen',
        ),
        (
          'Send the rematch challenge to Bay C',
          'Die Revanche-Anfrage an Bucht C schicken',
        ),
      ],
    ),
  ];
}
